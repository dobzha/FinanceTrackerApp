-- ============================================
-- SUPABASE DATABASE SETUP FOR iOS & WEB SYNC
-- ============================================
-- Run this SQL in Supabase SQL Editor to enable data syncing between platforms
-- This ensures users only see their own data when signed in

-- ============================================
-- 1. FINANCE ITEMS TABLE (Accounts)
-- ============================================

-- Add last_processed_date column if it doesn't exist
-- This tracks when we last processed transactions for automatic balance updates
ALTER TABLE finance_items 
ADD COLUMN IF NOT EXISTS last_processed_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Enable Row Level Security
ALTER TABLE finance_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view own finance items" ON finance_items;
DROP POLICY IF EXISTS "Users can insert own finance items" ON finance_items;
DROP POLICY IF EXISTS "Users can update own finance items" ON finance_items;
DROP POLICY IF EXISTS "Users can delete own finance items" ON finance_items;

-- Policy: Users can only SELECT their own data
CREATE POLICY "Users can view own finance items"
ON finance_items
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only INSERT with their own user_id
CREATE POLICY "Users can insert own finance items"
ON finance_items
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only UPDATE their own data
CREATE POLICY "Users can update own finance items"
ON finance_items
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only DELETE their own data
CREATE POLICY "Users can delete own finance items"
ON finance_items
FOR DELETE
USING (auth.uid() = user_id);

-- ============================================
-- 2. SUBSCRIPTION ITEMS TABLE
-- ============================================

-- Enable Row Level Security
ALTER TABLE subscription_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view own subscriptions" ON subscription_items;
DROP POLICY IF EXISTS "Users can insert own subscriptions" ON subscription_items;
DROP POLICY IF EXISTS "Users can update own subscriptions" ON subscription_items;
DROP POLICY IF EXISTS "Users can delete own subscriptions" ON subscription_items;

-- Policy: Users can only SELECT their own data
CREATE POLICY "Users can view own subscriptions"
ON subscription_items
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only INSERT with their own user_id
CREATE POLICY "Users can insert own subscriptions"
ON subscription_items
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only UPDATE their own data
CREATE POLICY "Users can update own subscriptions"
ON subscription_items
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only DELETE their own data
CREATE POLICY "Users can delete own subscriptions"
ON subscription_items
FOR DELETE
USING (auth.uid() = user_id);

-- ============================================
-- 3. REVENUE ITEMS TABLE
-- ============================================

-- Enable Row Level Security
ALTER TABLE revenue_items ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view own revenues" ON revenue_items;
DROP POLICY IF EXISTS "Users can insert own revenues" ON revenue_items;
DROP POLICY IF EXISTS "Users can update own revenues" ON revenue_items;
DROP POLICY IF EXISTS "Users can delete own revenues" ON revenue_items;

-- Policy: Users can only SELECT their own data
CREATE POLICY "Users can view own revenues"
ON revenue_items
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only INSERT with their own user_id
CREATE POLICY "Users can insert own revenues"
ON revenue_items
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only UPDATE their own data
CREATE POLICY "Users can update own revenues"
ON revenue_items
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only DELETE their own data
CREATE POLICY "Users can delete own revenues"
ON revenue_items
FOR DELETE
USING (auth.uid() = user_id);

-- ============================================
-- 4. TRANSACTIONS TABLE (Balance History)
-- ============================================
-- This table stores all balance changes from subscriptions and revenues
-- Allows users to see historical balance through the dashboard calendar

-- Create the table if it doesn't exist
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES finance_items(id) ON DELETE CASCADE,
    amount NUMERIC NOT NULL,
    currency TEXT NOT NULL DEFAULT 'USD',
    transaction_date TIMESTAMP WITH TIME ZONE NOT NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('revenue', 'subscription')),
    source_id UUID NOT NULL,
    source_name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_transactions_source ON transactions(source_id);

-- Enable Row Level Security
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Users can view own transactions" ON transactions;
DROP POLICY IF EXISTS "Users can insert own transactions" ON transactions;
DROP POLICY IF EXISTS "Users can update own transactions" ON transactions;
DROP POLICY IF EXISTS "Users can delete own transactions" ON transactions;

-- Policy: Users can only SELECT their own data
CREATE POLICY "Users can view own transactions"
ON transactions
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can only INSERT with their own user_id
CREATE POLICY "Users can insert own transactions"
ON transactions
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only UPDATE their own data
CREATE POLICY "Users can update own transactions"
ON transactions
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can only DELETE their own data
CREATE POLICY "Users can delete own transactions"
ON transactions
FOR DELETE
USING (auth.uid() = user_id);

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Run these after applying the policies to verify they're working

-- Check if RLS is enabled
SELECT tablename, rowsecurity FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('finance_items', 'subscription_items', 'revenue_items', 'transactions');

-- Check all policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename IN ('finance_items', 'subscription_items', 'revenue_items', 'transactions');

-- ============================================
-- IMPORTANT NOTES:
-- ============================================
-- 1. These policies ensure users can ONLY see/modify their own data
-- 2. auth.uid() returns the currently authenticated user's ID
-- 3. Both iOS and Web apps will respect these policies automatically
-- 4. Data will sync seamlessly when signed in with the same Google account
-- 5. If a user is not authenticated, they won't be able to access any data
--
-- After applying these policies:
-- - Sign in on iOS → See only your data
-- - Sign in on Web with same account → See the same data
-- - Create data on iOS → Instantly available on Web (and vice versa)

