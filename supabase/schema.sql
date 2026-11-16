-- =====================================================================
-- Prashikshan - database schema (run once in Supabase > SQL Editor)
-- Covers: S1 Authentication & Profile, S2 Student Portal, S3 Internship Mgmt
-- =====================================================================

-- ---------- PROFILES ----------
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  full_name     text not null default '',
  role          text not null default 'student'
                check (role in ('student','faculty','tnp','industry')),
  enrollment_no text,
  branch        text,
  phone         text,
  created_at    timestamptz not null default now()
);

-- helper: role of the logged-in user (security definer avoids RLS recursion)
create or replace function public.current_role_of_user()
returns text
language sql
security definer
stable
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

-- auto-create a profile row whenever someone signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role, enrollment_no, branch, phone)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), 'Student'),
    case when lower(trim(coalesce(new.raw_user_meta_data->>'role', 'student'))) in ('student','faculty','tnp','industry')
         then lower(trim(coalesce(new.raw_user_meta_data->>'role', 'student'))) else 'student' end,
    new.raw_user_meta_data->>'enrollment_no',
    new.raw_user_meta_data->>'branch',
    new.raw_user_meta_data->>'phone'
  )
  on conflict (id) do nothing;
  return new;
exception when others then
  -- Fail-safe: never block user signup in auth.users if profile insert fails
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

grant execute on function public.handle_new_user() to anon, authenticated, service_role, supabase_auth_admin;

alter table public.profiles enable row level security;

drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own" on public.profiles for insert to authenticated
  with check (auth.uid() = id);

drop policy if exists "profiles read" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated
  using (auth.uid() = id or public.current_role_of_user() in ('faculty','tnp'));

drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles for update to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id and role = public.current_role_of_user()); -- users cannot change their own role

grant select, insert, update, delete on table public.profiles to authenticated;
grant select on table public.profiles to anon;

-- ---------- INTERNSHIPS ----------
create table if not exists public.internships (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references public.profiles(id) on delete cascade,
  company_name text not null,
  title        text not null,
  description  text,
  mode         text not null default 'onsite',
  start_date   date not null,
  end_date     date not null,
  status       text not null default 'pending',
  progress     int  not null default 0 check (progress between 0 and 100),
  industry_id  uuid,
  created_at   timestamptz not null default now(),
  check (end_date >= start_date)
);

alter table public.internships enable row level security;

drop policy if exists "internships read" on public.internships;
drop policy if exists "internships read scoped" on public.internships;
drop policy if exists "Students can view own internships" on public.internships;
create policy "internships read" on public.internships for select to authenticated
  using (
    student_id = auth.uid()
    or (exists (select 1 from public.students s where s.id = internships.student_id and s.user_id = auth.uid()))
    or public.current_role_of_user() in ('faculty','faculty_mentor','tnp','tp_officer','industry','industry_supervisor','admin')
  );

drop policy if exists "internships insert own" on public.internships;
drop policy if exists "Students can insert own internships" on public.internships;
drop policy if exists "Users can insert own internships" on public.internships;
create policy "internships insert own" on public.internships for insert to authenticated
  with check (
    (
      student_id = auth.uid()
      or (exists (select 1 from public.students s where s.id = internships.student_id and s.user_id = auth.uid()))
    )
    and (status is null or lower(status::text) in ('pending', 'planned', 'active'))
  );

-- a student can edit only while still pending; they cannot approve themselves
drop policy if exists "internships update own pending" on public.internships;
create policy "internships update own pending" on public.internships for update to authenticated
  using (
    student_id = auth.uid()
    or (exists (select 1 from public.students s where s.id = internships.student_id and s.user_id = auth.uid()))
  )
  with check (
    student_id = auth.uid()
    or (exists (select 1 from public.students s where s.id = internships.student_id and s.user_id = auth.uid()))
  );

drop policy if exists "internships delete own pending" on public.internships;
create policy "internships delete own pending" on public.internships for delete to authenticated
  using (
    student_id = auth.uid()
    or (exists (select 1 from public.students s where s.id = internships.student_id and s.user_id = auth.uid()))
  );

grant select, insert, update, delete on table public.internships to authenticated;

-- faculty / T&P review (used by the teammate building the approval workflow)
drop policy if exists "internships review" on public.internships;
create policy "internships review" on public.internships for update to authenticated
  using (public.current_role_of_user() in ('faculty','tnp'))
  with check (public.current_role_of_user() in ('faculty','tnp'));

