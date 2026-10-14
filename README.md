# Prashikshan

Prashikshan is a Flutter application for managing internships and ITR submissions.

## Setup

1. Install Flutter.
2. Copy `.env.json.example` to `.env.json` and set `SUPABASE_URL` and
   `SUPABASE_PUBLISHABLE_KEY` to the public client values for your Supabase
   project. Never use the `service_role` key in the app.
3. Fetch dependencies with `flutter pub get`.
4. Apply `supabase/schema.sql` to a new Supabase project, then apply the
   migrations in `supabase/migrations/`.
5. In Supabase Dashboard > Authentication > URL Configuration, add
   `http://localhost:8080/**` to the allowed redirect URLs for local web
   signup confirmation. Ensure the confirmation email template links to
   `{{ .ConfirmationURL }}`.
6. Run the web app with
   `flutter run -d chrome --web-port=8080 --dart-define-from-file=.env.json`.

Run static analysis and tests with `flutter analyze` and `flutter test`.

Keep `.env.json` local; it is excluded from Git. Analysis and tests do not
require Supabase credentials.
Flutter app for internship applications, approvals, documents, and progress
tracking.

## Run locally

1. Copy `.env.example` to `.env`.
2. Set `SUPABASE_URL` and either `SUPABASE_PUBLISHABLE_KEY` or
   `SUPABASE_ANON_KEY` using the public key from your Supabase project.
3. Install dependencies and start Flutter:

   ```sh
   flutter pub get
   flutter run
   ```

For browser development, use `flutter run -d chrome` or
`flutter run -d web-server --web-hostname 127.0.0.1`.

## Geo-tagged progress and offline queue

Apply [`supabase/migrations/20261011000000_geo_progress_offline_cache.sql`](./supabase/migrations/20261011000000_geo_progress_offline_cache.sql)
in the Supabase SQL Editor after the base schema. Approved internships can then
submit progress from their detail screen with a GPS fix. Updates are written to
the existing `progress_updates` table, so earlier progress remains visible.

Submissions are stored in Hive before upload. When offline, the detail screen
shows the queued entry and a **Sync** action retries pending uploads when the
device is connected. Queue entries are scoped to the signed-in user. Location
permission is requested when the user submits an update.
