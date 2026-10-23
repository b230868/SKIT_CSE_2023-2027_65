# Prashikshan

Prashikshan is a Flutter application for managing internships, approvals,
documents, and progress tracking.

## Run locally

1. Install Flutter.
2. Copy `.env.example` to `.env` and set `SUPABASE_URL` and either
   `SUPABASE_PUBLISHABLE_KEY` or `SUPABASE_ANON_KEY` to the public client
   values for your Supabase project. Never put a `service_role` key in the app.
3. Fetch dependencies with `flutter pub get`.
4. Apply `supabase/schema.sql` and the applicable migrations in
   `supabase/migrations/` to your Supabase project.
5. For local web signup confirmation, add `http://localhost:8080/**` to the
   Supabase Authentication redirect URLs and ensure the confirmation email
   template links to `{{ .ConfirmationURL }}`.
6. Start the web app with:

   ```sh
   flutter run -d chrome --web-port=8080
   ```

For other targets, run `flutter run` and choose an available device. Keep `.env`
local; it is excluded from Git.

## Geo-tagged progress and offline queue

Apply
[`supabase/migrations/20261011000000_geo_progress_offline_cache.sql`](./supabase/migrations/20261011000000_geo_progress_offline_cache.sql)
after the base schema. Approved internships can submit progress from their
detail screen with a GPS fix. Submissions are stored in Hive before upload; if
offline, the detail screen shows the queued entry and a **Sync** action retries
pending uploads when connectivity returns. Queue entries are scoped to the
signed-in user.

## Checks

Run static analysis with:

```sh
flutter analyze
```
