-- Apply after s4_reports_notifications.sql.
-- Implements automatic notifications: students are notified the moment
-- their application is approved/rejected, or a progress update is logged.

create or replace function public.notify_on_application_status() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status <> old.status and new.status in ('approved','rejected') then
    insert into public.notifications (user_id, title, body, type)
    values (
      new.student_id,
      case when new.status = 'approved' then 'Application approved' else 'Application update' end,
      case when new.status = 'approved'
           then 'Your application was approved. You can now log weekly progress.'
           else 'Your application status changed to ' || new.status || '.' end,
      'application'
    );
  end if;
  return new;
end $$;

drop trigger if exists on_application_status_change on public.internships;
create trigger on_application_status_change
  after update of status on public.internships
  for each row execute function public.notify_on_application_status();

create or replace function public.notify_on_progress_logged() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (user_id, title, body, type)
  values (
    new.student_id,
    'Progress saved',
    'Week ' || new.week_no || ' update recorded at ' || new.progress || '%.',
    'progress'
  );
  return new;
end $$;

drop trigger if exists on_progress_logged on public.progress_logs;
create trigger on_progress_logged
  after insert on public.progress_logs
  for each row execute function public.notify_on_progress_logged();

-- Realtime support for the live Notifications screen and bell badge.
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
end $$;
