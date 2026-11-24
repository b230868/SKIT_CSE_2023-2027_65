# S5 data flow verification (16-22 Nov)

Goal: confirm that data flows correctly from the app to the database triggers,
through the analytics and notification APIs, back to the app, including offline.

## 1. Database checks
1. Open Supabase > SQL Editor and run `supabase/verification/s5_data_flow_verification.sql`.
2. Every row of the result must say `PASS` (a `WARN` needs a look, `FAIL` must be fixed).
3. Run the second query in the script with a real student id and internship id.
   It simulates a progress update and rolls everything back afterwards.

## 2. App checks (use a test student account)

| # | Action | Expected result | Pass? |
|---|--------|-----------------|-------|
| 1 | Submit an internship application | "Application received" notification appears live | |
| 2 | Approve / reject it from the faculty side | Student gets "Application approved/update" once (not twice) | |
| 3 | Upload a document | "Document uploaded" notification | |
| 4 | Log a progress update that crosses 25/50/75/100% | "Progress saved" + "Milestone reached" alert | |
| 5 | Open the Alerts screen | Milestone alert is listed, unread dot visible | |
| 6 | Tap the alert / "mark all" | Dot disappears, unread count drops | |
| 7 | Open Progress Analytics | Latest progress, weekly trend and counts match step 4 | |
| 8 | Turn on airplane mode, reopen Alerts and Analytics | Saved data still shown, "Offline" banner on analytics | |
| 9 | Mark an alert as read while offline, then reconnect | Change reaches Supabase (check `is_read` in the table) | |
| 10 | Run `select public.generate_progress_alerts(0);` in SQL Editor | Alert "No recent progress update" created for stalled internships | |

## 3. Automated check
`flutter test test/features/student/s5_data_contract_test.dart` must pass.

## 4. Evidence for the mentor
Screenshot of the all-PASS result table, the filled table above, and the test output.
