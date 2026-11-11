# Student reports module

Shows a student's application summary, progress analytics, documents and
notification statistics, and exports them as a PDF.

## Files
| File | Role |
|---|---|
| models/notification_models.dart | AppNotification, ProgressPoint, ReportSummary (all analytics are getters here) |
| services/report_service.dart | Loads report data: one RPC call, falls back to table reads; 60 s in-memory cache |
| screens/student/reports_screen.dart | Screen, charts, PDF export, copy summary |
| test/features/student/report_summary_test.dart | Unit tests for the analytics |

## Data flow
Reports screen -> ReportService.studentSummary()
  1. rpc student_report_data (supabase/migrations/s5_report_refinements.sql)
  2. if that fails: reads applications, documents, progress_logs, profiles, notifications
-> ReportSummary -> widgets / PDF

## Database dependencies
applications, documents, progress_logs, notifications, profiles, and the
function student_report_data(). Indexes: s5_report_indexes.sql.

## Checks
flutter analyze
flutter test test/features/student/report_summary_test.dart
