-- S5 (23-29 Nov): refine synchronization handling.
-- Apply AFTER 20261109000000_s5_finalize_notification_analytics.sql.
-- Lets the app download only notifications that changed since its last sync
-- (new ones AND ones marked read from another device) instead of re-downloading everything.

-- 1. Track when a notification last changed -----------------------------------
alter table public.notifications
  add column if not exists updated_at timestamptz not null default now();

create or replace function public.touch_notification_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_notifications_touch_updated_at on public.notifications;
create trigger trg_notifications_touch_updated_at
  before update on public.notifications
  for each row execute function public.touch_notification_updated_at();

create index if not exists notifications_user_updated_idx
  on public.notifications (user_id, updated_at desc);

-- 2. Incremental sync API ------------------------------------------------------
-- Returns the caller's notifications changed on/after p_since (all if null).
-- The app treats a result of 500 rows as "too many changes" and does a full refresh.
create or replace function public.get_notifications_since(
  p_since timestamptz default null,
  p_limit integer default 200
)
returns setof public.notifications
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select *
    from public.notifications
   where user_id = auth.uid()
     and (p_since is null or updated_at >= p_since)
   order by updated_at asc
   limit least(greatest(coalesce(p_limit, 200), 1), 500);
$$;

revoke all on function public.get_notifications_since(timestamptz, integer)
  from public, anon;
grant execute on function public.get_notifications_since(timestamptz, integer)
  to authenticated;

-- Quick check (run manually):
-- select id, is_read, updated_at from public.get_notifications_since(now() - interval '1 day');
