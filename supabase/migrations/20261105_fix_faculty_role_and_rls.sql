-- ============================================================================
-- Migration: Fix Faculty Role Normalization, Registration Trigger, and RLS
-- Date: 2026-11-05
-- Description: Ensures faculty members can seamlessly sign up, log in,
--              access the faculty dashboard, review approvals, and monitor students.
-- ============================================================================

-- 1. Helper function: normalizes roles from profiles so RLS works seamlessly
CREATE OR REPLACE FUNCTION public.current_role_of_user()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT CASE 
    WHEN LOWER(TRIM(role::text)) IN ('faculty', 'faculty_mentor') THEN 'faculty'
    WHEN LOWER(TRIM(role::text)) IN ('tnp', 'tp_officer') THEN 'tnp'
    WHEN LOWER(TRIM(role::text)) IN ('industry', 'industry_supervisor') THEN 'industry'
    WHEN LOWER(TRIM(role::text)) IN ('admin') THEN 'admin'
    ELSE 'student'
  END
  FROM public.profiles WHERE id = auth.uid()
$$;

-- 2. Enhanced handle_new_user trigger function supporting Faculty & T&P signups
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_full_name text;
  v_enrollment_no text;
  v_branch text;
  v_phone text;
  v_role_str text;
  v_role public.app_role;
BEGIN
  v_full_name := NULLIF(TRIM(COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    ''
  )), '');

  IF v_full_name IS NOT NULL AND char_length(v_full_name) < 2 THEN
    v_full_name := NULL;
  END IF;

  -- Determine role from metadata (app_meta_data takes priority, fallback to user_meta_data)
  IF NEW.raw_app_meta_data IS NOT NULL AND NEW.raw_app_meta_data ? 'role' THEN
    v_role_str := LOWER(TRIM(NEW.raw_app_meta_data->>'role'));
  ELSIF NEW.raw_user_meta_data IS NOT NULL AND NEW.raw_user_meta_data ? 'role' THEN
    v_role_str := LOWER(TRIM(NEW.raw_user_meta_data->>'role'));
  ELSE
    v_role_str := 'student';
  END IF;

  -- Map to enum value, strictly preventing unauthorized 'admin' role elevation
  v_role := CASE v_role_str
    WHEN 'admin' THEN 'student'::public.app_role
    WHEN 'faculty' THEN 'faculty_mentor'::public.app_role
    WHEN 'faculty_mentor' THEN 'faculty_mentor'::public.app_role
    WHEN 'tnp' THEN 'tp_officer'::public.app_role
    WHEN 'tp_officer' THEN 'tp_officer'::public.app_role
    WHEN 'industry' THEN 'industry_supervisor'::public.app_role
    WHEN 'industry_supervisor' THEN 'industry_supervisor'::public.app_role
    ELSE 'student'::public.app_role
  END;

  v_enrollment_no := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'enrollment_no', '')), '');
  v_branch := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'branch', '')), '');
  v_phone := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'phone', '')), '');

  INSERT INTO public.profiles (
    id,
    full_name,
    email,
    role,
    enrollment_no,
    branch,
    phone
  ) VALUES (
    NEW.id,
    v_full_name,
    COALESCE(NEW.email, ''),
    v_role,
    v_enrollment_no,
    v_branch,
    v_phone
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email,
    role = CASE 
      WHEN public.profiles.role = 'student'::public.app_role AND EXCLUDED.role <> 'student'::public.app_role THEN EXCLUDED.role
      ELSE public.profiles.role
    END,
    enrollment_no = COALESCE(EXCLUDED.enrollment_no, public.profiles.enrollment_no),
    branch = COALESCE(EXCLUDED.branch, public.profiles.branch),
    phone = COALESCE(EXCLUDED.phone, public.profiles.phone);

  RETURN NEW;
END;
$$;

-- 3. Self-healing data fix: Update existing registered faculty accounts downgraded to student
UPDATE public.profiles p
SET role = 'faculty_mentor'::public.app_role
FROM auth.users u
WHERE p.id = u.id
  AND p.role = 'student'::public.app_role
  AND (
    LOWER(u.raw_user_meta_data->>'role') IN ('faculty', 'faculty_mentor')
    OR LOWER(u.raw_app_meta_data->>'role') IN ('faculty', 'faculty_mentor')
  );

-- 4. Ensure RLS policies on internships and approval_reviews permit faculty queries
DROP POLICY IF EXISTS faculty_read_internships ON public.internships;
CREATE POLICY faculty_read_internships ON public.internships
  FOR SELECT
  USING (
    public.current_role_of_user() IN ('faculty', 'tnp', 'admin')
    OR student_id = auth.uid()
    OR student_id IN (SELECT s.id FROM public.students s WHERE s.user_id = auth.uid())
  );

