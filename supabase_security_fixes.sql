-- ==============================================================================
-- MASTER SUPABASE SECURITY COMPLEMENTARY FIXES & COLUMN DEFAULTS SCRIPT
-- Paste and Run this in your Supabase SQL Editor:
-- Dashboard -> SQL Editor -> New Query -> Paste & Click 'Run'
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. SET AUTOMATIC 'DEFAULT auth.uid()' ON ALL TENANT COLUMNS
-- ------------------------------------------------------------------------------
-- This ensures ANY direct insert from the Flutter app automatically receives
-- the authenticated user's ID without requiring code rewrites.
DO $do$
DECLARE
    tbl text;
    has_user_id boolean;
    has_owner_id boolean;
    tables text[] := ARRAY[
        'farmers',
        'animals',
        'products',
        'stock_transactions',
        'suppliers',
        'customers',
        'milk_collections',
        'sales',
        'purchases',
        'sale_items',
        'purchase_items',
        'expenses',
        'payments',
        'rate_configs',
        'rate_history',
        'app_settings',
        'roles',
        'role_permissions',
        'employees',
        'main_dairies',
        'main_dairy_rate_configs',
        'main_dairy_collections',
        'main_dairy_payments',
        'bonus_settings',
        'bonus_transactions',
        'staff',
        'staff_transactions',
        'staff_attendance',
        'audit_logs'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables
    LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'public' AND table_name = tbl AND column_name = 'user_id'
            ) INTO has_user_id;

            SELECT EXISTS (
                SELECT 1 FROM information_schema.columns 
                WHERE table_schema = 'public' AND table_name = tbl AND column_name = 'owner_id'
            ) INTO has_owner_id;

            IF has_user_id THEN
                EXECUTE format('ALTER TABLE public.%I ALTER COLUMN user_id SET DEFAULT auth.uid();', tbl);
            END IF;

            IF has_owner_id THEN
                EXECUTE format('ALTER TABLE public.%I ALTER COLUMN owner_id SET DEFAULT auth.uid();', tbl);
            END IF;
        END IF;
    END LOOP;
END $do$;


-- ------------------------------------------------------------------------------
-- 2. HARDEN AUDIT_LOGS TABLE
-- ------------------------------------------------------------------------------
-- Fixes HTTP 42501 error when users switch accounts or login
DO $do$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'audit_logs') THEN
        ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS user_id UUID DEFAULT auth.uid();
        ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
        
        DROP POLICY IF EXISTS "Tenant isolation for audit_logs" ON public.audit_logs;
        DROP POLICY IF EXISTS "Allow all public audit_logs" ON public.audit_logs;
        
        CREATE POLICY "Tenant isolation for audit_logs"
            ON public.audit_logs
            FOR ALL TO authenticated
            USING (user_id = auth.uid() OR user_id IS NULL)
            WITH CHECK (user_id = auth.uid());
            
        GRANT ALL ON public.audit_logs TO authenticated;
        REVOKE ALL ON public.audit_logs FROM anon;
    END IF;
END $do$;


-- ------------------------------------------------------------------------------
-- 3. DROP ALL RESIDUAL LEAKY POLICIES ON SYSTEM TABLES
-- ------------------------------------------------------------------------------
-- Removes any hidden legacy policies that allowed anon read on roles / rate_configs
DO $do$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT schemaname, tablename, policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' AND tablename IN ('roles', 'role_permissions', 'rate_configs')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I;', pol.policyname, pol.schemaname, pol.tablename);
    END LOOP;
END $do$;


-- ------------------------------------------------------------------------------
-- 4. CLEAN POLICIES FOR ROLES (Allows viewing System Default Roles)
-- ------------------------------------------------------------------------------
-- Everyone needs to view default roles (Manager, Billing, etc. where owner_id IS NULL)
-- but can only create/update/delete their own roles.
DROP POLICY IF EXISTS "Tenant isolation for roles - SELECT" ON public.roles;
DROP POLICY IF EXISTS "Tenant isolation for roles - INSERT" ON public.roles;
DROP POLICY IF EXISTS "Tenant isolation for roles - UPDATE" ON public.roles;
DROP POLICY IF EXISTS "Tenant isolation for roles - DELETE" ON public.roles;

CREATE POLICY "Tenant isolation for roles - SELECT"
    ON public.roles
    FOR SELECT TO authenticated
    USING (owner_id = auth.uid() OR owner_id IS NULL);

CREATE POLICY "Tenant isolation for roles - INSERT"
    ON public.roles
    FOR INSERT TO authenticated
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Tenant isolation for roles - UPDATE"
    ON public.roles
    FOR UPDATE TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Tenant isolation for roles - DELETE"
    ON public.roles
    FOR DELETE TO authenticated
    USING (owner_id = auth.uid());

GRANT ALL ON public.roles TO authenticated;
REVOKE ALL ON public.roles FROM anon;


