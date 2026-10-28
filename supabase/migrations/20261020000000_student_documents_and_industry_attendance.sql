-- Migration: 20261020000000_student_documents_and_industry_attendance.sql
-- Description: Adds verification columns to internship_documents for Industry and Faculty verification
-- and adds RLS policies for Industry and Faculty access to student documents and attendance.

-- 1. Ensure columns exist on internship_documents
alter table public.internship_documents 
  add column if not exists doc_type text default 'other',
  add column if not exists status text default 'pending',
  add column if not exists rejection_reason text,
  add column if not exists remarks text,
  add column if not exists verified_by uuid references auth.users(id),
  add column if not exists verified_by_name text,
  add column if not exists verified_at timestamp with time zone,
  add column if not exists faculty_status text default 'pending',
  add column if not exists faculty_rejection_reason text,
  add column if not exists faculty_remarks text,
  add column if not exists faculty_verified_by uuid references auth.users(id),
  add column if not exists faculty_verified_by_name text,
  add column if not exists faculty_verified_at timestamp with time zone;

-- 2. Ensure indexes on internship_documents
create index if not exists idx_internship_docs_internship_id on public.internship_documents(internship_id);
create index if not exists idx_internship_docs_status on public.internship_documents(status);
create index if not exists idx_internship_docs_faculty_status on public.internship_documents(faculty_status);

-- 3. RLS Policies for Industry Representatives:
-- An industry representative can view documents of internships assigned to their company
create policy "Industry reps can view assigned students documents"
  on public.internship_documents for select
  using (
    internship_id in (
      select id from public.internships i
      where i.company_id = auth.uid()
         or i.company_name in (
           select company_name from public.profiles p where p.id = auth.uid()
         )
    )
  );

-- An industry representative can update verification status for assigned students documents
create policy "Industry reps can update assigned students documents verification"
  on public.internship_documents for update
  using (
    internship_id in (
      select id from public.internships i
      where i.company_id = auth.uid()
         or i.company_name in (
           select company_name from public.profiles p where p.id = auth.uid()
         )
    )
  )
  with check (
    internship_id in (
      select id from public.internships i
      where i.company_id = auth.uid()
         or i.company_name in (
           select company_name from public.profiles p where p.id = auth.uid()
         )
    )
  );

-- 4. RLS Policies for Faculty Members:
-- Faculty members can view student documents for monitoring
create policy "Faculty can view monitored students documents"
  on public.internship_documents for select
  using (
    exists (
      select 1 from public.profiles p 
      where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin')
    )
  );

-- Faculty members can update faculty verification on student documents
create policy "Faculty can update students documents verification"
  on public.internship_documents for update
  using (
    exists (
      select 1 from public.profiles p 
      where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin')
    )
  )
  with check (
    exists (
      select 1 from public.profiles p 
      where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin')
    )
  );

-- 5. Attendance RLS Policies:
-- Industry reps can manage attendance only for internships assigned to their company
create policy "Industry reps can view attendance of assigned students"
  on public.attendance for select
  using (
    internship_id in (
      select id from public.internships i
      where i.company_id = auth.uid()
         or i.company_name in (
           select company_name from public.profiles p where p.id = auth.uid()
         )
    )
  );

create policy "Industry reps can insert/update attendance of assigned students"
  on public.attendance for insert
  with check (
    internship_id in (
      select id from public.internships i
      where i.company_id = auth.uid()
         or i.company_name in (
           select company_name from public.profiles p where p.id = auth.uid()
         )
    )
  );

create policy "Industry reps can update attendance records of assigned students"
  on public.attendance for update
  using (
    internship_id in (
      select id from public.internships i
      where i.company_id = auth.uid()
         or i.company_name in (
           select company_name from public.profiles p where p.id = auth.uid()
         )
    )
  );
