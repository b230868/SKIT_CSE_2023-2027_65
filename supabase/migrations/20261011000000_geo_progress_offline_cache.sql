-- Apply after supabase/schema.sql to enable idempotent, geo-tagged progress
-- submissions from the existing internship progress screen.

alter table public.progress_updates
  add column if not exists client_ref uuid,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists accuracy_m double precision,
  add column if not exists captured_at timestamptz;

update public.progress_updates
set client_ref = gen_random_uuid()
where client_ref is null;

update public.progress_updates
set captured_at = created_at
where captured_at is null;

alter table public.progress_updates
  alter column client_ref set default gen_random_uuid(),
  alter column client_ref set not null,
  alter column captured_at set default now(),
  alter column captured_at set not null;

create unique index if not exists progress_updates_client_ref_key
  on public.progress_updates (client_ref);

create index if not exists progress_updates_internship_captured_at_idx
  on public.progress_updates (internship_id, captured_at desc);

alter table public.progress_updates enable row level security;

drop policy if exists "progress read" on public.progress_updates;
create policy "progress read" on public.progress_updates
  for select to authenticated
  using (
    student_id = auth.uid()
    or public.current_role_of_user() in ('faculty', 'tnp')
  );

drop policy if exists "progress insert own" on public.progress_updates;
drop policy if exists "Students log progress on approved internships"
  on public.progress_updates;
create policy "progress insert own" on public.progress_updates
  for insert to authenticated
  with check (
    student_id = auth.uid()
    and exists (
      select 1
      from public.internships i
      where i.id = internship_id
        and i.student_id = auth.uid()
        and i.status = 'approved'
    )
  );

grant select, insert on public.progress_updates to authenticated;
