-- Undo 20261123000000_s5_sync_refinement.sql
drop function if exists public.get_notifications_since(timestamptz, integer);
drop trigger if exists trg_notifications_touch_updated_at on public.notifications;
drop function if exists public.touch_notification_updated_at();
drop index if exists public.notifications_user_updated_idx;
alter table public.notifications drop column if exists updated_at;
