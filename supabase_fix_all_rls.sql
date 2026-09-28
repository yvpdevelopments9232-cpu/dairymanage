-- ==============================================================================
-- MASTER SUPABASE SCHEMA, CONSTRAINTS & PERMISSIONS SCRIPT
-- Paste and Run this script in your Supabase SQL Editor:
-- Dashboard -> SQL Editor -> New Query -> Paste & Click 'Run'
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. PUBLIC.USERS TABLE (Required for Application Account Status Verification)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT users_status_check CHECK (status IN ('active', 'pending'))
);

-- Trigger to automatically create/sync public.users row when user signs up
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

-- Backfill any existing auth users into public.users
INSERT INTO public.users (id, email, status)
SELECT id, email, 'active'
FROM auth.users
ON CONFLICT (id) DO NOTHING;


-- ------------------------------------------------------------------------------
-- 2. STAFF & STAFF ATTENDANCE MODULE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.staff (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    phone TEXT,
    role TEXT,
    salary_amount NUMERIC(10, 2) DEFAULT 0,
    salary_type TEXT DEFAULT 'Monthly', 
    balance NUMERIC(10, 2) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    user_id UUID,
    owner_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.staff_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff(id) ON DELETE CASCADE,
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    type TEXT NOT NULL, 
    amount NUMERIC(10, 2) NOT NULL,
    remarks TEXT,
    user_id UUID,
    owner_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.staff_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID REFERENCES public.staff(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(50) NOT NULL DEFAULT 'Present',
    user_id UUID,
    owner_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure staff_attendance columns exist if table already existed
ALTER TABLE public.staff_attendance ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.staff_attendance ADD COLUMN IF NOT EXISTS owner_id UUID;
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS owner_id UUID;
ALTER TABLE public.staff_transactions ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.staff_transactions ADD COLUMN IF NOT EXISTS owner_id UUID;

-- Ensure unique constraint on (staff_id, attendance_date) for upsert onConflict
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'uq_staff_attendance'
    ) THEN
        ALTER TABLE public.staff_attendance 
        ADD CONSTRAINT uq_staff_attendance UNIQUE (staff_id, attendance_date);
    END IF;
END $$;


-- ------------------------------------------------------------------------------
-- 3. BONUS MANAGEMENT MODULE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bonus_settings (
    id TEXT PRIMARY KEY DEFAULT 'default_settings',
    cow_rate NUMERIC(10, 2) NOT NULL DEFAULT 0.40,
    buffalo_rate NUMERIC(10, 2) NOT NULL DEFAULT 0.50,
    user_id UUID,
    owner_id UUID,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Ensure default configuration seed row exists
INSERT INTO public.bonus_settings (id, cow_rate, buffalo_rate, updated_at)
VALUES ('default_settings', 0.40, 0.50, NOW())
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.bonus_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    farmer_id UUID NOT NULL,
    farmer_name VARCHAR(255),
    farmer_no VARCHAR(50),
    animal_type VARCHAR(50) NOT NULL DEFAULT 'Buffalo',
    from_date DATE NOT NULL,
    to_date DATE NOT NULL,
    milk_quantity NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    bonus_rate NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    total_bonus NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    previous_paid NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    paid_amount NUMERIC(12, 2) NOT NULL,
    total_paid NUMERIC(12, 2) NOT NULL,
    remaining_bonus NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_mode VARCHAR(50) NOT NULL DEFAULT 'Cash',
    transaction_number VARCHAR(100),
    remarks TEXT,
    user_id UUID,
    owner_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bonus_trans_farmer ON public.bonus_transactions(farmer_id);
CREATE INDEX IF NOT EXISTS idx_bonus_trans_dates ON public.bonus_transactions(payment_date, from_date, to_date);


-- ------------------------------------------------------------------------------
-- 4. MAIN DAIRY MODULE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.main_dairies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dairy_no INT GENERATED BY DEFAULT AS IDENTITY,
    name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    mobile VARCHAR(20),
    email VARCHAR(100),
    village VARCHAR(255),
    animal_type VARCHAR(50) DEFAULT 'Cow',
    address TEXT,
    opening_balance NUMERIC(12,2) DEFAULT 0.00,
    current_balance NUMERIC(12,2) DEFAULT 0.00,
    status BOOLEAN DEFAULT TRUE,
    notes TEXT,
    user_id UUID,
    owner_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.main_dairies ADD COLUMN IF NOT EXISTS dairy_no INT GENERATED BY DEFAULT AS IDENTITY;
ALTER TABLE public.main_dairies ADD COLUMN IF NOT EXISTS village VARCHAR(255);
ALTER TABLE public.main_dairies ADD COLUMN IF NOT EXISTS animal_type VARCHAR(50) DEFAULT 'Cow';
ALTER TABLE public.main_dairies ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.main_dairies ADD COLUMN IF NOT EXISTS owner_id UUID;

CREATE TABLE IF NOT EXISTS public.main_dairy_rate_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dairy_id UUID,
    animal_type VARCHAR(50) NOT NULL,
    rate_type VARCHAR(50) DEFAULT 'Increase',
    base_fat NUMERIC(5,2) NOT NULL,
    base_snf NUMERIC(5,2) NOT NULL,
    base_rate NUMERIC(8,2) NOT NULL,
    fat_rate NUMERIC(8,2) NOT NULL DEFAULT 0.00,
    snf_rate NUMERIC(8,2) NOT NULL DEFAULT 0.00,
    fat_point NUMERIC(5,2) DEFAULT 0.1,
    snf_point NUMERIC(5,2) DEFAULT 0.1,
    fat_range_from NUMERIC(5,2) DEFAULT 0.00,
    fat_range_to NUMERIC(5,2) DEFAULT 15.00,
    snf_range_from NUMERIC(5,2) DEFAULT 0.00,
    snf_range_to NUMERIC(5,2) DEFAULT 15.00,
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_active BOOLEAN DEFAULT TRUE,
    user_id UUID,
    owner_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.main_dairy_rate_configs ADD COLUMN IF NOT EXISTS fat_point NUMERIC(5,2) DEFAULT 0.1;
ALTER TABLE public.main_dairy_rate_configs ADD COLUMN IF NOT EXISTS snf_point NUMERIC(5,2) DEFAULT 0.1;
ALTER TABLE public.main_dairy_rate_configs ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.main_dairy_rate_configs ADD COLUMN IF NOT EXISTS owner_id UUID;

CREATE TABLE IF NOT EXISTS public.main_dairy_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    main_dairy_id UUID REFERENCES public.main_dairies(id) ON DELETE CASCADE,
    collection_date DATE NOT NULL DEFAULT CURRENT_DATE,
    shift VARCHAR(20) NOT NULL,
    milk_type VARCHAR(50) NOT NULL,
    quantity NUMERIC(10,2) NOT NULL,
    fat NUMERIC(5,2) NOT NULL,
    snf NUMERIC(5,2) NOT NULL,
    rate NUMERIC(8,2) NOT NULL,
    total_amount NUMERIC(12,2) NOT NULL,
    payment_status VARCHAR(50) DEFAULT 'Pending',
    remarks TEXT,
    user_id UUID,
    owner_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.main_dairy_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    main_dairy_id UUID REFERENCES public.main_dairies(id) ON DELETE CASCADE,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    amount NUMERIC(12,2) NOT NULL,
    payment_mode VARCHAR(50) DEFAULT 'Bank Transfer',
    reference_no VARCHAR(100),
    remarks TEXT,
    user_id UUID,
    owner_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- ------------------------------------------------------------------------------
-- 5. RATE CONFIGS & MILK COLLECTIONS MISSING COLUMNS
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'rate_configs') THEN
        ALTER TABLE public.rate_configs ADD COLUMN IF NOT EXISTS fat_point NUMERIC(5,2) DEFAULT 0.1;
        ALTER TABLE public.rate_configs ADD COLUMN IF NOT EXISTS snf_point NUMERIC(5,2) DEFAULT 0.1;
        ALTER TABLE public.rate_configs ADD COLUMN IF NOT EXISTS user_id UUID;
        ALTER TABLE public.rate_configs ADD COLUMN IF NOT EXISTS owner_id UUID;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'milk_collections') THEN
        ALTER TABLE public.milk_collections ADD COLUMN IF NOT EXISTS milk_type VARCHAR(50) DEFAULT 'Cow Milk';
        ALTER TABLE public.milk_collections ADD COLUMN IF NOT EXISTS user_id UUID;
        ALTER TABLE public.milk_collections ADD COLUMN IF NOT EXISTS owner_id UUID;
    END IF;
