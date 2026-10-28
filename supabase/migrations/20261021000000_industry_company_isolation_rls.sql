-- Migration: 20261021000000_industry_company_isolation_rls.sql
-- Description: Enforces strict company-level data isolation for Industry supervisors
-- based purely on verified industry_users mapping and explicitly authorized company associations.
-- Idempotent, safe for repeatable execution, and avoids overly permissive access or spoofing.

-- 1. Ensure RLS is enabled on all involved tables
alter table if exists public.industries enable row level security;
alter table if exists public.industry_users enable row level security;
alter table if exists public.internships enable row level security;
alter table if exists public.attendance enable row level security;
alter table if exists public.evaluations enable row level security;
alter table if exists public.internship_documents enable row level security;

-- 2. Helper function to check if an internship belongs to the authenticated supervisor's authorized company.
-- SECURITY CRITICAL:
-- - A self-registered company_name in profiles or auth.users is UNTRUSTED and NEVER grants access.
-- - User ID matching `i.industry_id = auth.uid()` is REMOVED: industry_id references an organization,
--   not a supervisor user. Supervisors MUST be mapped via public.industry_users.
-- - SECURITY DEFINER ensures reliable execution with fixed search_path = public, pg_temp.
-- - REVOKE EXECUTE from public; explicitly GRANT EXECUTE only to authenticated role.
create or replace function public.is_internship_authorized_for_supervisor(target_internship_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select exists (
    select 1 
    from public.internships i
    where i.id = target_internship_id
      and (
        -- Matches strictly via canonical, admin-authorized industry_users table
        i.industry_id in (
          select iu.industry_id from public.industry_users iu where iu.user_id = auth.uid()
        )
        -- Matches if the internship company_name matches a company the supervisor is verified for in industry_users
        or exists (
          select 1
          from public.industry_users iu
          join public.industries ind on ind.id = iu.industry_id
          where iu.user_id = auth.uid()
            and i.company_name = ind.name
        )
      )
  );
$$;

revoke all on function public.is_internship_authorized_for_supervisor(uuid) from public;
grant execute on function public.is_internship_authorized_for_supervisor(uuid) to authenticated;

-- 3. Strict RLS Policies for industries and industry_users
drop policy if exists "Industry supervisors can view their assigned industry" on public.industries;
create policy "Industry supervisors can view their assigned industry"
  on public.industries for select
  using (
    id in (select iu.industry_id from public.industry_users iu where iu.user_id = auth.uid())
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  );

drop policy if exists "Industry supervisors view own mapping" on public.industry_users;
create policy "Industry supervisors view own mapping"
  on public.industry_users for select
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  );

-- Only Admin or T&P Officers can assign or modify industry_users mappings
drop policy if exists "Admin and TNP manage industry_users insert" on public.industry_users;
create policy "Admin and TNP manage industry_users insert"
  on public.industry_users for insert
  with check (
    exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('tp_officer', 'admin', 'tnp')
    )
  );

drop policy if exists "Admin and TNP manage industry_users update" on public.industry_users;
create policy "Admin and TNP manage industry_users update"
  on public.industry_users for update
  using (
    exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('tp_officer', 'admin', 'tnp')
    )
  )
  with check (
    exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('tp_officer', 'admin', 'tnp')
    )
  );

drop policy if exists "Admin and TNP manage industry_users delete" on public.industry_users;
create policy "Admin and TNP manage industry_users delete"
  on public.industry_users for delete
  using (
    exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('tp_officer', 'admin', 'tnp')
    )
  );

-- 4. Strict RLS Policies for Internships Table (Industry Isolation)
drop policy if exists "Industry supervisors can view only assigned company internships" on public.internships;
drop policy if exists "internships read" on public.internships;
create policy "Industry supervisors can view only assigned company internships"
  on public.internships for select
  using (
    -- Industry supervisors: view internships assigned strictly to their verified company
    public.is_internship_authorized_for_supervisor(id)
    -- Students: view only their own internships
    or auth.uid() = student_id
    -- Faculty & T&P: view internships within academic scope
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  );

-- 5. Strict RLS Policies for Attendance Table (Industry Isolation)
drop policy if exists "Industry reps can view attendance of assigned students" on public.attendance;
drop policy if exists "Industry reps can insert/update attendance of assigned students" on public.attendance;
drop policy if exists "Industry reps can update attendance records of assigned students" on public.attendance;
drop policy if exists "Industry supervisors view attendance for company interns only" on public.attendance;
drop policy if exists "Industry supervisors insert attendance for company interns only" on public.attendance;
drop policy if exists "Industry supervisors update attendance for company interns only" on public.attendance;

