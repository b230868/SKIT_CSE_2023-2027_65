-- S5 (02-08 Nov): alerts integrated with progress analytics (additive migration).
-- Existing triggers are untouched. It widens the notifications.type check to allow "alert",
-- adds a milestone trigger and generate_progress_alerts(), and replaces get_student_analytics()
-- with the same output plus student_name / unread_notifications / notifications_by_type.
-- Apply AFTER 20261026000000_s5_notification_analytics_apis.sql.

-- 1. Allow a new 'alert' notification type -------------------------------
do $$
declare
  c record;
begin
  for c in
    select conname
      from pg_constraint
     where conrelid = 'public.notifications'::regclass
       and contype = 'c'
       and pg_get_constraintdef(oid) ilike '%type%'
  loop
    execute format('alter table public.notifications drop constraint %I', c.conname);
  end loop;

  alter table public.notifications
    add constraint notifications_type_check
    check (type in ('general', 'application', 'document', 'progress', 'alert'));
end $$;

-- 2. Milestone alert when progress first crosses 25 / 50 / 75 / 100 -------
create or replace function public.notify_on_progress_milestone()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_prev      integer;
  v_milestone integer;
begin
  select coalesce(max(percent), 0)
    into v_prev
    from public.progress_updates
   where student_id = new.student_id
     and internship_id is not distinct from new.internship_id
     and created_at < new.created_at;

  select max(m)
    into v_milestone
    from unnest(array[25, 50, 75, 100]) as m
   where m > v_prev
     and m <= new.percent;

  if v_milestone is not null then
    insert into public.notifications (user_id, title, body, type, internship_id)
    values (
      new.student_id,
      case when v_milestone = 100 then 'Internship progress complete'
           else 'Milestone reached' end,
      'Your internship progress has passed ' || v_milestone || '%.',
      'alert',
      new.internship_id
    );
  end if;

  return new;
end;
$$;

drop trigger if exists on_progress_milestone on public.progress_updates;
create trigger on_progress_milestone
  after insert on public.progress_updates
  for each row execute function public.notify_on_progress_milestone();

-- 3. Stalled-progress alerts (run daily by a scheduled job / service role) --
create or replace function public.generate_progress_alerts(p_days integer default 7)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer;
begin
  with latest as (
    select distinct on (internship_id)
           internship_id,
           student_id,
           percent,
           coalesce(captured_at, created_at) as last_at
      from public.progress_updates
     order by internship_id, captured_at desc nulls last, created_at desc
  ),
  inserted as (
    insert into public.notifications (user_id, title, body, type, internship_id)
    select l.student_id,
           'No recent progress update',
           'No progress was logged for ' || i.title || ' in the last '
             || p_days || ' days. Please add an update.',
           'alert',
           l.internship_id
      from latest l
      join public.internships i
        on i.id = l.internship_id
       and i.status = 'approved'
     where l.percent < 100
       and l.last_at < now() - make_interval(days => p_days)
       and not exists (
             select 1
               from public.notifications n
              where n.internship_id = l.internship_id
                and n.type = 'alert'
                and n.title = 'No recent progress update'
                and n.created_at > now() - make_interval(days => p_days)
           )
    returning 1
  )
  select count(*)::integer into v_count from inserted;

  return v_count;
end;
$$;

revoke all on function public.generate_progress_alerts(integer)
  from public, anon, authenticated;

-- 4. Analytics RPC: same output as before + notification statistics --------
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
  v_documents_by_type jsonb;
  v_progress jsonb;
  v_name text;
  v_unread integer;
  v_notifications_by_type jsonb;
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

  -- new: student name (works whichever column your profiles table uses)
  select coalesce(to_jsonb(p) ->> 'full_name', to_jsonb(p) ->> 'name')
  into v_name
  from public.profiles p
  where p.id = v_user_id;

  -- new: notification statistics
  select (count(*) filter (where not is_read))::integer
  into v_unread
  from public.notifications
  where user_id = v_user_id;

  select coalesce(jsonb_object_agg(type, type_count), '{}'::jsonb)
  into v_notifications_by_type
  from (
    select type, count(*)::integer as type_count
    from public.notifications
    where user_id = v_user_id
    group by type
  ) as notification_counts;

  return jsonb_build_object(
    'total_applications', coalesce(v_total, 0),
    'approved', coalesce(v_approved, 0),
    'pending', coalesce(v_pending, 0),
    'rejected', coalesce(v_rejected, 0),
    'completed', coalesce(v_completed, 0),
    'documents_uploaded', coalesce(v_documents, 0),
    'documents_by_type', coalesce(v_documents_by_type, '{}'::jsonb),
    'latest_progress', coalesce(v_latest_progress, 0),
    'progress', coalesce(v_progress, '[]'::jsonb),
    'student_name', v_name,
    'unread_notifications', coalesce(v_unread, 0),
    'notifications_by_type', coalesce(v_notifications_by_type, '{}'::jsonb)
  );
end;
$$;

revoke all on function public.get_student_analytics() from public;
revoke all on function public.get_student_analytics() from anon;
grant execute on function public.get_student_analytics() to authenticated;
