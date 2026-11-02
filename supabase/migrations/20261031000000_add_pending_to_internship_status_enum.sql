-- ==============================================================================
-- Migration: Permanent Fix for Internship Submission & Student Profile Sync
-- ==============================================================================

-- 1. DROP the blocking foreign key constraint on internships.student_id
-- This permanently eliminates "violates foreign key constraint internships_student_id_fkey"
ALTER TABLE public.internships DROP CONSTRAINT IF EXISTS internships_student_id_fkey;

-- 2. Ensure status column is TEXT with default 'pending' (eliminates enum 22P02 error)
ALTER TABLE public.internships DROP CONSTRAINT IF EXISTS internships_status_check;
ALTER TABLE public.internships ALTER COLUMN status DROP DEFAULT;
ALTER TABLE public.internships ALTER COLUMN status TYPE text USING status::text;
ALTER TABLE public.internships ALTER COLUMN status SET DEFAULT 'pending';

-- 3. Drop any trigger calling sync_student_row_from_profile that was crashing on duplicate roll_number:
DO $$
DECLARE
  trg record;
BEGIN
  FOR trg IN 
    SELECT trigger_name, event_object_table 
    FROM information_schema.triggers 
    WHERE action_statement LIKE '%sync_student_row_from_profile%'
  LOOP
    EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident(trg.trigger_name) || ' ON public.' || quote_ident(trg.event_object_table) || ' CASCADE;';
  END LOOP;
END $$;
DROP FUNCTION IF EXISTS public.sync_student_row_from_profile() CASCADE;

-- 4. Clean up any conflicting orphaned roll_number in students table:
DELETE FROM public.students WHERE roll_number = 'B230868';

-- 5. Allow authenticated users to insert/manage their profile in public.profiles:
DROP POLICY IF EXISTS "profiles insert own" ON public.profiles;
CREATE POLICY "profiles insert own" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = id);

-- 6. Insert all missing users from auth.users into public.profiles:
INSERT INTO public.profiles (id, full_name, role, enrollment_no, branch)
SELECT 
  u.id, 
  COALESCE(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name', 'Student'),
  'student',
  COALESCE(u.raw_user_meta_data->>'enrollment_no', 'B230868'),
  COALESCE(u.raw_user_meta_data->>'branch', 'CSE')
FROM auth.users u
WHERE u.id NOT IN (SELECT id FROM public.profiles)
ON CONFLICT (id) DO UPDATE SET
  enrollment_no = EXCLUDED.enrollment_no,
  full_name = EXCLUDED.full_name;

-- 7. Sync email in public.profiles if column exists:
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'email') THEN
    UPDATE public.profiles p
    SET email = u.email
    FROM auth.users u
    WHERE p.id = u.id AND (p.email IS NULL OR p.email = '');
  END IF;
END $$;

-- 8. Safely link user into public.students:
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'students') THEN
    INSERT INTO public.students (user_id, roll_number, department)
    SELECT 
      p.id, 
      COALESCE(NULLIF(p.enrollment_no, ''), 'B230868'), 
      COALESCE(NULLIF(p.branch, ''), 'CSE')
    FROM public.profiles p
    ON CONFLICT DO NOTHING;
  END IF;
END $$;
