-- ==============================================================================
-- Supabase Account Status & Maintenance Control Migration
-- Run this script in your Supabase Project: Dashboard -> SQL Editor -> New query
-- ==============================================================================

-- 1. Create public.users table linked to auth.users
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT users_status_check CHECK (status IN ('active', 'pending'))
);

-- 2. Enable Row Level Security (RLS)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies: Authenticated users can read their own account status
DROP POLICY IF EXISTS "Users can read own status" ON public.users;
CREATE POLICY "Users can read own status"
ON public.users
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- Allow users to insert their own initial profile row (if missing)
DROP POLICY IF EXISTS "Users can insert own record" ON public.users;
CREATE POLICY "Users can insert own record"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Allow public read access to status for authenticated users
DROP POLICY IF EXISTS "Authenticated users can select status" ON public.users;
CREATE POLICY "Authenticated users can select status"
ON public.users
FOR SELECT
TO authenticated
USING (true);

-- 4. Automatically create/sync a public.users row when a user is created in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, email, status)
    VALUES (NEW.id, NEW.email, 'active')
    ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_auth_user();

-- 5. Backfill existing auth.users into public.users with 'active' status by default
INSERT INTO public.users (id, email, status)
SELECT id, email, 'active'
FROM auth.users
ON CONFLICT (id) DO NOTHING;

-- 6. Helper function for RLS checks across all business tables
-- Returns TRUE only when the calling user account has status = 'active'
CREATE OR REPLACE FUNCTION public.is_account_active()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()
          AND status = 'active'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ==============================================================================
-- Verification queries (Run these to verify after executing the script above):
-- SELECT * FROM public.users;
-- ==============================================================================
