-- ==============================================================================
-- BONUS MANAGEMENT MODULE SUPABASE MIGRATION SCRIPT
-- Paste and Run this script in your Supabase SQL Editor:
-- Supabase Dashboard -> SQL Editor -> New Query -> Run
-- ==============================================================================

-- 1. BONUS SETTINGS TABLE
-- Stores configured bonus rate per liter for Cow and Buffalo milk
CREATE TABLE IF NOT EXISTS bonus_settings (
    id TEXT PRIMARY KEY DEFAULT 'default_settings',
    cow_rate NUMERIC(10, 2) NOT NULL DEFAULT 0.40,
    buffalo_rate NUMERIC(10, 2) NOT NULL DEFAULT 0.50,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_id UUID
);

-- Ensure default configuration seed row exists
INSERT INTO bonus_settings (id, cow_rate, buffalo_rate, updated_at)
VALUES ('default_settings', 0.40, 0.50, NOW())
ON CONFLICT (id) DO NOTHING;


-- 2. BONUS TRANSACTIONS TABLE
-- Stores every bonus payment transaction with audit and balance history
CREATE TABLE IF NOT EXISTS bonus_transactions (
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
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_id UUID
);

-- Ensure performance indexes for date ranges and farmer queries
CREATE INDEX IF NOT EXISTS idx_bonus_trans_farmer ON bonus_transactions(farmer_id);
CREATE INDEX IF NOT EXISTS idx_bonus_trans_dates ON bonus_transactions(payment_date, from_date, to_date);

-- 3. PERMISSIONS & ROW LEVEL SECURITY (RLS) POLICIES
-- Enable Row Level Security
ALTER TABLE bonus_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE bonus_transactions ENABLE ROW LEVEL SECURITY;

-- Allow full access (SELECT, INSERT, UPDATE, DELETE) for authenticated and anon clients
DROP POLICY IF EXISTS "Allow full access on bonus_settings" ON bonus_settings;
CREATE POLICY "Allow full access on bonus_settings"
ON bonus_settings
FOR ALL
TO public
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow full access on bonus_transactions" ON bonus_transactions;
CREATE POLICY "Allow full access on bonus_transactions"
ON bonus_transactions
FOR ALL
TO public
USING (true)
WITH CHECK (true);

-- Grant permissions to authenticated and anon roles for sync
GRANT ALL ON bonus_settings TO authenticated, anon;
GRANT ALL ON bonus_transactions TO authenticated, anon;
