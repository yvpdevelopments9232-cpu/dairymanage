-- ==============================================================================
-- DAIRY MANAGEMENT - SUBSCRIPTION & LICENSE MANAGEMENT MODULE SCHEMA
-- Run this in your Supabase SQL Editor (Dashboard -> SQL Editor -> New Query -> Run)
-- ==============================================================================

-- 1. SUBSCRIPTION PLANS TABLE
CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id TEXT PRIMARY KEY,                       -- 'basic', 'premium', 'enterprise'
    name TEXT NOT NULL,                        -- 'Basic Plan', 'Premium Plan', etc.
    description TEXT,
    price NUMERIC(10, 2) NOT NULL,             -- 999.00, 2499.00, 4999.00
    duration_days INTEGER NOT NULL DEFAULT 365,
    billing_cycle TEXT NOT NULL DEFAULT 'Year',
    badge TEXT,                                -- 'MOST POPULAR', etc.
    features JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. SUBSCRIPTIONS TABLE (User Licenses)
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id TEXT NOT NULL UNIQUE,      -- Formatted ID: e.g. 'DM-20260901-001'
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_id TEXT NOT NULL REFERENCES public.subscription_plans(id),
    plan_name TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    start_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    end_date TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'ACTIVE',     -- 'ACTIVE', 'EXPIRED', 'CANCELLED'
    auto_renewal BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. SUBSCRIPTION PAYMENTS & INVOICES TABLE
CREATE TABLE IF NOT EXISTS public.subscription_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id TEXT NOT NULL UNIQUE,       -- e.g. 'TXN202609010123'
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_id TEXT NOT NULL,             -- References subscription_id code
    plan_id TEXT NOT NULL,
    plan_name TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    payment_method TEXT NOT NULL,              -- 'UPI', 'Credit/Debit Card', 'Net Banking', 'Wallet'
    payment_status TEXT NOT NULL DEFAULT 'SUCCESS', -- 'SUCCESS', 'PENDING', 'FAILED'
    invoice_no TEXT,                           -- e.g. 'INV-2026-001'
    payment_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ==============================================================================
-- INDEXES FOR FAST QUERYING
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON public.subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_end_date ON public.subscriptions(end_date);
CREATE INDEX IF NOT EXISTS idx_sub_payments_user ON public.subscription_payments(user_id);
CREATE INDEX IF NOT EXISTS idx_sub_payments_txn ON public.subscription_payments(transaction_id);

-- ==============================================================================
-- ENABLE ROW LEVEL SECURITY (RLS)
-- ==============================================================================
ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_payments ENABLE ROW LEVEL SECURITY;

-- POLICIES: subscription_plans (Public read access for authenticated & anonymous users)
CREATE POLICY "Allow public read for subscription plans"
    ON public.subscription_plans
    FOR SELECT
    USING (true);

-- POLICIES: subscriptions (Users can only see and manage their own subscriptions)
CREATE POLICY "Users can view their own subscriptions"
    ON public.subscriptions
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own subscriptions"
    ON public.subscriptions
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own subscriptions"
    ON public.subscriptions
    FOR UPDATE
    USING (auth.uid() = user_id);

-- POLICIES: subscription_payments (Users can only view and insert their own subscription payments)
CREATE POLICY "Users can view their own subscription payments"
    ON public.subscription_payments
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can record their own subscription payments"
    ON public.subscription_payments
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- ==============================================================================
-- PRE-POPULATE DEFAULT PLANS (Basic, Premium, Enterprise)
-- ==============================================================================
INSERT INTO public.subscription_plans (id, name, description, price, duration_days, billing_cycle, badge, features, is_active)
VALUES
(
    'basic',
    'Basic Plan',
    'Essential tools for small local dairies starting milk collection and farmer records.',
    999.00,
    365,
    'Year',
    NULL,
    '["1 Dairy", "Up to 5 Farmers", "Milk Collection", "Payment Management", "Basic Reports"]'::jsonb,
    true
),
(
    'premium',
    'Premium Plan',
    'Most popular choice for growing dairies needing complete analytics, bonuses, and reports.',
    2499.00,
    365,
    'Year',
    'MOST POPULAR',
    '["Unlimited Farmers", "Milk Collection", "Payment Management", "Bonus Module", "Bank Management", "Advanced Reports", "PDF Reports & Sharing", "Dashboard Analytics", "Animal Management"]'::jsonb,
    true
),
(
    'enterprise',
    'Enterprise Plan',
    'Comprehensive multi-dairy, multi-branch solution with advanced analytics and priority support.',
    4999.00,
    365,
    'Year',
    NULL,
    '["Multiple Dairies / Branches", "Unlimited Farmers", "Advanced Analytics", "Advanced Reports & Export", "Priority 24/7 Support"]'::jsonb,
    true
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    price = EXCLUDED.price,
    features = EXCLUDED.features,
    badge = EXCLUDED.badge,
    is_active = EXCLUDED.is_active;

-- ==============================================================================
-- HELPER FUNCTION: CHECK USER ACTIVE SUBSCRIPTION
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.check_user_subscription(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    sub_record RECORD;
    is_valid BOOLEAN := false;
    days_left INTEGER := 0;
BEGIN
    SELECT * INTO sub_record
    FROM public.subscriptions
    WHERE user_id = p_user_id
    ORDER BY end_date DESC
    LIMIT 1;

    IF sub_record IS NULL THEN
        RETURN jsonb_build_object(
            'status', 'NONE',
            'is_active', false,
            'message', 'No subscription found'
        );
    END IF;

    -- Calculate days remaining
    days_left := EXTRACT(DAY FROM (sub_record.end_date - now()))::INTEGER;

    IF sub_record.status = 'PENDING' THEN
        RETURN jsonb_build_object(
            'status', 'PENDING',
            'is_active', false,
            'subscription_id', sub_record.subscription_id,
            'plan_id', sub_record.plan_id,
            'plan_name', sub_record.plan_name,
            'amount', sub_record.amount,
            'start_date', sub_record.start_date,
            'end_date', sub_record.end_date,
            'days_remaining', days_left,
            'message', 'Subscription approval is pending admin verification'
        );
    END IF;

    IF sub_record.status = 'ACTIVE' AND sub_record.end_date > now() THEN
        is_valid := true;
        RETURN jsonb_build_object(
            'status', 'ACTIVE',
            'is_active', true,
            'subscription_id', sub_record.subscription_id,
            'plan_id', sub_record.plan_id,
            'plan_name', sub_record.plan_name,
            'amount', sub_record.amount,
            'start_date', sub_record.start_date,
            'end_date', sub_record.end_date,
            'days_remaining', days_left,
            'auto_renewal', sub_record.auto_renewal
        );
    ELSE
        -- Update expired status in database if passed end_date
        IF sub_record.status = 'ACTIVE' AND sub_record.end_date <= now() THEN
            UPDATE public.subscriptions SET status = 'EXPIRED', updated_at = now() WHERE id = sub_record.id;
        END IF;

        RETURN jsonb_build_object(
            'status', 'EXPIRED',
            'is_active', false,
            'subscription_id', sub_record.subscription_id,
            'plan_id', sub_record.plan_id,
            'plan_name', sub_record.plan_name,
            'amount', sub_record.amount,
            'start_date', sub_record.start_date,
            'end_date', sub_record.end_date,
            'days_overdue', ABS(days_left),
            'message', 'Subscription expired'
        );
    END IF;
END;
$$;
