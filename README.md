# prashikshan

Prashikshan is a Flutter application for managing internships and ITR submissions.

## Setup

1. Install Flutter.
2. Copy `.env.example` to `.env` and set `SUPABASE_URL` and `SUPABASE_ANON_KEY`
   to the values for your Supabase project.
3. Fetch dependencies with `flutter pub get`.
4. Apply `supabase/schema.sql` to a new Supabase project, then apply the
   migrations in `supabase/migrations/`.
5. Run the app with `flutter run`.

Run static analysis and tests with `flutter analyze` and `flutter test`.

Keep `.env` local; it is excluded from Git.
