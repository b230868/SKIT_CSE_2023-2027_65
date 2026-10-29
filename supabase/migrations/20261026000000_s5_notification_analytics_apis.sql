-- S5 notification and analytics APIs for the current internship schema.
-- Apply after schema.sql and the existing internship/progress migrations.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null default '',
  type text not null default 'general'
    check (type in ('general', 'application', 'document', 'progress')),
  internship_id uuid references public.internships(id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.notifications
  add column if not exists internship_id uuid
  references public.internships(id) on delete cascade;

create index if not exists notifications_user_created_at_idx
  on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

drop policy if exists "Users read own notifications"
  on public.notifications;
create policy "Users read own notifications"
  on public.notifications for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users update own notifications"
  on public.notifications;
create policy "Users update own notifications"
  on public.notifications for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Users delete own notifications"
  on public.notifications;
create policy "Users delete own notifications"
  on public.notifications for delete to authenticated
  using (user_id = auth.uid());

revoke all on table public.notifications from public, anon;
revoke update on table public.notifications from authenticated;
grant select, delete on table public.notifications to authenticated;
grant update (is_read) on table public.notifications to authenticated;

create or replace function public.notify_on_internship_submitted()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, title, body, type, internship_id)
  values (
    new.student_id,
    'Application received',
    'Your application for ' || new.title || ' was submitted.',
    'application',
    new.id
  );
  return new;
end;
$$;

drop trigger if exists on_internship_submitted on public.internships;
create trigger on_internship_submitted
  after insert on public.internships
  for each row execute function public.notify_on_internship_submitted();

create or replace function public.notify_on_internship_status_changed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status is distinct from old.status
     and new.status in ('approved', 'rejected', 'completed') then
    insert into public.notifications (user_id, title, body, type, internship_id)
    values (
      new.student_id,
      case new.status
        when 'approved' then 'Application approved'
        when 'rejected' then 'Application update'
        else 'Internship completed'
      end,
      case new.status
        when 'approved' then 'Your application was approved.'
        when 'rejected' then 'Your application was rejected.'
        else 'Your internship was marked as completed.'
      end,
      'application',
      new.id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists on_application_status_change on public.internships;
drop trigger if exists on_internship_status_changed on public.internships;
create trigger on_internship_status_changed
  after update of status on public.internships
  for each row execute function public.notify_on_internship_status_changed();

create or replace function public.notify_on_progress_update()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, title, body, type, internship_id)
  values (
    new.student_id,
    'Progress saved',
    'Your progress update reached ' || new.percent || '%.',
    'progress',
    new.internship_id
  );
  return new;
end;
$$;

drop trigger if exists on_progress_update_notification
  on public.progress_updates;
create trigger on_progress_update_notification
  after insert on public.progress_updates
  for each row execute function public.notify_on_progress_update();

create or replace function public.notify_on_internship_document_uploaded()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.notifications (user_id, title, body, type, internship_id)
  values (
    new.student_id,
    'Document uploaded',
    new.file_name || ' was added to your internship.',
    'document',
    new.internship_id
  );
  return new;
end;
$$;

drop trigger if exists on_internship_document_uploaded
  on public.internship_documents;
create trigger on_internship_document_uploaded
  after insert on public.internship_documents
  for each row execute function public.notify_on_internship_document_uploaded();

create or replace function public.get_student_analytics()
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_total integer;
  v_approved integer;
  v_pending integer;
  v_rejected integer;
  v_completed integer;
  v_documents integer;
  v_latest_progress integer;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to read student analytics.'
      using errcode = '42501';
  end if;

  select
    count(*)::integer,
    (count(*) filter (where status = 'approved'))::integer,
    (count(*) filter (where status = 'pending'))::integer,
    (count(*) filter (where status = 'rejected'))::integer,
    (count(*) filter (where status = 'completed'))::integer
  into v_total, v_approved, v_pending, v_rejected, v_completed
  from public.internships
  where student_id = v_user_id;

  select count(*)::integer
  into v_documents
  from public.internship_documents
  where student_id = v_user_id;

  select percent
  into v_latest_progress
  from public.progress_updates
  where student_id = v_user_id
  order by captured_at desc, created_at desc
  limit 1;

  return jsonb_build_object(
    'total_applications', coalesce(v_total, 0),
    'approved', coalesce(v_approved, 0),
    'pending', coalesce(v_pending, 0),
    'rejected', coalesce(v_rejected, 0),
    'completed', coalesce(v_completed, 0),
    'documents_uploaded', coalesce(v_documents, 0),
    'latest_progress', coalesce(v_latest_progress, 0)
  );
end;
$$;

revoke all on function public.get_student_analytics() from public;
revoke all on function public.get_student_analytics() from anon;
grant execute on function public.get_student_analytics() to authenticated;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end;
$$;
