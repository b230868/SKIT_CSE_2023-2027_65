# S5 - Verification of integrated report and notification workflows

Tester: ______________   Date: ______________   Build / branch: ______________

Use two accounts: a student, and a faculty or T&P user (or change statuses
directly in Supabase > Table Editor). Run the app with
`flutter run -d chrome --web-port=8080`.

| # | Workflow | Steps | Expected result | Pass / Fail |
|---|---|---|---|---|
| 1 | Application notification | Student applies to an internship | "Application received" appears in the bell without a refresh; unread badge goes up | |
| 2 | Document notification | Student uploads a document (under 5 MB) | "Document uploaded" notification appears; document listed on the application | |
| 3 | Approval notification | Set the application status to approved | "Application approved" appears live; progress tab becomes available | |
| 4 | Progress notification | Student saves a weekly progress update | "Progress saved" notification appears; progress cannot go below the previous value | |
| 5 | Tap-through | Tap an application notification | Opens that application's Documents / Progress screen | |
| 6 | Report numbers | Open My report | Application counts, documents and latest progress match the Supabase tables | |
| 7 | Report updates | Log new progress, pull down to refresh | Chart, insights and "Updated hh:mm" change | |
| 8 | Time window | Choose 4 weeks, 8 weeks, All | Weeks logged and average gain change; chart redraws | |
| 9 | Unread statistics | Mark all notifications read, refresh the report | Unread shows 0 of N | |
| 10 | PDF export | Tap Export as PDF | PDF opens with student name, tables and "Page x of y" | |
| 11 | Empty state | Sign in with a new student account | "Nothing to report yet" message | |
| 12 | Error handling | Turn the network off, open My report | "Could not load your report" with a Retry button; Retry works when online | |
| 13 | Isolation | Sign in as a second student | Sees only their own report and notifications | |
| 14 | Delete | Swipe a notification left | It disappears and stays gone after restart | |

## Automated checks
    flutter analyze
    flutter test
    -- and run supabase/verification/s5_verify_report_workflows.sql in the SQL Editor (all rows PASS)

Defects found: ____________________________________________________
