-- S5 (final pass): run once in Supabase > SQL Editor.
-- Indexes that speed up the report and notification queries as the number
-- of students and records grows (NFR-03 performance, NFR-06 scalability).
-- Safe to run more than once. If a statement fails because a column does not
-- exist in your project's table, skip only that line.

create index if not exists idx_applications_student
  on public.applications (student_id);

create index if not exists idx_documents_student
  on public.documents (student_id);

create index if not exists idx_progress_logs_student_week
  on public.progress_logs (student_id, week_no);

create index if not exists idx_notifications_user_created
  on public.notifications (user_id, created_at desc);

create index if not exists idx_notifications_user_unread
  on public.notifications (user_id, is_read);
