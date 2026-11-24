-- ============================================================================
-- Migration: 20270222_tp_placement_communication.sql
-- Description: Complete T&P Cell Placement Notices, Fast Forwarding,
--              Branch Targeting, Student Queries, Smart FAQs, and NOC Management.
-- ============================================================================

-- 1. Branch Normalization & Discovery Helpers (No Hardcoded Branches)
CREATE OR REPLACE FUNCTION public.normalize_branch_code(p_raw text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_clean text;
BEGIN
  v_clean := lower(regexp_replace(trim(coalesce(p_raw, '')), '\s+', ' ', 'g'));
  IF v_clean = '' THEN
    RETURN '';
  END IF;

  IF v_clean IN ('cse', 'cs', 'computer science', 'computer science & engineering', 'computer science and engineering') THEN
    RETURN 'cse';
  ELSIF v_clean IN ('it', 'information technology') THEN
    RETURN 'it';
  ELSIF v_clean IN ('iot', 'internet of things', 'cse-iot', 'cse (iot)') THEN
    RETURN 'iot';
  ELSIF v_clean IN ('ce', 'civil', 'civil engineering') THEN
    RETURN 'civil';
  ELSIF v_clean IN ('me', 'mech', 'mechanical', 'mechanical engineering') THEN
    RETURN 'mechanical';
  ELSIF v_clean IN ('ee', 'electrical', 'electrical engineering') THEN
    RETURN 'electrical';
  ELSIF v_clean IN ('ece', 'ec', 'electronics', 'electronics & communication', 'electronics and communication engineering') THEN
    RETURN 'ece';
  ELSIF v_clean IN ('ai', 'aiml', 'ai & ml', 'artificial intelligence', 'aids', 'ai & ds') THEN
    RETURN 'ai';
  END IF;

  RETURN v_clean;
END;
$$;

CREATE OR REPLACE FUNCTION public.current_user_branch()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT NULLIF(TRIM(p.branch), '') FROM public.profiles p WHERE p.id = auth.uid()),
    (SELECT NULLIF(TRIM(p.department), '') FROM public.profiles p WHERE p.id = auth.uid()),
    (SELECT NULLIF(TRIM(s.department), '') FROM public.students s WHERE s.user_id = auth.uid() LIMIT 1)
  );
$$;

CREATE OR REPLACE FUNCTION public.branch_matches(
  p_target_branches text[],
  p_is_all_branches boolean,
  p_student_branch text
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_student_norm text;
  v_target text;
BEGIN
  IF COALESCE(p_is_all_branches, false) THEN
    RETURN true;
  END IF;

  IF p_target_branches IS NULL OR COALESCE(array_length(p_target_branches, 1), 0) = 0 THEN
    RETURN true;
  END IF;

  v_student_norm := public.normalize_branch_code(p_student_branch);
  IF v_student_norm = '' THEN
    RETURN false;
  END IF;

  FOREACH v_target IN ARRAY p_target_branches LOOP
    IF lower(trim(coalesce(v_target, ''))) IN ('all', 'all branches') THEN
      RETURN true;
    END IF;
    IF public.normalize_branch_code(v_target) = v_student_norm THEN
      RETURN true;
    END IF;
  END LOOP;

  RETURN false;
END;
$$;

-- 2. Placement & Internship Notices Table
CREATE TABLE IF NOT EXISTS public.placement_notices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  industry_id uuid REFERENCES public.industries(id) ON DELETE SET NULL,
  company_name text NOT NULL,
  opportunity_type text NOT NULL DEFAULT 'campus_recruitment'
    CHECK (opportunity_type IN ('internship', 'full_time', 'internship_ppo', 'campus_recruitment', 'other')),
  title text NOT NULL,
  description text,
  eligibility text,
  recruitment_process text,
  additional_notes text,
  application_link text,
  application_deadline timestamptz,
  recruitment_date timestamptz,
  is_all_branches boolean NOT NULL DEFAULT false,
  target_branches text[] NOT NULL DEFAULT '{}',
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'upcoming', 'closed')),
  notify_students boolean NOT NULL DEFAULT true,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_placement_notices_status_deadline
  ON public.placement_notices(status, application_deadline);
