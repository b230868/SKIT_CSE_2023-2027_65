-- ==============================================================================
-- Prashikshan - Complete Fresh Start Data Reset Script
-- ==============================================================================
-- PURPOSE:
-- Deletes all existing user accounts, login credentials, profiles, internship
-- applications (ITRs), reviews, progress updates, documents, notifications,
-- attendance, evaluations, and storage files.
--
-- PRESERVES:
-- All tables, schema definitions, constraints, sequences, foreign keys,
-- triggers (e.g. handle_new_user), RLS policies, and storage buckets.
--
-- HOW TO RUN:
-- 1. Open your Supabase Dashboard: https://supabase.com/dashboard
-- 2. Select your Prashikshan project.
-- 3. In the left navigation, click "SQL Editor".
-- 4. Click "New Query", paste the entire contents of this file, and click "Run".
-- ==============================================================================

DO $$
DECLARE
    tbl text;
    -- All application data tables to clear (ordered safely with cascade)
    tables_to_clear text[] := ARRAY[
        -- Reviews & Evaluations
        'approval_reviews',
        'evaluation_history',
        'evaluations',
        'verifications',
        'attendance',
        
        -- Progress & Geo Tracking
        'geo_progress_logs',
        'geo_checkins',
        'progress_updates',
        'progress_logs',
        
        -- Documents & Files metadata
        'internship_documents',
        'documents',
        
        -- Notifications & System Logs
        'notifications',
        'erp_sync_logs',
        'company_affiliation_requests',
        
        -- Internships (ITR applications)
        'internships',
        
        -- Industry Users & Companies
        'industry_users',
        'industries',
        
        -- Role-specific & Profiles
        'students',
        'faculty',
        'profiles'
    ];
BEGIN
    -- 1. Truncate all application data tables in the public schema
    FOREACH tbl IN ARRAY tables_to_clear LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = tbl
        ) THEN
            EXECUTE format('TRUNCATE TABLE public.%I RESTART IDENTITY CASCADE;', tbl);
            RAISE NOTICE 'Cleared table: public.%', tbl;
        END IF;
    END LOOP;

    -- 2. Clear uploaded storage files (keeps storage buckets intact)
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'storage' AND table_name = 'objects'
    ) THEN
        DELETE FROM storage.objects;
        RAISE NOTICE 'Cleared all files from Supabase Storage.';
    END IF;

    -- 3. Delete all authentication credentials, users, and sessions
    -- This wipes all student, faculty, tp_officer, and industry logins so they can register fresh.
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'auth' AND table_name = 'users'
    ) THEN
        DELETE FROM auth.users;
        RAISE NOTICE 'Cleared all user credentials from auth.users.';
    END IF;

    RAISE NOTICE 'Database reset completed successfully! All tables are empty and ready for fresh registrations.';
END $$;
