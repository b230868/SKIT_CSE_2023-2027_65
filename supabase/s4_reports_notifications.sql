-- S4/S5 (design pass): run once in Supabase > SQL Editor, after s3_documents_progress.sql.
-- This creates the notifications table so the UI has something to read.
-- Triggers that auto-create notifications (on approval, new document, etc.)
-- are added once this interface is reviewed.

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null default '',
  type text not null default 'general'
    check (type in ('general','application','document','progress')),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.notifications enable row level security;

create policy "Users read own notifications" on public.notifications
  for select using (user_id = auth.uid());
create policy "Users update own notifications" on public.notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Sample rows so the screen has something to show while testing.
-- Replace YOUR-USER-ID with your own id from Authentication > Users.
-- insert into public.notifications (user_id, title, body, type) values
-- ('YOUR-USER-ID', 'Welcome to Prashikshan', 'Your account is set up and ready to go.', 'general'),
-- ('YOUR-USER-ID', 'Application received', 'Your application to TechNova Labs was submitted.', 'application');