CREATE INDEX IF NOT EXISTS idx_placement_notices_created_at
  ON public.placement_notices(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_placement_notices_company
  ON public.placement_notices(company_name);
CREATE INDEX IF NOT EXISTS idx_placement_notices_branches_gin
  ON public.placement_notices USING GIN (target_branches);

-- 3. Placement Notice Attachments Table
CREATE TABLE IF NOT EXISTS public.placement_notice_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notice_id uuid NOT NULL REFERENCES public.placement_notices(id) ON DELETE CASCADE,
  file_name text NOT NULL,
  file_path text NOT NULL,
  file_type text NOT NULL DEFAULT 'pdf'
    CHECK (file_type IN ('pdf', 'image', 'doc', 'other')),
  mime_type text,
  file_size bigint,
  uploaded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notice_attachments_notice_id
  ON public.placement_notice_attachments(notice_id);

-- 4. Placement Notice Read Receipts (Unread / New Indicator)
CREATE TABLE IF NOT EXISTS public.placement_notice_reads (
  notice_id uuid NOT NULL REFERENCES public.placement_notices(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (notice_id, user_id)
);

-- 5. T&P FAQs Table
CREATE TABLE IF NOT EXISTS public.tp_faqs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL DEFAULT 'General',
  question text NOT NULL,
  answer text NOT NULL,
  keywords text[] NOT NULL DEFAULT '{}',
  target_branches text[] NOT NULL DEFAULT '{}',
  is_all_branches boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  usage_count integer NOT NULL DEFAULT 0,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tp_faqs_active_cat
  ON public.tp_faqs(is_active, category);

-- 6. Student Queries & Replies Tables
CREATE TABLE IF NOT EXISTS public.student_queries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  notice_id uuid REFERENCES public.placement_notices(id) ON DELETE SET NULL,
  company_name text,
  student_branch text,
  category text NOT NULL DEFAULT 'General',
  question text NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'answered', 'closed')),
  has_unread_reply boolean NOT NULL DEFAULT false,
  is_read_by_tp boolean NOT NULL DEFAULT false,
  last_reply_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_student_queries_student_id
  ON public.student_queries(student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_student_queries_status
  ON public.student_queries(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_student_queries_notice_id
  ON public.student_queries(notice_id);

CREATE TABLE IF NOT EXISTS public.student_query_replies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  query_id uuid NOT NULL REFERENCES public.student_queries(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  sender_role text NOT NULL DEFAULT 'tp_officer',
  message text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_student_query_replies_query_id
  ON public.student_query_replies(query_id, created_at ASC);

-- 7. Formal NOC Requests Table (Integrated alongside existing internship_documents NOCs)
CREATE TABLE IF NOT EXISTS public.noc_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  internship_id uuid REFERENCES public.internships(id) ON DELETE SET NULL,
  notice_id uuid REFERENCES public.placement_notices(id) ON DELETE SET NULL,
  company_name text NOT NULL,
  opportunity_title text,
  student_branch text,
  roll_number text,
  student_remarks text,
  document_name text,
  document_path text,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  tp_remarks text,
  rejection_reason text,
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_noc_requests_student_id
  ON public.noc_requests(student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_noc_requests_status
  ON public.noc_requests(status, created_at DESC);

-- 8. Notifications Table Enhancements
DO $$
DECLARE
  c record;
BEGIN
  IF to_regclass('public.notifications') IS NOT NULL THEN
    -- Widen type check constraint if present
    FOR c IN
      SELECT conname
      FROM pg_constraint
      WHERE conrelid = 'public.notifications'::regclass
        AND contype = 'c'
        AND pg_get_constraintdef(oid) ILIKE '%type%'
    LOOP
      EXECUTE format('ALTER TABLE public.notifications DROP CONSTRAINT %I', c.conname);
    END LOOP;

    -- Only add text check constraint if column type is text/varchar (not enum)
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'notifications'
        AND column_name = 'type'
        AND data_type IN ('text', 'character varying')
    ) THEN
      ALTER TABLE public.notifications
        ADD CONSTRAINT notifications_type_check
        CHECK (type IN ('general', 'application', 'document', 'progress', 'alert', 'placement', 'query', 'noc'));
    END IF;

    ALTER TABLE public.notifications
      ADD COLUMN IF NOT EXISTS notice_id uuid REFERENCES public.placement_notices(id) ON DELETE CASCADE,
      ADD COLUMN IF NOT EXISTS query_id uuid REFERENCES public.student_queries(id) ON DELETE CASCADE,
      ADD COLUMN IF NOT EXISTS noc_request_id uuid REFERENCES public.noc_requests(id) ON DELETE CASCADE,
      ADD COLUMN IF NOT EXISTS reference_type text,
      ADD COLUMN IF NOT EXISTS reference_id uuid;

    CREATE INDEX IF NOT EXISTS idx_notifications_notice_id ON public.notifications(notice_id);
  END IF;
END $$;

-- Helper to insert notification safely regardless of schema variant
CREATE OR REPLACE FUNCTION public.create_user_notification(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_type text,
  p_internship_id uuid DEFAULT NULL,
  p_notice_id uuid DEFAULT NULL,
  p_query_id uuid DEFAULT NULL,
  p_noc_request_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_ref_type text;
  v_ref_id uuid;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  IF p_notice_id IS NOT NULL THEN
    v_ref_type := 'placement_notice';
    v_ref_id := p_notice_id;
  ELSIF p_query_id IS NOT NULL THEN
    v_ref_type := 'student_query';
    v_ref_id := p_query_id;
  ELSIF p_noc_request_id IS NOT NULL THEN
    v_ref_type := 'noc_request';
    v_ref_id := p_noc_request_id;
  ELSIF p_internship_id IS NOT NULL THEN
    v_ref_type := 'internship';
    v_ref_id := p_internship_id;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'user_id'
  ) THEN
    INSERT INTO public.notifications (
      user_id, title, body, type, internship_id, notice_id, query_id, noc_request_id, reference_type, reference_id, is_read
    )
    VALUES (
      p_user_id, p_title, COALESCE(p_body, ''), p_type, p_internship_id, p_notice_id, p_query_id, p_noc_request_id, v_ref_type, v_ref_id, false
    );
  ELSIF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'notifications' AND column_name = 'recipient_id'
  ) THEN
    INSERT INTO public.notifications (
      recipient_id, title, message, type, reference_type, reference_id, notice_id, query_id, noc_request_id, is_read
    )
    VALUES (
      p_user_id, p_title, COALESCE(p_body, ''), 'system', v_ref_type, v_ref_id, p_notice_id, p_query_id, p_noc_request_id, false
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'create_user_notification failed: %', SQLERRM;
END;
$$;

-- 9. Triggers for Automated Notifications

-- A. Placement Notice Published -> Notify Eligible Branch Students
CREATE OR REPLACE FUNCTION public.notify_on_placement_notice_published()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_type_label text;
  v_branches_label text;
  v_deadline_text text;
  v_title text;
  v_body text;
  v_student record;
BEGIN
  IF NOT COALESCE(NEW.notify_students, true) THEN
    RETURN NEW;
  END IF;

  IF NEW.status NOT IN ('open', 'upcoming') THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.status IN ('open', 'upcoming') AND COALESCE(OLD.notify_students, false) = true THEN
      RETURN NEW;
    END IF;
  END IF;

  v_type_label := CASE NEW.opportunity_type
    WHEN 'internship' THEN 'internship'
    WHEN 'full_time' THEN 'full-time job'
    WHEN 'internship_ppo' THEN 'internship + PPO'
    WHEN 'campus_recruitment' THEN 'campus recruitment'
    ELSE 'placement'
  END;

  IF NEW.is_all_branches OR COALESCE(array_length(NEW.target_branches, 1), 0) = 0 THEN
    v_branches_label := 'all branches';
  ELSE
    v_branches_label := array_to_string(NEW.target_branches, '/') || ' students';
  END IF;

  IF NEW.application_deadline IS NOT NULL THEN
    v_deadline_text := ' Application deadline: ' || to_char(NEW.application_deadline AT TIME ZONE 'Asia/Kolkata', 'DD Mon YYYY') || '.';
  ELSE
    v_deadline_text := '';
  END IF;

  v_title := NEW.company_name || ' · ' || NEW.title;
  v_body := NEW.company_name || ' has published a new ' || v_type_label || ' opportunity for ' || v_branches_label || '.' || v_deadline_text;

  FOR v_student IN
    SELECT DISTINCT p.id AS user_id,
      COALESCE(NULLIF(TRIM(p.branch), ''), NULLIF(TRIM(p.department), ''), s.department) AS branch_name
    FROM public.profiles p
    LEFT JOIN public.students s ON s.user_id = p.id
    WHERE LOWER(TRIM(p.role::text)) = 'student'
      AND COALESCE(p.is_active, true) = true
  LOOP
    IF public.branch_matches(NEW.target_branches, NEW.is_all_branches, v_student.branch_name) THEN
      PERFORM public.create_user_notification(
        v_student.user_id,
        v_title,
        v_body,
        'placement',
        NULL,
        NEW.id,
        NULL,
        NULL
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_placement_notice_published ON public.placement_notices;
CREATE TRIGGER on_placement_notice_published
  AFTER INSERT OR UPDATE OF status, notify_students ON public.placement_notices
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_placement_notice_published();

-- B. Student Query Created / Replied -> Sync Status & Notify
CREATE OR REPLACE FUNCTION public.notify_on_student_query_reply()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_query public.student_queries%ROWTYPE;
  v_is_staff boolean;
BEGIN
  SELECT * INTO v_query FROM public.student_queries WHERE id = NEW.query_id;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  v_is_staff := LOWER(TRIM(NEW.sender_role)) IN ('tnp', 'tp_officer', 'admin', 'faculty', 'faculty_mentor');

  IF v_is_staff THEN
    UPDATE public.student_queries
    SET
      status = CASE WHEN status = 'closed' THEN 'closed' ELSE 'answered' END,
      has_unread_reply = true,
      is_read_by_tp = true,
      last_reply_at = now(),
      updated_at = now()
    WHERE id = NEW.query_id;

    PERFORM public.create_user_notification(
      v_query.student_id,
      'T&P Cell replied to your query',
      COALESCE(NULLIF(TRIM(v_query.company_name), ''), v_query.category) || ': ' || LEFT(NEW.message, 120),
      'query',
      NULL,
      v_query.notice_id,
      v_query.id,
      NULL
    );
  ELSE
    UPDATE public.student_queries
    SET
      status = CASE WHEN status = 'closed' THEN 'open' ELSE status END,
      is_read_by_tp = false,
      last_reply_at = now(),
      updated_at = now()
    WHERE id = NEW.query_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_student_query_reply ON public.student_query_replies;
CREATE TRIGGER on_student_query_reply
  AFTER INSERT ON public.student_query_replies
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_student_query_reply();

-- C. NOC Request Status Changed -> Notify Student
CREATE OR REPLACE FUNCTION public.notify_on_noc_status_changed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_title text;
  v_body text;
  v_note text;
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status IN ('approved', 'rejected') THEN
    v_note := COALESCE(NULLIF(TRIM(NEW.rejection_reason), ''), NULLIF(TRIM(NEW.tp_remarks), ''));
    IF NEW.status = 'approved' THEN
      v_title := 'NOC Approved · ' || NEW.company_name;
      v_body := 'Your NOC request for ' || NEW.company_name || ' has been approved by the T&P Cell.' ||
                CASE WHEN v_note IS NOT NULL THEN ' Remarks: ' || v_note ELSE '' END;
    ELSE
      v_title := 'NOC Rejected · ' || NEW.company_name;
      v_body := 'Your NOC request for ' || NEW.company_name || ' was rejected by the T&P Cell.' ||
                CASE WHEN v_note IS NOT NULL THEN ' Reason: ' || v_note ELSE '' END;
    END IF;

    PERFORM public.create_user_notification(
      NEW.student_id,
      v_title,
      v_body,
      'noc',
      NEW.internship_id,
      NEW.notice_id,
      NULL,
      NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_noc_request_status_changed ON public.noc_requests;
CREATE TRIGGER on_noc_request_status_changed
  AFTER UPDATE OF status ON public.noc_requests
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_noc_status_changed();

-- D. Existing internship_documents NOC verification -> Notify Student
CREATE OR REPLACE FUNCTION public.notify_on_internship_doc_noc_changed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid;
  v_company text;
  v_note text;
BEGIN
  IF LOWER(COALESCE(NEW.doc_type, '')) = 'noc'
     AND NEW.faculty_status IS DISTINCT FROM OLD.faculty_status
     AND LOWER(COALESCE(NEW.faculty_status, '')) IN ('approved', 'verified', 'rejected') THEN
    SELECT COALESCE(
      (SELECT s.user_id FROM public.students s WHERE s.id = NEW.student_id LIMIT 1),
      NEW.student_id
    ) INTO v_user_id;

    SELECT company_name INTO v_company FROM public.internships WHERE id = NEW.internship_id LIMIT 1;
    v_note := COALESCE(NULLIF(TRIM(NEW.faculty_rejection_reason), ''), NULLIF(TRIM(NEW.faculty_remarks), ''));

    PERFORM public.create_user_notification(
      v_user_id,
      CASE WHEN LOWER(NEW.faculty_status) = 'rejected' THEN 'NOC Document Rejected' ELSE 'NOC Document Approved' END,
      'Your NOC document (' || NEW.file_name || ')' ||
        CASE WHEN v_company IS NOT NULL THEN ' for ' || v_company ELSE '' END ||
        CASE WHEN LOWER(NEW.faculty_status) = 'rejected' THEN ' was rejected.' ELSE ' has been approved.' END ||
        CASE WHEN v_note IS NOT NULL THEN ' Remarks: ' || v_note ELSE '' END,
      'noc',
      NEW.internship_id,
      NULL,
      NULL,
      NULL
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_internship_doc_noc_changed ON public.internship_documents;
CREATE TRIGGER on_internship_doc_noc_changed
  AFTER UPDATE OF faculty_status ON public.internship_documents
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_internship_doc_noc_changed();

-- 10. RPCs for Branch Discovery, FAQ Usage, and T&P Dashboard Summary
CREATE OR REPLACE FUNCTION public.get_available_branches()
RETURNS text[]
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(array_agg(branch_name ORDER BY branch_name), '{}')
  FROM (
    SELECT DISTINCT TRIM(branch) AS branch_name
    FROM public.profiles
    WHERE branch IS NOT NULL AND TRIM(branch) <> ''
    UNION
    SELECT DISTINCT TRIM(department) AS branch_name
    FROM public.profiles
    WHERE department IS NOT NULL AND TRIM(department) <> ''
    UNION
    SELECT DISTINCT TRIM(department) AS branch_name
    FROM public.students
    WHERE department IS NOT NULL AND TRIM(department) <> ''
    UNION
    SELECT DISTINCT TRIM(department) AS branch_name
    FROM public.faculty_details
    WHERE department IS NOT NULL AND TRIM(department) <> ''
    UNION
    SELECT DISTINCT TRIM(b) AS branch_name
    FROM public.placement_notices pn, unnest(pn.target_branches) AS b
    WHERE b IS NOT NULL AND TRIM(b) <> '' AND LOWER(TRIM(b)) NOT IN ('all', 'all branches')
  ) AS branches;
$$;

GRANT EXECUTE ON FUNCTION public.get_available_branches() TO authenticated;

CREATE OR REPLACE FUNCTION public.increment_faq_usage(p_faq_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.tp_faqs
  SET usage_count = usage_count + 1
  WHERE id = p_faq_id AND is_active = true;
END;
$$;

GRANT EXECUTE ON FUNCTION public.increment_faq_usage(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_tp_dashboard_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_role text := LOWER(TRIM(COALESCE(public.current_role_of_user(), '')));
  v_active_opps integer := 0;
  v_new_notices integer := 0;
  v_upcoming_drives integer := 0;
  v_closing_soon integer := 0;
  v_pending_nocs integer := 0;
  v_pending_doc_nocs integer := 0;
  v_unanswered_queries integer := 0;
  v_active_faqs integer := 0;
BEGIN
  IF v_role NOT IN ('tnp', 'tp_officer', 'admin', 'faculty', 'faculty_mentor') THEN
    RAISE EXCEPTION 'Unauthorized' USING ERRCODE = '42501';
  END IF;

  SELECT
    COUNT(*) FILTER (WHERE status IN ('open', 'upcoming'))::int,
    COUNT(*) FILTER (WHERE status IN ('open', 'upcoming') AND created_at >= now() - interval '48 hours')::int,
    COUNT(*) FILTER (WHERE status = 'upcoming' OR (status = 'open' AND recruitment_date IS NOT NULL AND recruitment_date >= now()))::int,
    COUNT(*) FILTER (WHERE status = 'open' AND application_deadline IS NOT NULL AND application_deadline >= now() AND application_deadline <= now() + interval '72 hours')::int
  INTO v_active_opps, v_new_notices, v_upcoming_drives, v_closing_soon
  FROM public.placement_notices;

  SELECT COUNT(*)::int INTO v_pending_nocs
  FROM public.noc_requests
  WHERE status = 'pending';

  SELECT COUNT(*)::int INTO v_pending_doc_nocs
  FROM public.internship_documents
  WHERE LOWER(COALESCE(doc_type, '')) = 'noc'
    AND LOWER(COALESCE(faculty_status, 'pending')) = 'pending';

  SELECT COUNT(*)::int INTO v_unanswered_queries
  FROM public.student_queries
  WHERE status = 'open' OR (status <> 'closed' AND is_read_by_tp = false);

  SELECT COUNT(*)::int INTO v_active_faqs
  FROM public.tp_faqs
  WHERE is_active = true;

  RETURN jsonb_build_object(
    'active_opportunities', COALESCE(v_active_opps, 0),
    'new_notices', COALESCE(v_new_notices, 0),
    'upcoming_drives', COALESCE(v_upcoming_drives, 0),
    'closing_soon', COALESCE(v_closing_soon, 0),
    'pending_noc_requests', COALESCE(v_pending_nocs, 0) + COALESCE(v_pending_doc_nocs, 0),
    'unanswered_queries', COALESCE(v_unanswered_queries, 0),
    'active_faqs', COALESCE(v_active_faqs, 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_tp_dashboard_summary() TO authenticated;

-- 11. Row Level Security (RLS)
ALTER TABLE public.placement_notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.placement_notice_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.placement_notice_reads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tp_faqs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_queries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_query_replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.noc_requests ENABLE ROW LEVEL SECURITY;

-- placement_notices policies
DROP POLICY IF EXISTS "placement_notices_read" ON public.placement_notices;
CREATE POLICY "placement_notices_read" ON public.placement_notices
  FOR SELECT TO authenticated
  USING (
    public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin', 'faculty', 'faculty_mentor')
    OR public.branch_matches(target_branches, is_all_branches, public.current_user_branch())
  );

DROP POLICY IF EXISTS "placement_notices_tp_insert" ON public.placement_notices;
CREATE POLICY "placement_notices_tp_insert" ON public.placement_notices
  FOR INSERT TO authenticated
  WITH CHECK (public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin'));

DROP POLICY IF EXISTS "placement_notices_tp_update" ON public.placement_notices;
CREATE POLICY "placement_notices_tp_update" ON public.placement_notices
  FOR UPDATE TO authenticated
  USING (public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin'))
  WITH CHECK (public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin'));

DROP POLICY IF EXISTS "placement_notices_tp_delete" ON public.placement_notices;
CREATE POLICY "placement_notices_tp_delete" ON public.placement_notices
  FOR DELETE TO authenticated
  USING (public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin'));

-- placement_notice_attachments policies
DROP POLICY IF EXISTS "notice_attachments_read" ON public.placement_notice_attachments;
CREATE POLICY "notice_attachments_read" ON public.placement_notice_attachments
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.placement_notices pn
      WHERE pn.id = notice_id
        AND (
          public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin', 'faculty', 'faculty_mentor')
          OR public.branch_matches(pn.target_branches, pn.is_all_branches, public.current_user_branch())
        )
    )
  );

DROP POLICY IF EXISTS "notice_attachments_tp_insert" ON public.placement_notice_attachments;
CREATE POLICY "notice_attachments_tp_insert" ON public.placement_notice_attachments
  FOR INSERT TO authenticated
  WITH CHECK (public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin'));

DROP POLICY IF EXISTS "notice_attachments_tp_delete" ON public.placement_notice_attachments;
CREATE POLICY "notice_attachments_tp_delete" ON public.placement_notice_attachments
  FOR DELETE TO authenticated
  USING (public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin'));

-- placement_notice_reads policies
DROP POLICY IF EXISTS "notice_reads_own" ON public.placement_notice_reads;
CREATE POLICY "notice_reads_own" ON public.placement_notice_reads
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- tp_faqs policies
DROP POLICY IF EXISTS "tp_faqs_read" ON public.tp_faqs;
CREATE POLICY "tp_faqs_read" ON public.tp_faqs
  FOR SELECT TO authenticated
  USING (
    public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin')
    OR (
      is_active = true
      AND (
        is_all_branches = true
        OR COALESCE(array_length(target_branches, 1), 0) = 0
        OR public.branch_matches(target_branches, is_all_branches, public.current_user_branch())
      )
    )
  );

DROP POLICY IF EXISTS "tp_faqs_tp_write" ON public.tp_faqs;
CREATE POLICY "tp_faqs_tp_write" ON public.tp_faqs
  FOR ALL TO authenticated
  USING (public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin'))
  WITH CHECK (public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin'));

-- student_queries policies
DROP POLICY IF EXISTS "student_queries_read" ON public.student_queries;
CREATE POLICY "student_queries_read" ON public.student_queries
  FOR SELECT TO authenticated
  USING (
    student_id = auth.uid()
    OR public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin')
  );

DROP POLICY IF EXISTS "student_queries_insert_own" ON public.student_queries;
CREATE POLICY "student_queries_insert_own" ON public.student_queries
  FOR INSERT TO authenticated
  WITH CHECK (student_id = auth.uid());

DROP POLICY IF EXISTS "student_queries_update" ON public.student_queries;
CREATE POLICY "student_queries_update" ON public.student_queries
  FOR UPDATE TO authenticated
  USING (
    student_id = auth.uid()
    OR public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin')
  )
  WITH CHECK (
    student_id = auth.uid()
    OR public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin')
  );

-- student_query_replies policies
DROP POLICY IF EXISTS "student_query_replies_read" ON public.student_query_replies;
CREATE POLICY "student_query_replies_read" ON public.student_query_replies
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.student_queries q
      WHERE q.id = query_id
        AND (q.student_id = auth.uid() OR public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin'))
    )
  );

DROP POLICY IF EXISTS "student_query_replies_insert" ON public.student_query_replies;
CREATE POLICY "student_query_replies_insert" ON public.student_query_replies
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND (
      public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin')
      OR EXISTS (
        SELECT 1 FROM public.student_queries q
        WHERE q.id = query_id AND q.student_id = auth.uid()
      )
    )
  );

-- noc_requests policies
DROP POLICY IF EXISTS "noc_requests_read" ON public.noc_requests;
CREATE POLICY "noc_requests_read" ON public.noc_requests
  FOR SELECT TO authenticated
  USING (
    student_id = auth.uid()
    OR public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin', 'faculty', 'faculty_mentor')
  );

DROP POLICY IF EXISTS "noc_requests_insert_own" ON public.noc_requests;
CREATE POLICY "noc_requests_insert_own" ON public.noc_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    student_id = auth.uid()
    AND status = 'pending'
  );

DROP POLICY IF EXISTS "noc_requests_tp_update" ON public.noc_requests;
CREATE POLICY "noc_requests_tp_update" ON public.noc_requests
  FOR UPDATE TO authenticated
  USING (public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin'))
  WITH CHECK (public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin'));

DROP POLICY IF EXISTS "noc_requests_delete_own_pending" ON public.noc_requests;
CREATE POLICY "noc_requests_delete_own_pending" ON public.noc_requests
  FOR DELETE TO authenticated
  USING (
    (student_id = auth.uid() AND status = 'pending')
    OR public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin')
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.placement_notices TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.placement_notice_attachments TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.placement_notice_reads TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.tp_faqs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.student_queries TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.student_query_replies TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.noc_requests TO authenticated;

-- 12. Storage Bucket & Storage RLS for Placement Notice PDFs/Images and NOC Docs
INSERT INTO storage.buckets (id, name, public)
VALUES ('placement-notices', 'placement-notices', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "placement_notices_storage_tp_insert" ON storage.objects;
CREATE POLICY "placement_notices_storage_tp_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'placement-notices'
    AND (
      (
        (storage.foldername(name))[1] = 'notices'
        AND public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin')
      )
      OR (
        (storage.foldername(name))[1] = 'noc'
        AND (storage.foldername(name))[2] = auth.uid()::text
      )
    )
  );

DROP POLICY IF EXISTS "placement_notices_storage_read" ON storage.objects;
CREATE POLICY "placement_notices_storage_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'placement-notices'
    AND (
      public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin', 'faculty', 'faculty_mentor')
      OR (
        (storage.foldername(name))[1] = 'notices'
        AND EXISTS (
          SELECT 1
          FROM public.placement_notice_attachments a
          JOIN public.placement_notices pn ON pn.id = a.notice_id
          WHERE a.file_path = name
            AND public.branch_matches(pn.target_branches, pn.is_all_branches, public.current_user_branch())
        )
      )
      OR (
        (storage.foldername(name))[1] = 'noc'
        AND (storage.foldername(name))[2] = auth.uid()::text
      )
    )
  );

DROP POLICY IF EXISTS "placement_notices_storage_delete" ON storage.objects;
CREATE POLICY "placement_notices_storage_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'placement-notices'
    AND (
      (
        (storage.foldername(name))[1] = 'notices'
        AND public.current_role_of_user() IN ('tnp', 'tp_officer', 'admin')
      )
      OR (
        (storage.foldername(name))[1] = 'noc'
        AND (storage.foldername(name))[2] = auth.uid()::text
      )
    )
  );

-- 13. Realtime publication (optional best-effort)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'placement_notices') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.placement_notices;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'student_queries') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.student_queries;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'noc_requests') THEN
      ALTER PUBLICATION supabase_realtime ADD TABLE public.noc_requests;
    END IF;
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Could not add tables to supabase_realtime: %', SQLERRM;
END $$;

NOTIFY pgrst, 'reload schema';
