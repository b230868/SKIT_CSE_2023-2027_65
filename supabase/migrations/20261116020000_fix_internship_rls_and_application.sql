-- ==============================================================================
-- Prashikshan Migration: Complete Fix for Registration Trigger & Internship Submission RLS
-- File: supabase/migrations/20261116020000_fix_internship_rls_and_application.sql
-- Description:
-- 1. Ensures public.app_role enum exists with all expected variants.
-- 2. Ensures public.profiles has all columns and permissive RLS for self-healing.
-- 3. Exception-safe handle_new_user() trigger that never crashes auth signups.
-- 4. Fixes public.internships schema, status constraints, and grants full permissions.
-- 5. Fixes RLS policies on public.internships for INSERT, SELECT, UPDATE, DELETE.
-- 6. Exception-safe notification trigger on internship submission.
-- ==============================================================================

-- 1. Ensure public.app_role enum exists with all expected variants
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

-- 2. Ensure public.profiles table and all columns exist
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL DEFAULT '',
  email text NOT NULL DEFAULT '',
  role text NOT NULL DEFAULT 'student',
  enrollment_no text,
  branch text,
  department text,
  phone text,
  phone_number text,
  is_active boolean DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS full_name text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS email text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'student',
  ADD COLUMN IF NOT EXISTS enrollment_no text,
  ADD COLUMN IF NOT EXISTS branch text,
  ADD COLUMN IF NOT EXISTS department text,
  ADD COLUMN IF NOT EXISTS phone text,
  ADD COLUMN IF NOT EXISTS phone_number text,
  ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

-- Helper: current role
CREATE OR REPLACE FUNCTION public.current_role_of_user()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(role::text, 'student') FROM public.profiles WHERE id = auth.uid() LIMIT 1;
$$;

-- 3. Exception-safe handle_new_user() trigger function
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
  v_enrollment text;
  v_branch text;
  v_phone text;
BEGIN
  v_name := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
    'Student'
  );

  v_role_raw := LOWER(TRIM(COALESCE(
    NEW.raw_app_meta_data->>'role',
    NEW.raw_user_meta_data->>'role',
    'student'
  )));

  IF v_role_raw IN ('faculty', 'faculty_mentor') THEN
    v_role_normalized := 'faculty_mentor';
  ELSIF v_role_raw IN ('tnp', 'tp_officer') THEN
    v_role_normalized := 'tp_officer';
  ELSIF v_role_raw IN ('industry', 'industry_supervisor') THEN
    v_role_normalized := 'industry_supervisor';
  ELSE
    v_role_normalized := 'student';
  END IF;

  v_enrollment := NULLIF(TRIM(COALESCE(
    NEW.raw_user_meta_data->>'enrollment_no',
    NEW.raw_user_meta_data->>'roll_number',
    ''
  )), '');

  v_branch := NULLIF(TRIM(COALESCE(
    NEW.raw_user_meta_data->>'branch',
    NEW.raw_user_meta_data->>'department',
    'CSE'
  )), '');

  v_phone := NULLIF(TRIM(COALESCE(
    NEW.raw_user_meta_data->>'phone',
    NEW.raw_user_meta_data->>'phone_number',
    ''
  )), '');

  BEGIN
    INSERT INTO public.profiles (
      id, full_name, email, role, enrollment_no, branch, department, phone, phone_number, is_active
    ) VALUES (
      NEW.id,
      v_name,
      COALESCE(NEW.email, ''),
      v_role_normalized,
      v_enrollment,
      v_branch,
      v_branch,
      v_phone,
      v_phone,
      true
    )
    ON CONFLICT (id) DO UPDATE SET
      full_name = EXCLUDED.full_name,
      email = EXCLUDED.email,
      role = EXCLUDED.role,
      enrollment_no = COALESCE(public.profiles.enrollment_no, EXCLUDED.enrollment_no),
      branch = COALESCE(public.profiles.branch, EXCLUDED.branch),
      department = COALESCE(public.profiles.department, EXCLUDED.department),
      phone = COALESCE(public.profiles.phone, EXCLUDED.phone),
      updated_at = now();
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user profiles insert failed: %', SQLERRM;
  END;

  -- If public.students table exists and role is student, auto-create student record
  IF v_role_normalized = 'student' THEN
    BEGIN
      IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'students') THEN
        INSERT INTO public.students (user_id, roll_number, department, created_at, updated_at)
        VALUES (
          NEW.id,
          COALESCE(v_enrollment, 'ENR-' || SUBSTRING(NEW.id::text, 1, 8)),
          COALESCE(v_branch, 'CSE'),
          now(),
          now()
        )
        ON CONFLICT (user_id) DO NOTHING;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'handle_new_user students insert failed: %', SQLERRM;
    END;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

GRANT EXECUTE ON FUNCTION public.handle_new_user() TO anon, authenticated, service_role, supabase_auth_admin;

-- 4. Enable RLS and permissions on public.profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles read" ON public.profiles;
DROP POLICY IF EXISTS "profiles read own or staff" ON public.profiles;
CREATE POLICY "profiles read" ON public.profiles
  FOR SELECT TO authenticated
  USING (
    auth.uid() = id
    OR public.current_role_of_user() IN ('faculty', 'faculty_mentor', 'tnp', 'tp_officer', 'industry', 'industry_supervisor', 'admin')
  );