-- ---------- PROGRESS UPDATES ----------
create table if not exists public.progress_updates (
  id            uuid primary key default gen_random_uuid(),
  client_ref    uuid not null unique default gen_random_uuid(),
  internship_id uuid not null references public.internships(id) on delete cascade,
  student_id    uuid not null references public.profiles(id) on delete cascade,
  note          text not null,
  percent       int  not null check (percent between 0 and 100),
  latitude      double precision,
  longitude     double precision,
  accuracy_m    double precision,
  captured_at   timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

alter table public.progress_updates enable row level security;

drop policy if exists "progress read" on public.progress_updates;
create policy "progress read" on public.progress_updates for select to authenticated
  using (student_id = auth.uid() or public.current_role_of_user() in ('faculty','tnp'));

drop policy if exists "progress insert own" on public.progress_updates;
create policy "progress insert own" on public.progress_updates for insert to authenticated
  with check (
    student_id = auth.uid()
    and exists (select 1 from public.internships i
                where i.id = internship_id and i.student_id = auth.uid()
                  and i.status = 'approved')
  );

-- keep internships.progress in sync with the latest update
create or replace function public.sync_internship_progress()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.internships set progress = new.percent where id = new.internship_id;
  return new;
end;
$$;

drop trigger if exists on_progress_insert on public.progress_updates;
create trigger on_progress_insert
  after insert on public.progress_updates
  for each row execute function public.sync_internship_progress();

-- ---------- DOCUMENTS ----------
create table if not exists public.internship_documents (
  id            uuid primary key default gen_random_uuid(),
  internship_id uuid not null references public.internships(id) on delete cascade,
  student_id    uuid not null references public.profiles(id) on delete cascade,
  file_name     text not null,
  file_path     text not null,
  created_at    timestamptz not null default now()
);

alter table public.internship_documents enable row level security;

drop policy if exists "docs read" on public.internship_documents;
create policy "docs read" on public.internship_documents for select to authenticated
  using (student_id = auth.uid() or public.current_role_of_user() in ('faculty','tnp'));

drop policy if exists "docs insert own" on public.internship_documents;
create policy "docs insert own" on public.internship_documents for insert to authenticated
  with check (
    student_id = auth.uid()
    and exists (select 1 from public.internships i
                where i.id = internship_id and i.student_id = auth.uid())
  );

drop policy if exists "docs delete own" on public.internship_documents;
create policy "docs delete own" on public.internship_documents for delete to authenticated
  using (student_id = auth.uid());

-- ---------- STORAGE (private bucket for uploaded documents) ----------
insert into storage.buckets (id, name, public)
values ('internship-docs', 'internship-docs', false)
on conflict (id) do nothing;

drop policy if exists "docs storage insert" on storage.objects;
create policy "docs storage insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'internship-docs'
              and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "docs storage read" on storage.objects;
create policy "docs storage read" on storage.objects for select to authenticated
  using (bucket_id = 'internship-docs'
         and ((storage.foldername(name))[1] = auth.uid()::text
              or public.current_role_of_user() in ('faculty','tnp')));

drop policy if exists "docs storage delete" on storage.objects;
create policy "docs storage delete" on storage.objects for delete to authenticated
  using (bucket_id = 'internship-docs'
         and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------- NOTIFICATIONS & ITR STATUS TRIGGER ----------
create table if not exists public.notifications (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  title         text not null,
  body          text not null default '',
  type          text not null default 'document',
  internship_id uuid references public.internships(id) on delete cascade,
  is_read       boolean not null default false,
  created_at    timestamptz not null default now()
);

alter table public.notifications enable row level security;

drop policy if exists "Users read own notifications" on public.notifications;
create policy "Users read own notifications" on public.notifications for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users insert own notifications" on public.notifications;
create policy "Users insert own notifications" on public.notifications for insert to authenticated
  with check (true);

drop policy if exists "Users update own notifications" on public.notifications;
create policy "Users update own notifications" on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Users delete own notifications" on public.notifications;
create policy "Users delete own notifications" on public.notifications for delete to authenticated
  using (user_id = auth.uid());

grant select, insert, update, delete on table public.notifications to authenticated;
grant select on table public.notifications to anon;

create or replace function public.notify_on_itr_status_changed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid;
  v_title text;
  v_body text;
  v_internship_title text;
  v_remarks text;
begin
  if new.status is distinct from old.status
     and lower(new.status::text) in ('approved', 'rejected', 'changes_requested') then
    begin
      select coalesce(
        (select s.user_id from public.students s where s.id = new.student_id limit 1),
        (select p.id from public.profiles p where p.id = new.student_id limit 1),
        (select i.student_id from public.internships i where i.id = new.internship_id limit 1)
      ) into v_user_id;

      select coalesce(
        nullif(trim(coalesce(new.internship_title, '')), ''),
        nullif(trim(coalesce(new.project_title, '')), ''),
        (select title from public.internships where id = new.internship_id limit 1),
        'Industrial Training Report'
      ) into v_internship_title;

      v_remarks := nullif(trim(coalesce(new.remarks, '')), '');

      if lower(new.status::text) = 'approved' then
        v_title := 'ITR Approved';
        v_body := 'Your Industrial Training Report (ITR) for ' || v_internship_title || ' has been approved by your Faculty Mentor.';
      elsif lower(new.status::text) = 'rejected' then
        v_title := 'ITR Rejected';
        v_body := 'Your Industrial Training Report (ITR) for ' || v_internship_title || ' was rejected.' || case when v_remarks is not null then ' Remarks: ' || v_remarks else '' end;
      else
        v_title := 'ITR Changes Requested';
        v_body := 'Changes have been requested for your Industrial Training Report (ITR) for ' || v_internship_title || '.' || case when v_remarks is not null then ' Feedback: ' || v_remarks else '' end;
      end if;

      if v_user_id is not null then
        insert into public.notifications (user_id, title, body, type, internship_id, is_read)
        values (v_user_id, v_title, v_body, 'document', new.internship_id, false);
      end if;
    exception when others then
      raise warning 'Could not create notification on ITR status change: %', sqlerrm;
    end;
  end if;
  return new;
end;
$$;
