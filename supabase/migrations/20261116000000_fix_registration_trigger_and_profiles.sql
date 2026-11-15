-- ============================================================================
-- Prashikshan Database Migration: Fix Registration Trigger & Profiles Schema
-- File: supabase/migrations/20261116000000_fix_registration_trigger_and_profiles.sql
-- Description:
-- 1. Ensures public.app_role enum exists with all expected role variants.
-- 2. Ensures all profile columns exist with permissive defaults and nullability.
-- 3. Replaces public.handle_new_user() with an exception-safe trigger function
--    that NEVER aborts user registration in auth.users.
-- 4. Configures RLS policies to allow authenticated self-healing profile upserts.
-- ============================================================================

-- Step 1: Ensure app_role enum exists with all values
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.app_role AS ENUM (
      'student',
      'faculty_mentor',
      'tp_officer',
      'industry_supervisor',
      'admin'
    );
  END IF;
END $$;

-- Step 2: Ensure all expected columns exist on public.profiles
ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS full_name text DEFAULT '',
  ADD COLUMN IF NOT EXISTS email text DEFAULT '',
  ADD COLUMN IF NOT EXISTS enrollment_no text,
  ADD COLUMN IF NOT EXISTS branch text,
  ADD COLUMN IF NOT EXISTS department text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS phone_number text,
  ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Step 3: Recreate handle_new_user() with complete exception safety
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_name text;
  v_role_raw text;
  v_role_normalized text;
BEGIN
  -- Extract name safely
  v_name := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
    'Student'
  );

  -- Determine role from metadata
  v_role_raw := LOWER(TRIM(COALESCE(
    NEW.raw_app_meta_data->>'role',
    NEW.raw_user_meta_data->>'role',
    'student'
  )));

  -- Normalize role string
  IF v_role_raw IN ('faculty', 'faculty_mentor') THEN
    v_role_normalized := 'faculty_mentor';
  ELSIF v_role_raw IN ('tnp', 'tp_officer') THEN
    v_role_normalized := 'tp_officer';
  ELSIF v_role_raw IN ('industry', 'industry_supervisor') THEN
    v_role_normalized := 'industry_supervisor';
  ELSE
    v_role_normalized := 'student';
  END IF;

  -- Attempt insert handling both text role and enum app_role schemas
  BEGIN
    -- Try dynamic execution with app_role cast first if enum exists
    EXECUTE $dyn$
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
        $1,
        $2,
        COALESCE($3, ''),
        $4::public.app_role,
        $5,
        $6,
        $6,
        $7,
        $7,
        true,
        now(),
        now()
      )
      ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        email = COALESCE(NULLIF(EXCLUDED.email, ''), public.profiles.email),
        enrollment_no = COALESCE(EXCLUDED.enrollment_no, public.profiles.enrollment_no),
        branch = COALESCE(EXCLUDED.branch, public.profiles.branch),
        department = COALESCE(EXCLUDED.department, public.profiles.department),
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
        updated_at = now()
    $dyn$
    USING
      NEW.id,
      v_name,
      NEW.email,
      v_role_normalized,
      NULLIF(TRIM(NEW.raw_user_meta_data->>'enrollment_no'), ''),
      NULLIF(TRIM(NEW.raw_user_meta_data->>'branch'), ''),
      NULLIF(TRIM(NEW.raw_user_meta_data->>'phone'), '');

  EXCEPTION WHEN OTHERS THEN
    -- Fallback for schemas where role is plain text
    BEGIN
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
        v_name,
        COALESCE(NEW.email, ''),
        CASE
          WHEN v_role_normalized = 'faculty_mentor' THEN 'faculty'
          WHEN v_role_normalized = 'tp_officer' THEN 'tnp'
          WHEN v_role_normalized = 'industry_supervisor' THEN 'industry'
          ELSE 'student'
        END,
        NULLIF(TRIM(NEW.raw_user_meta_data->>'enrollment_no'), ''),
        NULLIF(TRIM(NEW.raw_user_meta_data->>'branch'), ''),
        NULLIF(TRIM(NEW.raw_user_meta_data->>'branch'), ''),
        NULLIF(TRIM(NEW.raw_user_meta_data->>'phone'), ''),
        NULLIF(TRIM(NEW.raw_user_meta_data->>'phone'), ''),
        true,
        now(),
        now()
      )
      ON CONFLICT (id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
      -- CRITICAL: Never abort auth.users signup transaction.
      -- If profile insertion fails, client-side fetchProfile() will self-heal.
      NULL;
    END;
  END;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Unhandled outer failure safeguard: Ensure signup never returns 500
  RETURN NEW;
END;
$$;

-- Step 4: Ensure trigger is active on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Step 5: Grant execution permissions
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO anon, authenticated, service_role, supabase_auth_admin;

-- Step 6: Enable RLS and add self-healing insert policy for profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles insert own" ON public.profiles;
CREATE POLICY "profiles insert own" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles read own or staff" ON public.profiles;
CREATE POLICY "profiles read own or staff" ON public.profiles
  FOR SELECT TO authenticated
  USING (
    auth.uid() = id 
    OR public.current_role_of_user() IN ('faculty', 'faculty_mentor', 'tnp', 'tp_officer', 'industry', 'industry_supervisor', 'admin')
  );

NOTIFY pgrst, 'reload schema';
