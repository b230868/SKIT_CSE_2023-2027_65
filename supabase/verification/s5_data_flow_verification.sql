-- S5 (16-22 Nov): verify the notification and analytics data flow end to end.
--
-- Run the WHOLE script in the Supabase SQL Editor.
--  * Part 1 only reads the catalog (tables, triggers, functions, policies, grants).
--  * Part 2 (optional) simulates a progress update for one student, checks that the
--    triggers and APIs react correctly, then ROLLS BACK everything it inserted.
-- Only temporary functions are created, so nothing is left in your database.

create or replace function pg_temp.s5_add(p_out jsonb, p_check text, p_status text, p_detail text)
returns jsonb
language sql
as $$
  select p_out || jsonb_build_array(
    jsonb_build_object('c', p_check, 's', p_status, 'd', p_detail));
$$;

create or replace function pg_temp.s5_verify(p_student uuid default null, p_internship uuid default null)
returns table (check_name text, status text, detail text)
language plpgsql
as $$
declare
  v_out    jsonb := '[]'::jsonb;
  v_item   text;
  v_ok     boolean;
  v_count  integer;
  v_json   jsonb;
  v_sum    jsonb;
  v_n      integer;
  v_prev   integer;
  v_p0     integer;
  v_p1     integer;
  v_a0     integer;
  v_a1     integer;
  v_total0 integer;
  v_total1 integer;
