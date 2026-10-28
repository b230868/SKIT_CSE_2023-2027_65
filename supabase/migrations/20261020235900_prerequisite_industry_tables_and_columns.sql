-- =====================================================================
-- Migration: 20261020235900_prerequisite_industry_tables_and_columns.sql
-- Description: Additive, safe DDL prerequisite that establishes canonical definitions
-- for public.industries, public.industry_users, public.attendance, public.evaluations,
-- and public.verifications, alongside missing foreign keys/columns on public.internships.
-- NOTE: Prepared as an unexecuted prerequisite script for Supabase staging.
-- DO NOT RUN AGAINST PRODUCTION.
-- =====================================================================

-- 1. Ensure uuid extension is available
create extension if not exists "uuid-ossp";

-- 2. Ensure public.industries exists
create table if not exists public.industries (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  website text,
  address text,
  contact_email text,
  contact_phone text,
  is_verified boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. Ensure public.industry_users mapping table exists
create table if not exists public.industry_users (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  industry_id uuid not null references public.industries(id) on delete cascade,
  assigned_by uuid references public.profiles(id) on delete set null,
  assigned_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, industry_id)
);

-- Unique index to prevent multi-company assignment conflict if 1:1 primary assignment is desired
create index if not exists idx_industry_users_user_id on public.industry_users(user_id);
create index if not exists idx_industry_users_industry_id on public.industry_users(industry_id);

-- 4. Ensure public.internships has industry_id column
alter table public.internships
  add column if not exists industry_id uuid references public.industries(id) on delete set null,
  add column if not exists company_id uuid references auth.users(id) on delete set null,
  add column if not exists internship_title text;

create index if not exists idx_internships_industry_id on public.internships(industry_id);

-- 5. Ensure public.attendance table exists
create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  internship_id uuid not null references public.internships(id) on delete cascade,
  student_id uuid not null references public.profiles(id) on delete cascade,
  date date not null,
  status text not null default 'present' check (status in ('present', 'absent', 'leave')),
  marked_by uuid references public.profiles(id) on delete set null,
  remarks text,
  created_at timestamptz not null default now(),
  unique (internship_id, date)
);

create index if not exists idx_attendance_internship_date on public.attendance(internship_id, date);
create index if not exists idx_attendance_student_id on public.attendance(student_id);

-- 6. Ensure public.evaluations table exists
create table if not exists public.evaluations (
  id uuid primary key default gen_random_uuid(),
  internship_id uuid not null references public.internships(id) on delete cascade,
  student_id uuid references public.profiles(id) on delete cascade,
  industry_id uuid references public.industries(id) on delete set null,
  evaluator_id uuid references public.profiles(id) on delete set null,
  itr_id uuid,
  technical_score double precision default 0,
  work_quality_score double precision default 0,
  punctuality_score double precision default 0,
  presentation_score double precision default 0,
  total_score double precision not null default 0 check (total_score between 0 and 100),
  score double precision default 0,
  marks double precision default 0,
  grade text not null default 'F',
  status text not null default 'pending' check (status in ('pending', 'in_progress', 'verified', 'completed', 'approved', 'rejected')),
  feedback text,
  remarks text,
  certificate_status text default 'pending',
  certificate_verified_at timestamptz,
  evaluation_date date default current_date,
  submitted_at timestamptz,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (internship_id)
);

create index if not exists idx_evaluations_internship_id on public.evaluations(internship_id);
create index if not exists idx_evaluations_industry_id on public.evaluations(industry_id);

-- 7. Ensure public.verifications audit table exists
create table if not exists public.verifications (
  id uuid primary key default gen_random_uuid(),
  internship_id uuid not null references public.internships(id) on delete cascade,
  itr_id uuid,
  verifier_id uuid references public.profiles(id) on delete set null,
  status text not null default 'verified',
  remarks text,
  verified_at timestamptz not null default now()
);

create index if not exists idx_verifications_internship_id on public.verifications(internship_id);