-- ------------------------------------------------------------------------------
-- 5. CLEAN POLICIES FOR ROLE_PERMISSIONS
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Tenant isolation for role_permissions - SELECT" ON public.role_permissions;
DROP POLICY IF EXISTS "Tenant isolation for role_permissions - INSERT" ON public.role_permissions;
DROP POLICY IF EXISTS "Tenant isolation for role_permissions - UPDATE" ON public.role_permissions;
DROP POLICY IF EXISTS "Tenant isolation for role_permissions - DELETE" ON public.role_permissions;

CREATE POLICY "Tenant isolation for role_permissions - SELECT"
    ON public.role_permissions
    FOR SELECT TO authenticated
    USING (owner_id = auth.uid() OR owner_id IS NULL);

CREATE POLICY "Tenant isolation for role_permissions - INSERT"
    ON public.role_permissions
    FOR INSERT TO authenticated
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Tenant isolation for role_permissions - UPDATE"
    ON public.role_permissions
    FOR UPDATE TO authenticated
    USING (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Tenant isolation for role_permissions - DELETE"
    ON public.role_permissions
    FOR DELETE TO authenticated
    USING (owner_id = auth.uid());

GRANT ALL ON public.role_permissions TO authenticated;
REVOKE ALL ON public.role_permissions FROM anon;


-- ------------------------------------------------------------------------------
-- 6. CLEAN POLICIES FOR RATE_CONFIGS (Allows viewing & deleting Default Rate Charts)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Tenant isolation for rate_configs" ON public.rate_configs;
DROP POLICY IF EXISTS "Tenant isolation for rate_configs - SELECT" ON public.rate_configs;
DROP POLICY IF EXISTS "Tenant isolation for rate_configs - INSERT" ON public.rate_configs;
DROP POLICY IF EXISTS "Tenant isolation for rate_configs - UPDATE" ON public.rate_configs;
DROP POLICY IF EXISTS "Tenant isolation for rate_configs - DELETE" ON public.rate_configs;

CREATE POLICY "Tenant isolation for rate_configs - SELECT"
    ON public.rate_configs
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR user_id IS NULL);

CREATE POLICY "Tenant isolation for rate_configs - INSERT"
    ON public.rate_configs
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Tenant isolation for rate_configs - UPDATE"
    ON public.rate_configs
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid() OR user_id IS NULL)
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Tenant isolation for rate_configs - DELETE"
    ON public.rate_configs
    FOR DELETE TO authenticated
    USING (user_id = auth.uid() OR user_id IS NULL);

GRANT ALL ON public.rate_configs TO authenticated;
REVOKE ALL ON public.rate_configs FROM anon;


-- ------------------------------------------------------------------------------
-- 6B. CLEAN POLICIES FOR MAIN_DAIRY_RATE_CONFIGS
-- ------------------------------------------------------------------------------
DO $do$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'main_dairy_rate_configs') THEN
        DROP POLICY IF EXISTS "Tenant isolation for main_dairy_rate_configs" ON public.main_dairy_rate_configs;
        DROP POLICY IF EXISTS "Tenant isolation for main_dairy_rate_configs - SELECT" ON public.main_dairy_rate_configs;
        DROP POLICY IF EXISTS "Tenant isolation for main_dairy_rate_configs - INSERT" ON public.main_dairy_rate_configs;
        DROP POLICY IF EXISTS "Tenant isolation for main_dairy_rate_configs - UPDATE" ON public.main_dairy_rate_configs;
        DROP POLICY IF EXISTS "Tenant isolation for main_dairy_rate_configs - DELETE" ON public.main_dairy_rate_configs;

        CREATE POLICY "Tenant isolation for main_dairy_rate_configs - SELECT"
            ON public.main_dairy_rate_configs
            FOR SELECT TO authenticated
            USING (user_id = auth.uid() OR user_id IS NULL);

        CREATE POLICY "Tenant isolation for main_dairy_rate_configs - INSERT"
            ON public.main_dairy_rate_configs
            FOR INSERT TO authenticated
            WITH CHECK (user_id = auth.uid());

        CREATE POLICY "Tenant isolation for main_dairy_rate_configs - UPDATE"
            ON public.main_dairy_rate_configs
            FOR UPDATE TO authenticated
            USING (user_id = auth.uid() OR user_id IS NULL)
            WITH CHECK (user_id = auth.uid());

        CREATE POLICY "Tenant isolation for main_dairy_rate_configs - DELETE"
            ON public.main_dairy_rate_configs
            FOR DELETE TO authenticated
            USING (user_id = auth.uid() OR user_id IS NULL);

        GRANT ALL ON public.main_dairy_rate_configs TO authenticated;
        REVOKE ALL ON public.main_dairy_rate_configs FROM anon;
    END IF;
END $do$;


-- ------------------------------------------------------------------------------
-- 7. ALLOW USERS TO UPDATE THEIR OWN PROFILE (Without Self-Activating)
-- ------------------------------------------------------------------------------
-- Allows updating profile info (name, mobile, address) but keeps status 'pending'
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;

CREATE POLICY "Users can update own profile"
    ON public.users
    FOR UPDATE TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id AND status = 'pending');

-- ==============================================================================
-- COMPLETED SUCCESSFULLY! ALL SYSTEM TABLES AND COLUMN DEFAULTS ARE HARDENED!
-- ==============================================================================
