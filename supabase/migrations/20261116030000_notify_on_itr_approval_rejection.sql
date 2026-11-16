-- ==============================================================================
-- Prashikshan Migration: Notify Student on ITR Approval or Rejection
-- File: supabase/migrations/20261116030000_notify_on_itr_approval_rejection.sql
-- Description:
-- 1. Ensures notifications table and constraints allow ITR notifications.
-- 2. Adds trigger on public.itrs: sends notification when status changes to
--    'approved', 'rejected', or 'changes_requested'.
-- 3. Ensures approval_reviews synchronization with itrs table and student notifications.
-- ==============================================================================

-- 1. Ensure public.notifications table exists
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  type text NOT NULL DEFAULT 'document',
  internship_id uuid REFERENCES public.internships(id) ON DELETE CASCADE,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Ensure columns exist
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS type text NOT NULL DEFAULT 'document',
  ADD COLUMN IF NOT EXISTS internship_id uuid REFERENCES public.internships(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS is_read boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS created_at timestamptz NOT NULL DEFAULT now();

-- Ensure indexes exist
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON public.notifications (user_id, created_at DESC);

-- Ensure permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.notifications TO authenticated;
GRANT SELECT ON TABLE public.notifications TO anon;

-- Ensure notifications_type_check is permissive
DO $$
DECLARE
  c record;
BEGIN
  FOR c IN
    SELECT conname
      FROM pg_constraint
     WHERE conrelid = 'public.notifications'::regclass
       AND contype = 'c'
       AND pg_get_constraintdef(oid) ILIKE '%type%'
  LOOP
    EXECUTE FORMAT('ALTER TABLE public.notifications DROP CONSTRAINT %I', c.conname);
  END LOOP;

  ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (type IN ('general', 'application', 'document', 'progress', 'alert'));
EXCEPTION WHEN OTHERS THEN
  NULL;
END $$;

-- 2. Function to notify student when ITR status changes
CREATE OR REPLACE FUNCTION public.notify_on_itr_status_changed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid;
  v_title text;
  v_body text;
  v_internship_title text;
  v_remarks text;
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status
     AND LOWER(NEW.status::text) IN ('approved', 'rejected', 'changes_requested') THEN
    BEGIN
      -- Step A: Resolve the student's profile user_id
      -- 1) Directly via student_id on itrs matching profiles
      SELECT id INTO v_user_id
      FROM public.profiles
      WHERE id = NEW.student_id
      LIMIT 1;

      -- 2) Via students table (if student_id references students.id)
      IF v_user_id IS NULL THEN
        SELECT s.user_id INTO v_user_id
        FROM public.students s
        WHERE s.id = NEW.student_id
        LIMIT 1;
      END IF;

      -- 3) Via internships table (internship_id)
      IF v_user_id IS NULL AND NEW.internship_id IS NOT NULL THEN
        SELECT COALESCE(
          (SELECT s.user_id FROM public.students s JOIN public.internships i ON i.student_id = s.id WHERE i.id = NEW.internship_id LIMIT 1),
          (SELECT i.student_id FROM public.internships i WHERE i.id = NEW.internship_id LIMIT 1)
        ) INTO v_user_id;
      END IF;

      -- Step B: Fetch internship or project title
      SELECT COALESCE(
        NULLIF(TRIM(COALESCE(NEW.internship_title, '')), ''),
        NULLIF(TRIM(COALESCE(NEW.project_title, '')), ''),
        (SELECT title FROM public.internships WHERE id = NEW.internship_id LIMIT 1),
        'Industrial Training Report'
      ) INTO v_internship_title;

      v_remarks := NULLIF(TRIM(COALESCE(NEW.remarks, '')), '');

      -- Step C: Determine notification content
      IF LOWER(NEW.status::text) = 'approved' THEN
        v_title := 'ITR Approved';
        v_body := 'Your Industrial Training Report (ITR) for ' || v_internship_title || ' has been approved by your Faculty Mentor.';
      ELSIF LOWER(NEW.status::text) = 'rejected' THEN
        v_title := 'ITR Rejected';
        v_body := 'Your Industrial Training Report (ITR) for ' || v_internship_title || ' was rejected.';
        IF v_remarks IS NOT NULL THEN
          v_body := v_body || ' Remarks: ' || v_remarks;
        END IF;
      ELSE
        v_title := 'ITR Changes Requested';
        v_body := 'Changes have been requested for your Industrial Training Report (ITR) for ' || v_internship_title || '.';
        IF v_remarks IS NOT NULL THEN
          v_body := v_body || ' Feedback: ' || v_remarks;
        END IF;
      END IF;

      -- Step D: Insert notification for the student
      IF v_user_id IS NOT NULL THEN
        INSERT INTO public.notifications (
          user_id,
          title,
          body,
          type,
          internship_id,
          is_read
        ) VALUES (
          v_user_id,
          v_title,
          v_body,
          'document',
          NEW.internship_id,
          false
        );
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'Could not create notification on ITR status change: %', SQLERRM;
    END;
  END IF;
  RETURN NEW;