create policy "Industry supervisors view attendance for company interns only"
  on public.attendance for select
  using (
    public.is_internship_authorized_for_supervisor(internship_id)
    or auth.uid() = student_id
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  );

create policy "Industry supervisors insert attendance for company interns only"
  on public.attendance for insert
  with check (
    public.is_internship_authorized_for_supervisor(internship_id)
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  );

create policy "Industry supervisors update attendance for company interns only"
  on public.attendance for update
  using (
    public.is_internship_authorized_for_supervisor(internship_id)
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  )
  with check (
    public.is_internship_authorized_for_supervisor(internship_id)
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  );

-- 6. Strict RLS Policies for Evaluations Table (Industry Isolation & Faculty Visibility)
drop policy if exists "Industry supervisors view company evaluations only" on public.evaluations;
drop policy if exists "Industry supervisors insert company evaluations only" on public.evaluations;
drop policy if exists "Industry supervisors update company evaluations only" on public.evaluations;

create policy "Industry supervisors view company evaluations only"
  on public.evaluations for select
  using (
    public.is_internship_authorized_for_supervisor(internship_id)
    or auth.uid() = student_id
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  );

create policy "Industry supervisors insert company evaluations only"
  on public.evaluations for insert
  with check (
    public.is_internship_authorized_for_supervisor(internship_id)
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  );

create policy "Industry supervisors update company evaluations only"
  on public.evaluations for update
  using (
    public.is_internship_authorized_for_supervisor(internship_id)
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  )
  with check (
    public.is_internship_authorized_for_supervisor(internship_id)
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  );

-- 7. Strict RLS Policies for Internship Documents Table (Offer letters & Certificates)
drop policy if exists "Industry reps can view assigned students documents" on public.internship_documents;
drop policy if exists "Industry reps can update assigned students documents verification" on public.internship_documents;
drop policy if exists "Industry supervisors view documents for company interns only" on public.internship_documents;
drop policy if exists "Industry supervisors update documents for company interns only" on public.internship_documents;
drop policy if exists "Faculty can view monitored students documents" on public.internship_documents;
drop policy if exists "Faculty can update students documents verification" on public.internship_documents;
drop policy if exists "docs read" on public.internship_documents;

create policy "Industry supervisors view documents for company interns only"
  on public.internship_documents for select
  using (
    public.is_internship_authorized_for_supervisor(internship_id)
    or exists (
      select 1 from public.internships i where i.id = internship_documents.internship_id and i.student_id = auth.uid()
    )
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  );

create policy "Industry supervisors update documents for company interns only"
  on public.internship_documents for update
  using (
    public.is_internship_authorized_for_supervisor(internship_id)
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  )
  with check (
    public.is_internship_authorized_for_supervisor(internship_id)
    or exists (
      select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
    )
  );

-- 8. Storage Bucket Data Isolation for 'internship-docs'
-- Storage object paths follow the standard schema: <student_id>/<internship_id>/<filename>
-- SECURITY CRITICAL:
-- 1. Validates that the 2nd path segment matches a valid UUID format using regex to prevent SQL injection or path traversal.
-- 2. Checks public.is_internship_authorized_for_supervisor() with the parsed UUID.
-- 3. Drops legacy overly permissive storage read policies.
drop policy if exists "docs storage read" on storage.objects;
drop policy if exists "Industry supervisors read documents for assigned interns only" on storage.objects;

create policy "Industry supervisors read documents for assigned interns only"
  on storage.objects for select
  using (
    bucket_id = 'internship-docs'
    and (
      -- Student accessing own uploaded files: path starts with their user ID
      (storage.foldername(name))[1] = auth.uid()::text
      -- Faculty, T&P Officer, Admin authorized roles
      or exists (
        select 1 from public.profiles p where p.id = auth.uid() and p.role in ('faculty', 'tp_officer', 'admin', 'tnp')
      )
      -- Industry supervisor for the authorized internship:
      -- Enforces UUID regex syntax on segment 2 before casting and checks authorization
      or (
        (storage.foldername(name))[2] is not null
        and (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and public.is_internship_authorized_for_supervisor(((storage.foldername(name))[2])::uuid)
      )
    )
  );
