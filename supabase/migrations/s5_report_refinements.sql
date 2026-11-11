-- S5 (refinement pass): run once in Supabase > SQL Editor,
-- after s5_report_analytics.sql.
-- Replaces student_report_data() with a version that also returns the
-- student's name and notification statistics. Still security invoker, so
-- row-level security applies and only the caller's own rows are read.

create or replace function public.student_report_data()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'student_name',
      (select full_name from public.profiles where id = auth.uid()),
    'total_applications',
      (select count(*) from public.applications where student_id = auth.uid()),
    'approved',
      (select count(*) from public.applications where student_id = auth.uid() and status = 'approved'),
    'pending',
      (select count(*) from public.applications where student_id = auth.uid() and status = 'pending'),
    'rejected',
      (select count(*) from public.applications where student_id = auth.uid() and status = 'rejected'),
    'documents_by_type',
      coalesce((select jsonb_object_agg(doc_type, c)
                from (select doc_type, count(*) as c
                      from public.documents
                      where student_id = auth.uid()
                      group by doc_type) d), '{}'::jsonb),
    'progress',
      coalesce((select jsonb_agg(
                         jsonb_build_object('week_no', week_no,
                                            'progress', progress,
                                            'recorded_at', created_at)
                         order by week_no)
                from public.progress_logs
                where student_id = auth.uid()), '[]'::jsonb),
    'unread_notifications',
      (select count(*) from public.notifications where user_id = auth.uid() and is_read = false),
    'notifications_by_type',
      coalesce((select jsonb_object_agg(type, c)
                from (select type, count(*) as c
                      from public.notifications
                      where user_id = auth.uid()
                      group by type) n), '{}'::jsonb)
  );
$$;

revoke all on function public.student_report_data() from public;
grant execute on function public.student_report_data() to authenticated;
