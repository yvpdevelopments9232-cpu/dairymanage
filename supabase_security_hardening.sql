-- ==============================================================================
-- MASTER SUPABASE SECURITY HARDENING & TENANT ISOLATION SCRIPT
-- Paste and Run this in your Supabase SQL Editor:
-- Dashboard -> SQL Editor -> New Query -> Paste & Click 'Run'
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. REVOKE DANGEROUS PUBLIC / ANONYMOUS ACCESS
-- ------------------------------------------------------------------------------
-- Prevents unauthenticated users with anonKey from performing CRUD operations
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;

-- Grant authenticated users access (which is strictly bounded by RLS below)
GRANT USAGE ON SCHEMA public TO authenticated, anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Allow anonymous & authenticated users to view subscription plans
GRANT SELECT ON public.subscription_plans TO anon, authenticated;


-- ------------------------------------------------------------------------------
-- 2. ENSURE REQUIRED COLUMNS & CONSTRAINTS EXIST
-- ------------------------------------------------------------------------------
-- Add user_id to child tables if missing
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'sale_items') THEN
        ALTER TABLE public.sale_items ADD COLUMN IF NOT EXISTS user_id UUID;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'purchase_items') THEN
        ALTER TABLE public.purchase_items ADD COLUMN IF NOT EXISTS user_id UUID;
    END IF;
END $$;


-- ------------------------------------------------------------------------------
-- 3. HARDEN PUBLIC.USERS (Account Verification & Status Control)
-- ------------------------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Drop all old/insecure policies
DROP POLICY IF EXISTS "Allow all public users" ON public.users;
DROP POLICY IF EXISTS "Allow full access on users" ON public.users;
DROP POLICY IF EXISTS "Users can read own status" ON public.users;
DROP POLICY IF EXISTS "Users can insert own record" ON public.users;
DROP POLICY IF EXISTS "Authenticated users can select status" ON public.users;
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Users can insert own pending profile" ON public.users;

-- Users can ONLY read their own status and profile
CREATE POLICY "Users can read own profile"
    ON public.users
    FOR SELECT TO authenticated
    USING (auth.uid() = id);

-- Users can only insert their own row with status = 'pending'
CREATE POLICY "Users can insert own pending profile"
    ON public.users
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = id AND status = 'pending');

-- Prevent users from updating their own status to 'active'
-- (Only admin via Supabase Dashboard / service_role can update public.users)


-- ------------------------------------------------------------------------------
-- 4. HARDEN SUBSCRIPTIONS & PAYMENTS
-- ------------------------------------------------------------------------------
-- A. subscription_plans (Public read-only, no client mutations)
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all public subscription_plans" ON public.subscription_plans;
DROP POLICY IF EXISTS "Allow public read for subscription plans" ON public.subscription_plans;

CREATE POLICY "Public read for subscription plans"
    ON public.subscription_plans
    FOR SELECT TO anon, authenticated
    USING (true);

-- B. subscriptions (User licenses)
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all public subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can view their own subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can insert their own subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can update their own subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can read own subscriptions" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can submit pending subscription" ON public.subscriptions;
DROP POLICY IF EXISTS "Users can update pending subscription" ON public.subscriptions;

-- Users can only view their own subscription
CREATE POLICY "Users can read own subscriptions"
    ON public.subscriptions
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

-- Users can only submit PENDING subscriptions (cannot self-activate)
CREATE POLICY "Users can submit pending subscription"
    ON public.subscriptions
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id AND status = 'PENDING');

-- Users can update pending payment reference (status must remain PENDING)
CREATE POLICY "Users can update pending subscription"
    ON public.subscriptions
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id AND status = 'PENDING')
    WITH CHECK (auth.uid() = user_id AND status = 'PENDING');

