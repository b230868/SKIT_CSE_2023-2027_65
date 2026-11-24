# S5 synchronization checks (23-29 Nov)

Use a test student account with at least 3 notifications.

| # | Scenario | Expected result | Pass? |
|---|----------|-----------------|-------|
| 1 | Open Alerts, then switch on airplane mode and reopen | Saved list still shown, red "Offline" banner | |
| 2 | Offline: tap an alert to mark it read | Dot disappears at once, banner says "1 change(s) will sync" | |
| 3 | Offline: swipe-delete a notification | It disappears, banner count goes to 2 | |
| 4 | Switch airplane mode off, tap Retry (or wait ~2 minutes) | Banner disappears; Supabase shows `is_read = true` and the row deleted | |
| 5 | Mark the same alert read twice offline | Only 1 change is queued (no duplicates) | |
| 6 | On a second device / SQL Editor mark a notification read | After resume or sync it is read on the first device too | |
| 7 | Offline for a long time with a failing action | After 5 failed tries the action is dropped (no endless retries) | |
| 8 | Pull to refresh while online | Full refresh; rows deleted on the server vanish | |
| 9 | Sign out and sign in as another student | No notifications from the first student are visible | |

Automated: `flutter test test/features/student/s5_sync_logic_test.dart`

SQL check after the migration:
`select id, is_read, updated_at from public.get_notifications_since(now() - interval '1 day');`