END $$;


-- ------------------------------------------------------------------------------
-- 6. FULL ROW LEVEL SECURITY (RLS) & UNRESTRICTED PUBLIC CRUD PERMISSIONS
-- This ensures DELETE, INSERT, UPDATE, and SELECT never get blocked by RLS policies!
-- ------------------------------------------------------------------------------
DO $do$
DECLARE
    tbl text;
    tables text[] := ARRAY[
        'users',
        'rate_configs',
        'main_dairy_rate_configs',
        'app_settings',
        'roles',
        'role_permissions',
        'products',
        'stock_transactions',
        'farmers',
        'animals',
        'main_dairies',
        'suppliers',
        'customers',
        'employees',
        'milk_collections',
        'sales',
        'sale_items',
        'purchases',
        'purchase_items',
        'expenses',
        'payments',
        'rate_history',
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
            -- Enable RLS
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', tbl);
            
            -- Drop any previous restrictive policy
            EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', 'Allow all public ' || tbl, tbl);
            EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', 'Allow full access on ' || tbl, tbl);
            EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', 'Allow all operations for authenticated users', tbl);
            EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', 'Users can read own status', tbl);
            EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I;', 'Users can insert own record', tbl);
            
            -- Create universal permissive policy allowing ALL operations (SELECT, INSERT, UPDATE, DELETE)
            EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO public USING (true) WITH CHECK (true);', 'Allow all public ' || tbl, tbl);
            
            -- Grant table permissions
            EXECUTE format('GRANT ALL ON public.%I TO public, anon, authenticated;', tbl);
        END IF;
    END LOOP;
END $do$;

-- Grant sequence permissions so auto-increment/serial IDs insert cleanly
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO public, anon, authenticated;
