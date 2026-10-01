-- S3: run once in Supabase > SQL Editor, after the S2 script.

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  doc_type text not null default 'other'
    check (doc_type in ('resume','offer_letter','noc','certificate','other')),
  file_name text not null,
  file_path text not null,
  uploaded_at timestamptz not null default now()
);
alter table public.documents enable row level security;

create policy "Students read own documents" on public.documents
  for select using (student_id = auth.uid());
create policy "Students add own documents" on public.documents
  for insert with check (
    student_id = auth.uid()
    and exists (select 1 from public.applications a
                where a.id = application_id and a.student_id = auth.uid()));
create policy "Faculty and T&P read documents" on public.documents
  for select using (
    exists (select 1 from public.profiles p
            where p.id = auth.uid() and p.role in ('faculty','tnp')));

create table public.progress_logs (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.applications(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  week_no int not null check (week_no >= 1),
  progress int not null check (progress between 0 and 100),
  summary text,
  created_at timestamptz not null default now(),
  unique (application_id, week_no)
);
alter table public.progress_logs enable row level security;

create policy "Students read own progress" on public.progress_logs
  for select using (student_id = auth.uid());
create policy "Students log progress on approved internships" on public.progress_logs
  for insert with check (
    student_id = auth.uid()
    and exists (select 1 from public.applications a
                where a.id = application_id and a.student_id = auth.uid()
                  and a.status = 'approved'));
create policy "Faculty and T&P read progress" on public.progress_logs
  for select using (
    exists (select 1 from public.profiles p
            where p.id = auth.uid() and p.role in ('faculty','tnp')));

-- Private storage bucket; each student can only use the folder named after their user id
insert into storage.buckets (id, name, public) values ('documents', 'documents', false)
on conflict (id) do nothing;

create policy "Students upload own files" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'documents' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "Students read own files" on storage.objects
  for select to authenticated using (
    bucket_id = 'documents' and (storage.foldername(name))[1] = auth.uid()::text);
