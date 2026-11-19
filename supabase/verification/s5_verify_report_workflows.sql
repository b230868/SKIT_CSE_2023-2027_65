-- S5 verification script. READ-ONLY: it changes nothing.
-- Run in Supabase > SQL Editor after all S3-S5 SQL files have been applied.
-- Every row should say PASS. Failures are listed first.

with checks(check_name, ok) as (
  -- tables
  select 'table profiles',       to_regclass('public.profiles') is not null
  union all select 'table internships',    to_regclass('public.internships') is not null
  union all select 'table applications',   to_regclass('public.applications') is not null
  union all select 'table documents',      to_regclass('public.documents') is not null
  union all select 'table progress_logs',  to_regclass('public.progress_logs') is not null
  union all select 'table notifications',  to_regclass('public.notifications') is not null

  -- row level security
  union all select 'RLS on applications',  coalesce((select relrowsecurity from pg_class where oid = to_regclass('public.applications')), false)
  union all select 'RLS on documents',     coalesce((select relrowsecurity from pg_class where oid = to_regclass('public.documents')), false)
  union all select 'RLS on progress_logs', coalesce((select relrowsecurity from pg_class where oid = to_regclass('public.progress_logs')), false)
  union all select 'RLS on notifications', coalesce((select relrowsecurity from pg_class where oid = to_regclass('public.notifications')), false)

  -- notification workflow
  union all select 'notifications.application_id column', exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'notifications' and column_name = 'application_id')
  union all select 'trigger on_application_submitted',   exists (select 1 from pg_trigger where tgname = 'on_application_submitted'   and not tgisinternal)
  union all select 'trigger on_application_status_change', exists (select 1 from pg_trigger where tgname = 'on_application_status_change' and not tgisinternal)
  union all select 'trigger on_document_uploaded',       exists (select 1 from pg_trigger where tgname = 'on_document_uploaded'       and not tgisinternal)
  union all select 'trigger on_progress_logged',         exists (select 1 from pg_trigger where tgname = 'on_progress_logged'         and not tgisinternal)
  union all select 'realtime enabled for notifications', exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'notifications')

  -- report workflow
  union all select 'function student_report_data', exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'student_report_data')
  union all select 'storage bucket documents', exists (select 1 from storage.buckets where id = 'documents')

  -- indexes
  union all select 'index applications(student_id)',    to_regclass('public.idx_applications_student') is not null
  union all select 'index documents(student_id)',       to_regclass('public.idx_documents_student') is not null
  union all select 'index progress_logs(student, week)', to_regclass('public.idx_progress_logs_student_week') is not null
  union all select 'index notifications(user, created)', to_regclass('public.idx_notifications_user_created') is not null
  union all select 'index notifications(user, unread)',  to_regclass('public.idx_notifications_user_unread') is not null

  -- data consistency (each count should be 0)
  union all select 'no notifications pointing to a missing application', not exists (
    select 1 from public.notifications n
    where n.application_id is not null
      and not exists (select 1 from public.applications a where a.id = n.application_id))
  union all select 'no progress values outside 0-100', not exists (
    select 1 from public.progress_logs where progress < 0 or progress > 100)
  union all select 'no duplicate week per application', not exists (
    select 1 from public.progress_logs group by application_id, week_no having count(*) > 1)
  union all select 'no progress logged on a non-approved application', not exists (
    select 1 from public.progress_logs l
    join public.applications a on a.id = l.application_id
    where a.status <> 'approved')
)
select check_name, case when ok then 'PASS' else 'FAIL' end as result
from checks
order by ok, check_name;
