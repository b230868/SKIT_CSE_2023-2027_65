-- S5 (analytics integration): run once in Supabase > SQL Editor.
-- Returns all report data for the signed-in student in ONE call, so the
-- Reports screen loads faster. RLS still applies (security invoker), and
-- the function only ever reads the caller's own rows.
-- The app works without this (it falls back to reading the tables), but run
-- it to use the single-call path.

create or replace function public.student_report_data()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
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
                where student_id = auth.uid()), '[]'::jsonb)
  );
$$;

revoke all on function public.student_report_data() from public;
grant execute on function public.student_report_data() to authenticated;