-- C. subscription_payments
ALTER TABLE public.subscription_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all public subscription_payments" ON public.subscription_payments;
DROP POLICY IF EXISTS "Users can view their own subscription payments" ON public.subscription_payments;
DROP POLICY IF EXISTS "Users can record their own subscription payments" ON public.subscription_payments;
DROP POLICY IF EXISTS "Users can read own payments" ON public.subscription_payments;
DROP POLICY IF EXISTS "Users can insert own payments" ON public.subscription_payments;

CREATE POLICY "Users can read own payments"
    ON public.subscription_payments
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own payments"
    ON public.subscription_payments
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);


-- ------------------------------------------------------------------------------
-- 5. HARDEN ALL BUSINESS TABLES (Strict Tenant Isolation)
-- ------------------------------------------------------------------------------
DO $do$
DECLARE
    tbl text;
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
        'staff_attendance'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables
    LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            -- Enable Row Level Security
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', tbl);
            
            -- Drop any insecure or old policies
            EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', 'Allow all public ' || tbl, tbl);
            EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', 'Allow full access on ' || tbl, tbl);
            EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', 'Allow all operations for authenticated users', tbl);
            EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', 'Tenant isolation for ' || tbl, tbl);
            
            -- Create bulletproof tenant policy:
            -- An authenticated user can only access rows where user_id or owner_id equals their auth.uid()
            EXECUTE format('
                CREATE POLICY %I ON public.%I
                FOR ALL TO authenticated
                USING (user_id = auth.uid() OR owner_id = auth.uid())
                WITH CHECK (user_id = auth.uid() OR owner_id = auth.uid());
            ', 'Tenant isolation for ' || tbl, tbl);
            
            -- Grant table access to authenticated role
            EXECUTE format('GRANT ALL ON public.%I TO authenticated;', tbl);
        END IF;
    END LOOP;
END $do$;


-- ------------------------------------------------------------------------------
-- 6. HARDEN CHILD TABLES (sale_items & purchase_items)
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    -- sale_items
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'sale_items') THEN
        ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS "Allow all public sale_items" ON public.sale_items;
        DROP POLICY IF EXISTS "Tenant isolation for sale_items" ON public.sale_items;
        
        CREATE POLICY "Tenant isolation for sale_items" ON public.sale_items
        FOR ALL TO authenticated
        USING (
            user_id = auth.uid() 
            OR EXISTS (
                SELECT 1 FROM public.sales s 
                WHERE s.id = sale_items.sale_id 
                  AND (s.user_id = auth.uid() OR s.owner_id = auth.uid())
            )
        )
        WITH CHECK (
            user_id = auth.uid() 
            OR EXISTS (
                SELECT 1 FROM public.sales s 
                WHERE s.id = sale_items.sale_id 
                  AND (s.user_id = auth.uid() OR s.owner_id = auth.uid())
            )
        );
        GRANT ALL ON public.sale_items TO authenticated;
    END IF;

    -- purchase_items
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'purchase_items') THEN
        ALTER TABLE public.purchase_items ENABLE ROW LEVEL SECURITY;
        DROP POLICY IF EXISTS "Allow all public purchase_items" ON public.purchase_items;
        DROP POLICY IF EXISTS "Tenant isolation for purchase_items" ON public.purchase_items;
        
        CREATE POLICY "Tenant isolation for purchase_items" ON public.purchase_items
        FOR ALL TO authenticated
        USING (
            user_id = auth.uid() 
            OR EXISTS (
                SELECT 1 FROM public.purchases p 
                WHERE p.id = purchase_items.purchase_id 
                  AND (p.user_id = auth.uid() OR p.owner_id = auth.uid())
            )
        )
        WITH CHECK (
            user_id = auth.uid() 
            OR EXISTS (
                SELECT 1 FROM public.purchases p 
                WHERE p.id = purchase_items.purchase_id 
                  AND (p.user_id = auth.uid() OR p.owner_id = auth.uid())
            )
        );
        GRANT ALL ON public.purchase_items TO authenticated;
    END IF;
END $$;

-- ==============================================================================
-- END OF SCRIPT - YOUR DATABASE IS NOW BULLETPROOF & MULTI-TENANT ISOLATED!
-- ==============================================================================
