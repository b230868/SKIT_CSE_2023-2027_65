-- ============================================================================
-- Migration: 20270216_database_optimization.sql
-- User Story: Database Bug Fix & Query Optimization
-- ============================================================================

-- 1. Indexing on approval_reviews table for fast dashboard aggregation
CREATE INDEX IF NOT EXISTS idx_approval_reviews_composite_lookup 
ON public.approval_reviews (internship_id, review_stage, status);

CREATE INDEX IF NOT EXISTS idx_approval_reviews_stage_pending 
ON public.approval_reviews (review_stage) 
WHERE status = 'pending';

-- 2. Indexing on internships table for department & status queries
CREATE INDEX IF NOT EXISTS idx_internships_status_student 
ON public.internships (status, student_id);

CREATE INDEX IF NOT EXISTS idx_internships_company_status 
ON public.internships (company_name, status);

-- 3. Indexing on students table for fast batch and department filtering
CREATE INDEX IF NOT EXISTS idx_students_dept_batch 
ON public.students (department, batch_year);

-- 4. Indexing on faculty assignments
CREATE INDEX IF NOT EXISTS idx_faculty_assignments_lookup 
ON public.faculty_mentor_assignments (faculty_id, student_id);

-- 5. Indexing on certificates
CREATE INDEX IF NOT EXISTS idx_certificates_internship_status 
ON public.certificates (internship_id, status);

-- 6. Query Optimization Function: Fast Faculty Dashboard Statistics
CREATE OR REPLACE FUNCTION public.get_faculty_dashboard_stats(p_department TEXT DEFAULT NULL)
RETURNS TABLE (
  total_internships BIGINT,
  pending_approvals BIGINT,
  approved_internships BIGINT,
  active_internships BIGINT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(i.id)::BIGINT AS total_internships,
    COUNT(CASE WHEN ar.status = 'pending' OR ar.id IS NULL THEN 1 END)::BIGINT AS pending_approvals,
    COUNT(CASE WHEN ar.status = 'approved' THEN 1 END)::BIGINT AS approved_internships,
    COUNT(CASE WHEN i.status = 'active' THEN 1 END)::BIGINT AS active_internships
  FROM public.internships i
  LEFT JOIN public.students s ON s.id = i.student_id
  LEFT JOIN LATERAL (
    SELECT ar_inner.id, ar_inner.status
    FROM public.approval_reviews ar_inner
    WHERE ar_inner.internship_id = i.id
    ORDER BY ar_inner.created_at DESC
    LIMIT 1
  ) ar ON true
  WHERE (p_department IS NULL OR s.department ILIKE '%' || p_department || '%');
END;
$$;

