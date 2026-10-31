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