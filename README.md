# prashikshan

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