DROP POLICY IF EXISTS "profiles insert own" ON public.profiles;
CREATE POLICY "profiles insert own" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles update own" ON public.profiles;
CREATE POLICY "profiles update own" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.profiles TO authenticated;
GRANT SELECT ON TABLE public.profiles TO anon;

-- 5. Ensure public.students table (if present) has RLS and permissions
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'students') THEN
    ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "students read" ON public.students;
    CREATE POLICY "students read" ON public.students
      FOR SELECT TO authenticated
      USING (
        user_id = auth.uid()
        OR public.current_role_of_user() IN ('faculty', 'faculty_mentor', 'tnp', 'tp_officer', 'admin')
      );

    DROP POLICY IF EXISTS "students insert own" ON public.students;
    CREATE POLICY "students insert own" ON public.students
      FOR INSERT TO authenticated
      WITH CHECK (user_id = auth.uid());

    DROP POLICY IF EXISTS "students update own" ON public.students;
    CREATE POLICY "students update own" ON public.students
      FOR UPDATE TO authenticated
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());

    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.students TO authenticated;
  END IF;
END $$;

-- 6. Ensure public.internships table and columns exist
CREATE TABLE IF NOT EXISTS public.internships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL,
  company_name text NOT NULL,
  title text NOT NULL,
  description text,
  mode text NOT NULL DEFAULT 'onsite',
  start_date date NOT NULL,
  end_date date NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  progress int NOT NULL DEFAULT 0,
  industry_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.internships
  ADD COLUMN IF NOT EXISTS company_name text,
  ADD COLUMN IF NOT EXISTS title text,
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS mode text DEFAULT 'onsite',
  ADD COLUMN IF NOT EXISTS start_date date,
  ADD COLUMN IF NOT EXISTS end_date date,
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS progress int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS industry_id uuid,
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- Drop overly restrictive status and mode check constraints
ALTER TABLE public.internships DROP CONSTRAINT IF EXISTS internships_status_check;
ALTER TABLE public.internships DROP CONSTRAINT IF EXISTS internships_mode_check;
ALTER TABLE public.internships DROP CONSTRAINT IF EXISTS internships_check;

-- Ensure status default is 'pending'
ALTER TABLE public.internships ALTER COLUMN status SET DEFAULT 'pending';

-- 7. Fix ROW LEVEL SECURITY on public.internships
ALTER TABLE public.internships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "internships insert own" ON public.internships;
DROP POLICY IF EXISTS "Students can insert own internships" ON public.internships;
DROP POLICY IF EXISTS "Users can insert own internships" ON public.internships;
DROP POLICY IF EXISTS "internships insert policy" ON public.internships;

CREATE POLICY "internships insert own" ON public.internships
  FOR INSERT TO authenticated
  WITH CHECK (
    (
      student_id = auth.uid()
      OR (
        EXISTS (SELECT 1 FROM public.students s WHERE s.id = internships.student_id AND s.user_id = auth.uid())
      )
    )
    AND (status IS NULL OR LOWER(status::text) IN ('pending', 'planned', 'active'))
  );

DROP POLICY IF EXISTS "internships read" ON public.internships;
DROP POLICY IF EXISTS "internships read scoped" ON public.internships;
DROP POLICY IF EXISTS "Students can view own internships" ON public.internships;

CREATE POLICY "internships read" ON public.internships
  FOR SELECT TO authenticated
  USING (
    student_id = auth.uid()
    OR (
      EXISTS (SELECT 1 FROM public.students s WHERE s.id = internships.student_id AND s.user_id = auth.uid())
    )
    OR public.current_role_of_user() IN ('faculty', 'faculty_mentor', 'tnp', 'tp_officer', 'industry', 'industry_supervisor', 'admin')
  );

DROP POLICY IF EXISTS "internships update own pending" ON public.internships;
CREATE POLICY "internships update own pending" ON public.internships
  FOR UPDATE TO authenticated
  USING (
    student_id = auth.uid()
    OR (
      EXISTS (SELECT 1 FROM public.students s WHERE s.id = internships.student_id AND s.user_id = auth.uid())
    )
  )
  WITH CHECK (
    student_id = auth.uid()
    OR (
      EXISTS (SELECT 1 FROM public.students s WHERE s.id = internships.student_id AND s.user_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "internships delete own pending" ON public.internships;
CREATE POLICY "internships delete own pending" ON public.internships
  FOR DELETE TO authenticated
  USING (
    student_id = auth.uid()
    OR (
      EXISTS (SELECT 1 FROM public.students s WHERE s.id = internships.student_id AND s.user_id = auth.uid())
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.internships TO authenticated;

-- 8. Exception-safe submission trigger
CREATE OR REPLACE FUNCTION public.notify_on_internship_submitted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  BEGIN
    v_user_id := COALESCE(
      (SELECT s.user_id FROM public.students s WHERE s.id = NEW.student_id LIMIT 1),
      NEW.student_id
    );

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
      INSERT INTO public.notifications (user_id, title, body, type, internship_id)
      VALUES (
        v_user_id,
        'Application received',
        'Your application for ' || COALESCE(NEW.title, 'the internship') || ' was submitted.',
        'application',
        NEW.id
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Could not create notification on internship submit: %', SQLERRM;
  END;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_internship_submitted ON public.internships;
CREATE TRIGGER on_internship_submitted
  AFTER INSERT ON public.internships
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_internship_submitted();

-- 9. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
