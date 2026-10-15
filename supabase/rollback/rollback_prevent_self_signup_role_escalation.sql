-- ==============================================================================
-- Prashikshan Rollback Migration: Revert Role Escalation Fix
-- File: supabase/migrations/20261015154500_rollback_prevent_self_signup_role_escalation.sql
-- 
-- Description:
-- Reverts handle_new_user() to the previous version and removes admin_assign_user_role().
-- ==============================================================================

-- Step 1: Drop administrative function
DROP FUNCTION IF EXISTS public.admin_assign_user_role(uuid, public.app_role);

-- Step 2: Restore previous handle_new_user() trigger definition
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
  v_full_name text;
  v_raw_role text;
  v_role public.app_role;
  v_enrollment_no text;
  v_branch text;
  v_phone text;
BEGIN
  v_full_name := NULLIF(TRIM(COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    ''
  )), '');

  IF v_full_name IS NOT NULL AND char_length(v_full_name) < 2 THEN
    v_full_name := NULL;
  END IF;

  v_raw_role := LOWER(TRIM(COALESCE(NEW.raw_user_meta_data->>'role', 'student')));
  v_role := CASE v_raw_role
    WHEN 'industry' THEN 'industry_supervisor'::public.app_role
    WHEN 'industry_supervisor' THEN 'industry_supervisor'::public.app_role
    WHEN 'faculty' THEN 'faculty_mentor'::public.app_role
    WHEN 'faculty_mentor' THEN 'faculty_mentor'::public.app_role
    WHEN 'tnp' THEN 'tp_officer'::public.app_role
    WHEN 'tp_officer' THEN 'tp_officer'::public.app_role
    WHEN 'admin' THEN 'admin'::public.app_role
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
    department,
    phone,
    phone_number,
    is_active,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    v_full_name,
    NEW.email,
    v_role,
    v_enrollment_no,
    v_branch,
    v_branch,
    v_phone,
    CASE WHEN v_phone IS NOT NULL AND char_length(v_phone) BETWEEN 7 AND 20 THEN v_phone ELSE NULL END,
    true,
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      full_name = COALESCE(NULLIF(public.profiles.full_name, ''), EXCLUDED.full_name),
      enrollment_no = COALESCE(public.profiles.enrollment_no, EXCLUDED.enrollment_no),
      branch = COALESCE(public.profiles.branch, EXCLUDED.branch),
      department = COALESCE(public.profiles.department, EXCLUDED.department),
      phone = COALESCE(public.profiles.phone, EXCLUDED.phone),
      phone_number = COALESCE(public.profiles.phone_number, EXCLUDED.phone_number),
      updated_at = now();

  RETURN NEW;
END;
$$;
