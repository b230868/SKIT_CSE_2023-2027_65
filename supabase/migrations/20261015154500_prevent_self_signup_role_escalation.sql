-- ==============================================================================
-- Prashikshan Security Migration: Prevent Self-Signup Role Escalation
-- File: supabase/migrations/20261015154500_prevent_self_signup_role_escalation.sql
-- 
-- Description:
-- 1. Updates trigger function public.handle_new_user() so that public self-signup
--    ALWAYS defaults strictly to 'student' role.
-- 2. Completely ignores client-supplied NEW.raw_user_meta_data->>'role' to prevent
--    privilege escalation (e.g. self-assigning 'admin' or 'faculty_mentor').
-- 3. Allows elevated role assignment ONLY if set by trusted server-side
--    NEW.raw_app_meta_data (which is strictly read-only to clients and can only
--    be written by Supabase service-role/admin API).
-- 4. Creates public.admin_assign_user_role() for controlled administrative elevation,
--    enforcing authorization using IS DISTINCT FROM 'admin'::public.app_role to reject
--    NULL, missing, or non-admin caller roles.
-- 5. Explicitly restricts EXECUTE permissions: revokes from PUBLIC and anon, granting
--    only to authenticated (and service_role).
-- 6. Preserves all legitimate existing users and roles without any bulk modification.
-- ==============================================================================

-- Step 1: Replace trigger function with role-escalation patch
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
  v_role public.app_role;
BEGIN
  -- Extract and sanitize full name from user metadata
  v_full_name := NULLIF(TRIM(COALESCE(
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    ''
  )), '');

  IF v_full_name IS NOT NULL AND char_length(v_full_name) < 2 THEN
    v_full_name := NULL;
  END IF;

  -- ============================================================================
  -- SECURITY ENFORCEMENT: Self-Signup Role Hardening
  -- ----------------------------------------------------------------------------
  -- Client-supplied raw_user_meta_data->>'role' is completely IGNORED.
  -- Elevated roles can ONLY be set via raw_app_meta_data by Supabase Admin API
  -- or service-role administrative provisioning.
  -- ============================================================================
  IF NEW.raw_app_meta_data IS NOT NULL AND NEW.raw_app_meta_data ? 'role' THEN
    v_role := CASE LOWER(TRIM(NEW.raw_app_meta_data->>'role'))
      WHEN 'admin' THEN 'admin'::public.app_role
      WHEN 'faculty' THEN 'faculty_mentor'::public.app_role
      WHEN 'faculty_mentor' THEN 'faculty_mentor'::public.app_role
      WHEN 'tnp' THEN 'tp_officer'::public.app_role
      WHEN 'tp_officer' THEN 'tp_officer'::public.app_role
      WHEN 'industry' THEN 'industry_supervisor'::public.app_role
      WHEN 'industry_supervisor' THEN 'industry_supervisor'::public.app_role
      ELSE 'student'::public.app_role
    END;
  ELSE
    -- All self-signup users default strictly to student
    v_role := 'student'::public.app_role;
  END IF;

  v_enrollment_no := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'enrollment_no', '')), '');
  v_branch := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'branch', '')), '');
  v_phone := NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'phone', '')), '');

  -- Insert profile with enforced role
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
      -- Note: 'role' is intentionally NOT modified in ON CONFLICT to prevent role changes on update.

  RETURN NEW;
END;
$$;

-- Step 2: Create a secure, server-controlled administrative function for role assignment
CREATE OR REPLACE FUNCTION public.admin_assign_user_role(
  target_user_id uuid,
  new_role public.app_role
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
BEGIN
  -- ============================================================================
  -- SECURITY ENFORCEMENT: Admin Authorization Check
  -- ----------------------------------------------------------------------------
  -- Missing or NULL caller role is ALWAYS denied using IS DISTINCT FROM.
  -- Only callers with verified 'admin' role are permitted.
  -- ============================================================================
  IF (SELECT public.current_user_role()) IS DISTINCT FROM 'admin'::public.app_role THEN
    RAISE EXCEPTION 'Access denied: Only administrators can assign elevated user roles.';
  END IF;

  -- Input validation
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'Invalid target user: target_user_id cannot be NULL.';
  END IF;

  IF new_role IS NULL THEN
    RAISE EXCEPTION 'Invalid role: new_role cannot be NULL.';
  END IF;

  -- Ensure target profile exists
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = target_user_id) THEN
    RAISE EXCEPTION 'Target user profile not found.';
  END IF;

  -- Update role in public.profiles
  UPDATE public.profiles
  SET role = new_role,
      updated_at = now()
  WHERE id = target_user_id;
END;
$$;

COMMENT ON FUNCTION public.admin_assign_user_role IS 'Assigns an elevated role to a user. Restricted strictly to callers with admin role.';

-- Step 3: Explicitly restrict EXECUTE permissions
-- Revoke access from PUBLIC (default for functions) and anon (unauthenticated callers)
REVOKE ALL ON FUNCTION public.admin_assign_user_role(uuid, public.app_role) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_assign_user_role(uuid, public.app_role) FROM anon;

-- Grant EXECUTE to authenticated users only (internal authorization check restricts to admin)
GRANT EXECUTE ON FUNCTION public.admin_assign_user_role(uuid, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_user_role(uuid, public.app_role) TO service_role;

-- Revoke direct EXECUTE on trigger function from PUBLIC and anon
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM anon;

-- Explicitly grant EXECUTE on handle_new_user() to the Supabase auth admin role
-- and service roles so that the on_auth_user_created trigger on auth.users
-- executes reliably upon new user signups.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    GRANT EXECUTE ON FUNCTION public.handle_new_user() TO supabase_auth_admin;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;
  END IF;
END $$;

