-- Undo 20261109000000_s5_finalize_notification_analytics.sql

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('s5-generate-progress-alerts');
    perform cron.unschedule('s5-purge-old-notifications');
  end if;
exception when others then null;
end $$;

drop function if exists public.purge_old_notifications(integer);
drop function if exists public.get_notification_summary();
drop function if exists public.mark_all_notifications_read();
drop function if exists public.mark_notifications_read(uuid[]);

alter table public.progress_updates
  drop constraint if exists progress_updates_percent_range;

drop index if exists public.notifications_user_unread_idx;
drop index if exists public.notifications_internship_type_idx;
drop index if exists public.progress_updates_student_captured_idx;
drop index if exists public.progress_updates_internship_captured_idx;
drop index if exists public.internships_student_status_idx;