END;
$$;

-- Attach trigger to public.itrs if itrs table exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'itrs') THEN
    DROP TRIGGER IF EXISTS on_itr_status_changed ON public.itrs;
    CREATE TRIGGER on_itr_status_changed
      AFTER UPDATE OF status ON public.itrs
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_itr_status_changed();
  END IF;
END $$;

-- 3. Trigger on approval_reviews to automatically sync ITR status and notify
CREATE OR REPLACE FUNCTION public.notify_on_approval_review_submitted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_student_id uuid;
  v_title text;
  v_remarks text;
  v_is_approved boolean;
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status OR TG_OP = 'INSERT' THEN
    IF LOWER(NEW.status::text) IN ('approved', 'rejected') THEN
      BEGIN
        -- Sync associated ITR status if an ITR exists for this internship
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'itrs') THEN
          UPDATE public.itrs
          SET
            status = LOWER(NEW.status::text),
            remarks = COALESCE(NEW.remarks, public.itrs.remarks),
            reviewer_id = COALESCE(NEW.reviewer_id, public.itrs.reviewer_id),
            reviewed_at = now()
          WHERE internship_id = NEW.internship_id;
        END IF;

        -- Resolve student's user ID
        SELECT COALESCE(
          (SELECT s.user_id FROM public.students s JOIN public.internships i ON i.student_id = s.id WHERE i.id = NEW.internship_id LIMIT 1),
          (SELECT student_id FROM public.internships WHERE id = NEW.internship_id LIMIT 1)
        ) INTO v_student_id;

        SELECT COALESCE(
          (SELECT title FROM public.internships WHERE id = NEW.internship_id LIMIT 1),
          'Industrial Training Report'
        ) INTO v_title;

        v_remarks := NULLIF(TRIM(COALESCE(NEW.remarks, '')), '');
        v_is_approved := (LOWER(NEW.status::text) = 'approved');

        IF v_student_id IS NOT NULL THEN
          -- Also check if there is an ITR for this internship before creating the ITR notification
          IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'itrs'
                     AND EXISTS (SELECT 1 FROM public.itrs WHERE internship_id = NEW.internship_id)) THEN
            INSERT INTO public.notifications (
              user_id,
              title,
              body,
              type,
              internship_id,
              is_read
            ) VALUES (
              v_student_id,
              CASE WHEN v_is_approved THEN 'ITR Approved' ELSE 'ITR Rejected' END,
              CASE
                WHEN v_is_approved THEN 'Your Industrial Training Report (ITR) for ' || v_title || ' has been approved by your Faculty Mentor.'
                ELSE 'Your Industrial Training Report (ITR) for ' || v_title || ' was rejected.' || CASE WHEN v_remarks IS NOT NULL THEN ' Remarks: ' || v_remarks ELSE '' END
              END,
              'document',
              NEW.internship_id,
              false
            );
          END IF;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Could not sync ITR or send notification on approval review: %', SQLERRM;
      END;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Attach trigger to public.approval_reviews if table exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'approval_reviews') THEN
    DROP TRIGGER IF EXISTS on_approval_review_submitted ON public.approval_reviews;
    CREATE TRIGGER on_approval_review_submitted
      AFTER INSERT OR UPDATE OF status ON public.approval_reviews
      FOR EACH ROW EXECUTE FUNCTION public.notify_on_approval_review_submitted();
  END IF;
END $$;

-- 4. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
