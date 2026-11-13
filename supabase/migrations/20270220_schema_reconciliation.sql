-- ============================================================================
-- Migration: 20270220_schema_reconciliation.sql
-- Description: Safely adds missing optional columns queried by Flutter/Backend
--              clients (profiles, itrs, evaluations) and reloads PostgREST cache.
-- NOTE: Prepared for review; do not execute against production without approval.
-- ============================================================================

-- 1. Profile metadata columns used by Industry & Auth workflows
alter table if exists public.profiles
  add column if not exists company_name text,
  add column if not exists designation text;

-- 2. ITR certificate & evaluation summary columns
alter table if exists public.itrs
  add column if not exists certificate_status text default 'pending',
  add column if not exists certificate_url text,
  add column if not exists evaluation_score double precision,
  add column if not exists evaluation_grade text;

-- 3. Evaluation rubric breakdown & certificate status columns
alter table if exists public.evaluations
  add column if not exists itr_id uuid,
  add column if not exists technical_score double precision default 0,
  add column if not exists work_quality_score double precision default 0,
  add column if not exists punctuality_score double precision default 0,
  add column if not exists presentation_score double precision default 0,
  add column if not exists certificate_status text default 'pending',
  add column if not exists certificate_verified_at timestamptz;

create index if not exists idx_evaluations_itr_id on public.evaluations(itr_id);

-- 4. Reload PostgREST schema cache
notify pgrst, 'reload schema';
