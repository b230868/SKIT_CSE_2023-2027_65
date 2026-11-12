-- S5 (09-15 Nov): finalize notification and analytics services.
-- Apply AFTER 20261102000000_s5_alerts_analytics_integration.sql.
-- Adds indexes, batch "mark as read" APIs, a notification summary API,
-- data cleanup and (optional) scheduling. Existing objects are not changed.

-- 1. Indexes for the queries the app runs most --------------------------------
create index if not exists notifications_user_unread_idx
  on public.notifications (user_id) where is_read = false;

create index if not exists notifications_internship_type_idx
  on public.notifications (internship_id, type, created_at desc);

create index if not exists progress_updates_student_captured_idx
  on public.progress_updates (student_id, captured_at desc);

create index if not exists progress_updates_internship_captured_idx
  on public.progress_updates (internship_id, captured_at desc);

create index if not exists internships_student_status_idx
  on public.internships (student_id, status);

-- 2. Data guard: progress must be between 0 and 100 ---------------------------
-- NOT VALID = checked for new rows only, so old data cannot make this fail.
-- Optional later: alter table public.progress_updates validate constraint progress_updates_percent_range;
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conname = 'progress_updates_percent_range'
       and conrelid = 'public.progress_updates'::regclass
  ) then
    alter table public.progress_updates
      add constraint progress_updates_percent_range
      check (percent between 0 and 100) not valid;
  end if;
end $$;

-- 3. Batch "mark as read" (used to sync the offline queue in one call) --------
create or replace function public.mark_notifications_read(p_ids uuid[])
returns integer
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  update public.notifications
     set is_read = true
   where user_id = auth.uid()
     and id = any(p_ids)
     and is_read = false;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.mark_all_notifications_read()
returns integer
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_count integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.' using errcode = '42501';
  end if;

  update public.notifications
     set is_read = true
   where user_id = auth.uid()
     and is_read = false;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.mark_notifications_read(uuid[]) from public, anon;
revoke all on function public.mark_all_notifications_read() from public, anon;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;

-- 4. Notification summary for the bell badge and reports -----------------------
create or replace function public.get_notification_summary()
returns jsonb
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select jsonb_build_object(
    'total',
      (select count(*) from public.notifications where user_id = auth.uid()),
    'unread',
      (select count(*) from public.notifications
        where user_id = auth.uid() and not is_read),
    'by_type',
      coalesce((select jsonb_object_agg(type, c)
                  from (select type, count(*) as c
                          from public.notifications
                         where user_id = auth.uid()
                         group by type) t), '{}'::jsonb),
    'unread_by_type',
      coalesce((select jsonb_object_agg(type, c)
                  from (select type, count(*) as c
                          from public.notifications
                         where user_id = auth.uid() and not is_read
                         group by type) t), '{}'::jsonb)
  );
$$;

revoke all on function public.get_notification_summary() from public, anon;
grant execute on function public.get_notification_summary() to authenticated;

-- 5. Cleanup of old, already-read notifications (backend only) ----------------
create or replace function public.purge_old_notifications(p_days integer default 90)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer;
begin
  delete from public.notifications
   where is_read
     and created_at < now() - make_interval(days => p_days);

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.purge_old_notifications(integer)
  from public, anon, authenticated;

-- 6. Scheduling (only if the pg_cron extension is enabled) ---------------------
-- Enable it in Supabase: Database > Extensions > pg_cron. Safe to run without it.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      's5-generate-progress-alerts',
      '0 3 * * *',
      $cron$select public.generate_progress_alerts(7)$cron$
    );
    perform cron.schedule(
      's5-purge-old-notifications',
      '30 3 * * 0',
      $cron$select public.purge_old_notifications(90)$cron$
    );
  end if;
end $$;

-- 7. Quick checks (run manually in the SQL Editor after applying) -------------
-- select indexname from pg_indexes where tablename in ('notifications','progress_updates','internships');
-- select proname from pg_proc
--  where proname in ('mark_notifications_read','mark_all_notifications_read',
--                    'get_notification_summary','purge_old_notifications');
-- select * from cron.job where jobname like 's5-%';   -- only if pg_cron is enabled
