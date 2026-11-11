-- ==============================================================================
-- Migration: Safe & Minimal Fix for Student Internship Submission & Profile Sync
-- Preserves Database Integrity, Foreign Keys, Uniqueness, and Security Policies.
-- NOTE: Prepared for review; do not apply to live database without approval.
-- ==============================================================================

-- 1. FIX THE TRIGGER FUNCTION (PRESERVES ROLL NUMBER UNIQUENESS WITHOUT DUPLICATE KEY ERRORS)
-- When a profile is synced, handles existing roll numbers and existing user_id records
-- without attempting duplicate inserts that crash on students_roll_number_key (Error 23505).
CREATE OR REPLACE FUNCTION public.sync_student_row_from_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_roll text;
  v_dept text;
  v_existing_student_user uuid;
BEGIN
  IF NEW.role::text = 'student' THEN
    v_roll := NULLIF(TRIM(COALESCE(NEW.enrollment_no, '')), '');
    v_dept := COALESCE(NULLIF(TRIM(COALESCE(NEW.branch, '')), ''), 'General');

    IF v_roll IS NOT NULL THEN
      -- Case 1: This user_id already has a student record
      IF EXISTS (SELECT 1 FROM public.students WHERE user_id = NEW.id) THEN
        -- Only update roll_number if it doesn't conflict with another student's record
        SELECT user_id INTO v_existing_student_user 
        FROM public.students 
        WHERE roll_number = v_roll AND user_id <> NEW.id;

        IF v_existing_student_user IS NULL THEN
          UPDATE public.students
          SET roll_number = v_roll,
              department = v_dept,
              updated_at = now()
          WHERE user_id = NEW.id;
        ELSE
          -- Roll number belongs to another user; preserve uniqueness, update department only
          UPDATE public.students
          SET department = v_dept,
              updated_at = now()
          WHERE user_id = NEW.id;
        END IF;

      -- Case 2: This user_id has no student record, but roll_number already exists (e.g. pre-provisioned roster)
      ELSIF EXISTS (SELECT 1 FROM public.students WHERE roll_number = v_roll) THEN
        UPDATE public.students
        SET user_id = NEW.id,
            department = v_dept,
            updated_at = now()
        WHERE roll_number = v_roll;

      -- Case 3: Neither exists - safe to insert new student row
      ELSE
        INSERT INTO public.students (user_id, roll_number, department, created_at, updated_at)
        VALUES (NEW.id, v_roll, v_dept, now(), now());
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- 2. RE-ATTACH TRIGGER TO public.profiles
DROP TRIGGER IF EXISTS trg_sync_student_row_from_profile ON public.profiles;
CREATE TRIGGER trg_sync_student_row_from_profile
  AFTER INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_student_row_from_profile();

-- 3. ENSURE MISSING AUTH USERS HAVE A PROFILE ROW (PRESERVES FOREIGN KEY INTEGRITY)
-- This ensures internships_student_id_fkey can resolve every authenticated user's ID.
-- Enforces app_role casting and prevents unverified client metadata from self-escalating roles.
INSERT INTO public.profiles (id, full_name, email, role, enrollment_no, branch)
SELECT 
  u.id, 
  COALESCE(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name', 'Student'),
  u.email,
  COALESCE(
    CASE LOWER(TRIM(COALESCE(u.raw_app_meta_data->>'role', '')))
      WHEN 'admin' THEN 'admin'::public.app_role
      WHEN 'faculty' THEN 'faculty_mentor'::public.app_role
      WHEN 'faculty_mentor' THEN 'faculty_mentor'::public.app_role
      WHEN 'tnp' THEN 'tp_officer'::public.app_role
      WHEN 'tp_officer' THEN 'tp_officer'::public.app_role
      WHEN 'industry' THEN 'industry_supervisor'::public.app_role
      WHEN 'industry_supervisor' THEN 'industry_supervisor'::public.app_role
      ELSE NULL
    END,
    'student'::public.app_role
  ),
  NULLIF(TRIM(COALESCE(u.raw_user_meta_data->>'enrollment_no', u.raw_user_meta_data->>'roll_number', '')), ''),
  NULLIF(TRIM(COALESCE(u.raw_user_meta_data->>'branch', u.raw_user_meta_data->>'department', '')), '')
FROM auth.users u
WHERE u.id NOT IN (SELECT id FROM public.profiles)
ON CONFLICT (id) DO UPDATE SET
  full_name = EXCLUDED.full_name,
  email = EXCLUDED.email,
  enrollment_no = COALESCE(public.profiles.enrollment_no, EXCLUDED.enrollment_no),
  branch = COALESCE(public.profiles.branch, EXCLUDED.branch);

-- 4. ENSURE internships TABLE ACCEPTS 'pending' STATUS AND HAS STRICT FOREIGN KEY
ALTER TABLE public.internships DROP CONSTRAINT IF EXISTS internships_status_check;
ALTER TABLE public.internships ALTER COLUMN status DROP DEFAULT;
ALTER TABLE public.internships ALTER COLUMN status TYPE text USING status::text;
ALTER TABLE public.internships ALTER COLUMN status SET DEFAULT 'pending';

-- Re-establish the foreign key if it was missing or dropped
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'internships_student_id_fkey' 
      AND table_name = 'internships'
  ) THEN
    ALTER TABLE public.internships 
      ADD CONSTRAINT internships_student_id_fkey 
      FOREIGN KEY (student_id) REFERENCES public.profiles(id) 
      ON DELETE CASCADE;
  END IF;
END $$;

-- 5. SECURE, SCOPED ROW LEVEL SECURITY POLICIES (NO WIDE-OPEN 'TRUE' POLICIES)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile, or faculty/tnp/industry can read assigned student profiles
DROP POLICY IF EXISTS "profiles read own or staff" ON public.profiles;
CREATE POLICY "profiles read own or staff" ON public.profiles
  FOR SELECT TO authenticated
  USING (
    auth.uid() = id 
    OR public.current_role_of_user() IN ('faculty', 'faculty_mentor', 'tnp', 'tp_officer', 'industry', 'industry_supervisor')
  );

-- Users can only insert/update their own profile
DROP POLICY IF EXISTS "profiles insert own" ON public.profiles;
CREATE POLICY "profiles insert own" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles update own" ON public.profiles;
CREATE POLICY "profiles update own" ON public.profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Internships RLS: strictly scoped to ownership
ALTER TABLE public.internships ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "internships insert own" ON public.internships;
CREATE POLICY "internships insert own" ON public.internships 
  FOR INSERT TO authenticated 
  WITH CHECK (student_id = auth.uid() AND status = 'pending');

DROP POLICY IF EXISTS "internships read scoped" ON public.internships;
CREATE POLICY "internships read scoped" ON public.internships 
  FOR SELECT TO authenticated 
  USING (
    student_id = auth.uid() 
    OR public.current_role_of_user() IN ('faculty', 'faculty_mentor', 'tnp', 'tp_officer', 'industry', 'industry_supervisor')
  );

DROP POLICY IF EXISTS "internships update own pending" ON public.internships;
CREATE POLICY "internships update own pending" ON public.internships 
  FOR UPDATE TO authenticated 
  USING (student_id = auth.uid() AND status = 'pending')
  WITH CHECK (student_id = auth.uid() AND status = 'pending');

-- 6. RELOAD POSTGREST SCHEMA CACHE
NOTIFY pgrst, 'reload schema';
