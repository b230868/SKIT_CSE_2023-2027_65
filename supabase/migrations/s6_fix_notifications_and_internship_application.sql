-- S6 Fix: Notifications setup and resilient internship submission trigger
-- Run this in Supabase > SQL Editor

-- 1. Ensure public.notifications table exists with all required columns
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

-- Ensure internship_id column exists
alter table public.notifications
  add column if not exists internship_id uuid
  references public.internships(id) on delete cascade;

-- Ensure indexes exist
create index if not exists idx_notifications_user_id on public.notifications (user_id);
create index if not exists idx_notifications_user_created_at on public.notifications (user_id, created_at desc);

-- 2. Configure Row Level Security (RLS)
alter table public.notifications enable row level security;

drop policy if exists "Users read own notifications" on public.notifications;
create policy "Users read own notifications"
  on public.notifications for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users insert own notifications" on public.notifications;
create policy "Users insert own notifications"
  on public.notifications for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "Users update own notifications" on public.notifications;
create policy "Users update own notifications"
  on public.notifications for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Users delete own notifications" on public.notifications;
create policy "Users delete own notifications"
  on public.notifications for delete to authenticated
  using (user_id = auth.uid());

-- Grant permissions to authenticated role
grant select, insert, update, delete on table public.notifications to authenticated;

-- 3. Resilient Trigger: Notify student on internship submission
-- Exception handling ensures an internship application NEVER fails if notification insertion has an issue.
create or replace function public.notify_on_internship_submitted()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  begin
    insert into public.notifications (user_id, title, body, type, internship_id)
    values (
      new.student_id,
      'Application received',
      'Your application for ' || coalesce(new.title, 'the internship') || ' was submitted.',
      'application',
      new.id
    );
  exception when others then
    -- Safely continue so internship application insert succeeds
    raise warning 'Could not create notification on internship submit: %', sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists on_internship_submitted on public.internships;
create trigger on_internship_submitted
  after insert on public.internships
  for each row execute function public.notify_on_internship_submitted();

-- 4. Status change trigger
create or replace function public.notify_on_internship_status_changed()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.status is distinct from old.status
     and new.status in ('approved', 'rejected', 'completed') then
    begin
      insert into public.notifications (user_id, title, body, type, internship_id)
      values (
        new.student_id,
        case new.status
          when 'approved' then 'Application approved'
          when 'rejected' then 'Application update'
          else 'Internship completed'
        end,
        case new.status
          when 'approved' then 'Your application was approved. You can now log weekly progress.'
          when 'rejected' then 'Your application was rejected.'
          else 'Your internship was marked as completed.'
        end,
        'application',
        new.id
      );
    exception when others then
      raise warning 'Could not create notification on status change: %', sqlerrm;
    end;
  end if;
  return new;
end;
$$;

drop trigger if exists on_application_status_change on public.internships;
drop trigger if exists on_internship_status_changed on public.internships;
create trigger on_internship_status_changed
  after update of status on public.internships
  for each row execute function public.notify_on_internship_status_changed();

-- 5. Add notifications to Supabase Realtime publication
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
exception when others then
  raise notice 'Could not add table to supabase_realtime publication: %', sqlerrm;
end;
$$;

-- 6. Analytics API: get_student_analytics() and student_report_data()
create or replace function public.get_student_analytics()
returns jsonb
language plpgsql
stable
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_name text;
  v_total integer;
  v_approved integer;
  v_pending integer;
  v_rejected integer;
  v_completed integer;
  v_documents integer;
  v_latest_progress integer;
  v_unread_notifications integer;
  v_documents_by_type jsonb;
  v_notifications_by_type jsonb;
  v_progress jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required to read student analytics.'
      using errcode = '42501';
  end if;

  select full_name into v_name from public.profiles where id = v_user_id;

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

  select coalesce(jsonb_object_agg(document_type, document_count), '{}'::jsonb)
  into v_documents_by_type
  from (
    select
      case
        when lower(file_name) ~ '\.(png|jpe?g)$' then 'image'
        when lower(file_name) ~ '\.pdf$' then 'pdf'
        when lower(file_name) ~ '\.docx$' then 'docx'
        when lower(file_name) ~ '\.doc$' then 'doc'
        else 'other'
      end as document_type,
      count(*)::integer as document_count
    from public.internship_documents
    where student_id = v_user_id
    group by 1
  ) as document_counts;

  select percent
  into v_latest_progress
  from public.progress_updates
  where student_id = v_user_id
  order by captured_at desc, created_at desc
  limit 1;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'week_no', week_no,
        'progress', percent,
        'recorded_at', captured_at
      )
      order by week_no
    ),
    '[]'::jsonb
  )
  into v_progress
  from (
    select
      row_number() over (order by captured_at, created_at)::integer as week_no,
      percent,
      captured_at
    from public.progress_updates
    where student_id = v_user_id
  ) as progress_history;

  select count(*)::integer
  into v_unread_notifications
  from public.notifications
  where user_id = v_user_id and is_read = false;

  select coalesce(jsonb_object_agg(type, c), '{}'::jsonb)
  into v_notifications_by_type
  from (
    select type, count(*)::integer as c
    from public.notifications
    where user_id = v_user_id
    group by type
  ) as notif_counts;

  return jsonb_build_object(
    'student_name', v_name,
    'total_applications', coalesce(v_total, 0),
    'approved', coalesce(v_approved, 0),
    'pending', coalesce(v_pending, 0),
    'rejected', coalesce(v_rejected, 0),
    'completed', coalesce(v_completed, 0),
    'documents_uploaded', coalesce(v_documents, 0),
    'documents_by_type', coalesce(v_documents_by_type, '{}'::jsonb),
    'latest_progress', coalesce(v_latest_progress, 0),
    'progress', coalesce(v_progress, '[]'::jsonb),
    'unread_notifications', coalesce(v_unread_notifications, 0),
    'notifications_by_type', coalesce(v_notifications_by_type, '{}'::jsonb)
  );
end;
$$;

revoke all on function public.get_student_analytics() from public;
revoke all on function public.get_student_analytics() from anon;
grant execute on function public.get_student_analytics() to authenticated;

-- Compatibility alias
create or replace function public.student_report_data()
returns jsonb
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select public.get_student_analytics();
$$;

grant execute on function public.student_report_data() to authenticated;