begin
  ---------------------------------------------------------------------------
  -- PART 1: structure checks
  ---------------------------------------------------------------------------
  foreach v_item in array array[
    'notifications', 'internships', 'progress_updates',
    'internship_documents', 'profiles'
  ] loop
    v_ok := to_regclass('public.' || v_item) is not null;
    v_out := pg_temp.s5_add(v_out, 'table ' || v_item,
      case when v_ok then 'PASS' else 'FAIL' end, 'public.' || v_item);
  end loop;

  select coalesce(relrowsecurity, false) into v_ok
    from pg_class where oid = to_regclass('public.notifications');
  v_out := pg_temp.s5_add(v_out, 'RLS enabled on notifications',
    case when coalesce(v_ok, false) then 'PASS' else 'FAIL' end, '');

  foreach v_item in array array[
    'internships:on_internship_submitted',
    'internships:on_internship_status_changed',
    'progress_updates:on_progress_update_notification',
    'progress_updates:on_progress_milestone',
    'internship_documents:on_internship_document_uploaded'
  ] loop
    v_ok := exists (
      select 1 from pg_trigger
       where tgname = split_part(v_item, ':', 2)
         and tgrelid = to_regclass('public.' || split_part(v_item, ':', 1))
         and not tgisinternal);
    v_out := pg_temp.s5_add(v_out, 'trigger ' || split_part(v_item, ':', 2),
      case when v_ok then 'PASS' else 'FAIL' end,
      'on ' || split_part(v_item, ':', 1));
  end loop;

  v_ok := not exists (
    select 1 from pg_trigger
     where tgname = 'on_application_status_change'
       and tgrelid = to_regclass('public.internships'));
  v_out := pg_temp.s5_add(v_out, 'no stale duplicate status trigger',
    case when v_ok then 'PASS' else 'FAIL' end,
    'on_application_status_change would send every status notification twice');

  select count(*) into v_count from pg_trigger
   where tgrelid = to_regclass('public.progress_updates') and not tgisinternal;
  v_out := pg_temp.s5_add(v_out, 'progress_updates trigger count',
    case when v_count = 2 then 'PASS' else 'WARN' end,
    format('%s triggers found (expected 2: saved + milestone)', v_count));

  foreach v_item in array array[
    'get_student_analytics', 'get_notification_summary',
    'mark_notifications_read', 'mark_all_notifications_read',
    'generate_progress_alerts', 'purge_old_notifications',
    'notify_on_progress_milestone'
  ] loop
    v_ok := exists (
      select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.proname = v_item);
    v_out := pg_temp.s5_add(v_out, 'function ' || v_item,
      case when v_ok then 'PASS' else 'FAIL' end, 'public.' || v_item);
  end loop;

  v_ok := exists (
    select 1 from pg_constraint
     where conrelid = to_regclass('public.notifications')
       and contype = 'c'
       and pg_get_constraintdef(oid) ilike '%alert%');
  v_out := pg_temp.s5_add(v_out, 'notification type allows alert',
    case when v_ok then 'PASS' else 'FAIL' end, '');

  v_ok := exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public' and tablename = 'notifications');
  v_out := pg_temp.s5_add(v_out, 'realtime enabled on notifications',
    case when v_ok then 'PASS' else 'FAIL' end, 'needed for the live notification list');

  foreach v_item in array array[
    'notifications_user_unread_idx', 'notifications_internship_type_idx',
    'progress_updates_student_captured_idx', 'progress_updates_internship_captured_idx',
    'internships_student_status_idx'
  ] loop
    v_ok := exists (select 1 from pg_indexes
                     where schemaname = 'public' and indexname = v_item);
    v_out := pg_temp.s5_add(v_out, 'index ' || v_item,
      case when v_ok then 'PASS' else 'FAIL' end, '');
  end loop;

  begin
    v_ok := not has_function_privilege('authenticated',
              'public.generate_progress_alerts(integer)', 'EXECUTE');
    v_out := pg_temp.s5_add(v_out, 'app users cannot run generate_progress_alerts',
      case when v_ok then 'PASS' else 'FAIL' end, 'backend-only function');

    v_ok := not has_function_privilege('authenticated',
              'public.purge_old_notifications(integer)', 'EXECUTE');
    v_out := pg_temp.s5_add(v_out, 'app users cannot run purge_old_notifications',
      case when v_ok then 'PASS' else 'FAIL' end, 'backend-only function');

    v_ok := has_function_privilege('authenticated',
              'public.get_student_analytics()', 'EXECUTE');
    v_out := pg_temp.s5_add(v_out, 'app users can run get_student_analytics',
      case when v_ok then 'PASS' else 'FAIL' end, '');

    v_ok := has_column_privilege('authenticated', 'public.notifications', 'is_read', 'UPDATE')
        and not has_column_privilege('authenticated', 'public.notifications', 'title', 'UPDATE');
    v_out := pg_temp.s5_add(v_out, 'users may update only is_read',
      case when v_ok then 'PASS' else 'FAIL' end, 'column-level grant on notifications');
  exception when others then
    v_out := pg_temp.s5_add(v_out, 'privilege checks', 'FAIL', sqlerrm);
  end;

  ---------------------------------------------------------------------------
  -- PART 2: data-flow write test (rolled back)
  ---------------------------------------------------------------------------
  if p_student is null or p_internship is null then
    v_out := pg_temp.s5_add(v_out, 'data-flow write test', 'SKIP',
      'pass a student id and one of that student''s internship ids to run it');
  else
    select count(*) into v_total0 from public.notifications where user_id = p_student;

    begin
      -- act as that student so auth.uid() works inside the APIs
      perform set_config('request.jwt.claims',
        json_build_object('sub', p_student::text, 'role', 'authenticated')::text, true);
      perform set_config('request.jwt.claim.sub', p_student::text, true);

      select coalesce(max(percent), 0) into v_prev
        from public.progress_updates
       where student_id = p_student and internship_id = p_internship;

      select count(*) filter (where type = 'progress'),
             count(*) filter (where type = 'alert')
        into v_p0, v_a0
        from public.notifications where user_id = p_student;

      insert into public.progress_updates (student_id, internship_id, percent, captured_at)
      values (p_student, p_internship, 100, now());
      v_out := pg_temp.s5_add(v_out, 'flow: progress update inserted', 'PASS', 'percent = 100');

      select count(*) filter (where type = 'progress'),
             count(*) filter (where type = 'alert')
        into v_p1, v_a1
        from public.notifications where user_id = p_student;

      v_out := pg_temp.s5_add(v_out, 'flow: "Progress saved" notification created',
        case when v_p1 = v_p0 + 1 then 'PASS' else 'FAIL' end,
        format('progress notifications before %s, after %s', v_p0, v_p1));

      if v_prev >= 100 then
        v_out := pg_temp.s5_add(v_out, 'flow: milestone alert created', 'SKIP',
          'this internship was already at 100%, so no new milestone');
      else
        v_out := pg_temp.s5_add(v_out, 'flow: milestone alert created',
          case when v_a1 = v_a0 + 1 then 'PASS' else 'FAIL' end,
          format('alerts before %s, after %s', v_a0, v_a1));
      end if;

      v_json := public.get_student_analytics();
      v_out := pg_temp.s5_add(v_out, 'flow: analytics reflect the new progress',
        case when (v_json ->> 'latest_progress')::integer = 100 then 'PASS' else 'FAIL' end,
        'latest_progress = ' || coalesce(v_json ->> 'latest_progress', 'null'));

      v_out := pg_temp.s5_add(v_out, 'flow: analytics contain notification fields',
        case when v_json ?& array['student_name', 'unread_notifications',
                                   'notifications_by_type', 'progress']
             then 'PASS' else 'FAIL' end,
        'student_name, unread_notifications, notifications_by_type, progress');

      v_sum := public.get_notification_summary();
      v_out := pg_temp.s5_add(v_out, 'flow: summary shows unread notifications',
        case when (v_sum ->> 'unread')::integer >= 1 then 'PASS' else 'FAIL' end,
        'unread = ' || coalesce(v_sum ->> 'unread', 'null'));

      v_n := public.mark_all_notifications_read();
      v_out := pg_temp.s5_add(v_out, 'flow: mark_all_notifications_read',
        case when v_n >= 1 then 'PASS' else 'FAIL' end,
        format('%s notifications marked as read', v_n));

      v_sum := public.get_notification_summary();
      v_out := pg_temp.s5_add(v_out, 'flow: unread is 0 after mark all',
        case when (v_sum ->> 'unread')::integer = 0 then 'PASS' else 'FAIL' end,
        'unread = ' || coalesce(v_sum ->> 'unread', 'null'));

      -- force a rollback of everything inserted or updated above
      raise exception 's5 rollback' using errcode = 'S5RBK';
    exception
      when sqlstate 'S5RBK' then
        null;
      when others then
        v_out := pg_temp.s5_add(v_out, 'data-flow write test', 'FAIL',
          sqlerrm || ' (if progress_updates has more required columns such as latitude/longitude, add them to the insert above)');
    end;

    select count(*) into v_total1 from public.notifications where user_id = p_student;
    v_out := pg_temp.s5_add(v_out, 'rollback: no test data left behind',
      case when v_total1 = v_total0 then 'PASS' else 'FAIL' end,
      format('notifications before %s, after %s', v_total0, v_total1));
  end if;

  return query
    select x ->> 'c', x ->> 's', x ->> 'd'
      from jsonb_array_elements(v_out) as x;
end;
$$;

-- ----------------------------------------------------------------------------
-- RUN 1: structure checks only (safe)
-- ----------------------------------------------------------------------------
select * from pg_temp.s5_verify(null, null);

-- ----------------------------------------------------------------------------
-- RUN 2: full data-flow test (still rolled back). Find real ids first:
--   select id as internship_id, student_id from public.internships limit 5;
-- then replace the two ids below, remove the leading "-- " and run:
-- ----------------------------------------------------------------------------
-- select * from pg_temp.s5_verify(
--   '00000000-0000-0000-0000-000000000000'::uuid,   -- student_id
--   '00000000-0000-0000-0000-000000000000'::uuid    -- internship_id
-- );
