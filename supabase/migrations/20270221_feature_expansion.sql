-- =====================================================================
-- Migration: 20270221_feature_expansion.sql
-- Description: Adds tables and triggers for Evaluation History / Audit Log,
-- Company Affiliation Requests, ERP Sync Lifecycle Logs, and enhanced
-- ITR status change notifications.
-- =====================================================================

-- 1. Evaluation History Audit Log Table
CREATE TABLE IF NOT EXISTS public.evaluation_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evaluation_id uuid REFERENCES public.evaluations(id) ON DELETE CASCADE,
  internship_id uuid NOT NULL,
  student_id uuid,
  evaluator_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  evaluator_name text,
  previous_score double precision,
  new_score double precision,
  previous_grade text,
  new_grade text,
  previous_status text,
  new_status text,
  remarks text,
  changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eval_history_internship ON public.evaluation_history(internship_id);
CREATE INDEX IF NOT EXISTS idx_eval_history_evaluator ON public.evaluation_history(evaluator_id);

-- 2. Company Affiliation Requests Table
CREATE TABLE IF NOT EXISTS public.company_affiliation_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  company_name text NOT NULL,
  company_address text,
  contact_email text,
  contact_phone text,
  designation text,
  website text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  review_remarks text,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affil_requests_user ON public.company_affiliation_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_affil_requests_status ON public.company_affiliation_requests(status);

-- 3. ERP Sync Lifecycle Logs Table
CREATE TABLE IF NOT EXISTS public.erp_sync_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  internship_id uuid NOT NULL,
  student_id uuid,
  evaluation_score double precision,
  evaluation_grade text,
  sync_status text NOT NULL DEFAULT 'eligible' CHECK (sync_status IN ('pending', 'eligible', 'synced', 'failed')),
  academic_credits integer NOT NULL DEFAULT 4,
  synced_at timestamptz,
  sync_attempt integer NOT NULL DEFAULT 1,
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (internship_id)
);

CREATE INDEX IF NOT EXISTS idx_erp_sync_status ON public.erp_sync_logs(sync_status);

-- 4. Enable Row Level Security (RLS) on new tables
ALTER TABLE public.evaluation_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_affiliation_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.erp_sync_logs ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for evaluation_history
DROP POLICY IF EXISTS "evaluation_history_staff_read" ON public.evaluation_history;
CREATE POLICY "evaluation_history_staff_read" ON public.evaluation_history
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role::text IN ('faculty', 'faculty_mentor', 'tp_officer', 'tnp', 'admin', 'industry_supervisor', 'industry')
    )
  );

DROP POLICY IF EXISTS "evaluation_history_staff_insert" ON public.evaluation_history;
CREATE POLICY "evaluation_history_staff_insert" ON public.evaluation_history
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role::text IN ('faculty', 'faculty_mentor', 'tp_officer', 'tnp', 'admin', 'industry_supervisor', 'industry')
    )
  );

-- 6. RLS Policies for company_affiliation_requests
DROP POLICY IF EXISTS "affil_requests_user_read" ON public.company_affiliation_requests;
CREATE POLICY "affil_requests_user_read" ON public.company_affiliation_requests
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role::text IN ('faculty', 'tp_officer', 'tnp', 'admin')
    )
  );

DROP POLICY IF EXISTS "affil_requests_user_insert" ON public.company_affiliation_requests;
CREATE POLICY "affil_requests_user_insert" ON public.company_affiliation_requests
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "affil_requests_admin_update" ON public.company_affiliation_requests;
CREATE POLICY "affil_requests_admin_update" ON public.company_affiliation_requests
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role::text IN ('tp_officer', 'tnp', 'admin')
    )
  );

-- 7. RLS Policies for erp_sync_logs
DROP POLICY IF EXISTS "erp_sync_staff_read" ON public.erp_sync_logs;
CREATE POLICY "erp_sync_staff_read" ON public.erp_sync_logs
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role::text IN ('tp_officer', 'tnp', 'admin', 'faculty_mentor')
    )
  );

-- 8. Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';
