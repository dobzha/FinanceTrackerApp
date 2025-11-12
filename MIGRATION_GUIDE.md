# Migration Guide: Transaction System Update

## Overview

This guide will help you migrate your existing Finnik app to the new transaction-based balance system.

## What's Changing?

**Before:**
- Account balances were static (only changed when manually edited)
- Subscriptions and revenues only affected dashboard projections
- No transaction history

**After:**
- Account balances automatically update based on subscriptions and revenues
- All balance changes are recorded as transactions
- You can view historical balances
- Subscriptions subtract from account balances
- Revenues add to account balances

## Migration Steps

### Step 1: Backup Your Data (Recommended)

Before applying any changes, backup your Supabase database:

1. Go to Supabase Dashboard → Database → Backups
2. Create a manual backup
3. Note down your current account balances for verification

### Step 2: Update Database Schema

1. Open your Supabase Dashboard
2. Go to SQL Editor
3. Copy and paste the entire contents of `database_setup.sql`
4. Click "Run"

This will:
- ✅ Add `last_processed_date` column to existing accounts
- ✅ Create the new `transactions` table
- ✅ Set up indexes and RLS policies

**Note:** The SQL script is designed to be safe and idempotent (can be run multiple times).

### Step 3: Verify Database Changes

Run this verification query in Supabase SQL Editor:

```sql
-- Check if new column was added
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'finance_items' 
AND column_name = 'last_processed_date';

-- Check if transactions table exists
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'transactions';

-- Check RLS policies
SELECT tablename, policyname 
FROM pg_policies 
WHERE tablename IN ('finance_items', 'transactions');
```

Expected results:
- `last_processed_date` column should exist in `finance_items`
- `transactions` table should exist
- RLS policies should be present for both tables

### Step 4: Understand Existing Data Behavior

**Important:** When you first deploy the updated app:

1. **Existing Accounts**: The `last_processed_date` will default to NOW()
   - This means NO retroactive transactions will be created
   - Balances will remain as they currently are
   - Only FUTURE transactions (after deployment) will be processed

2. **To Process Retroactive Transactions**:
   - You can manually set `last_processed_date` to an earlier date
   - The app will then process all transactions since that date

### Step 5: Deploy Updated iOS App

1. Pull the latest code
2. Build and run in Xcode
3. Test thoroughly in development before releasing

### Step 6: Test the Migration

#### Test 1: Verify Existing Data
```
1. Open the app
2. Check all your accounts
3. Balances should remain UNCHANGED (for now)
4. No errors should appear
```

#### Test 2: Create New Subscription
```
1. Create a new monthly subscription for $10
2. Link it to an account (e.g., "Bank Account")
3. Note the current balance
4. Close and reopen the app
5. The account balance should be UNCHANGED
   (because last_processed_date is set to now)
```

#### Test 3: Wait for Processing
```
1. Wait 24 hours (or manually change last_processed_date)
2. Reopen the app
3. The account balance should now reflect the subscription
```

#### Test 4: Historical Balance
```
1. Go to Dashboard
2. Select a date in the past using the calendar
3. Should show the balance at that date
```

## Handling Retroactive Processing

If you want to apply transactions retroactively for existing subscriptions/revenues:

### Option A: Manual Database Update (Recommended for Testing)

```sql
-- Set last_processed_date for a specific account to 30 days ago
UPDATE finance_items 
SET last_processed_date = NOW() - INTERVAL '30 days'
WHERE id = 'YOUR_ACCOUNT_ID';

-- Or set for ALL accounts
UPDATE finance_items 
SET last_processed_date = NOW() - INTERVAL '30 days';
```

After running this, the next time the app loads, it will process all transactions from 30 days ago to now.

### Option B: Use Repetition Dates

If you want to process transactions from when the subscription/revenue was created:

```sql
-- For each account, set last_processed_date to the earliest repetition_date
-- of its subscriptions/revenues

WITH earliest_dates AS (
    SELECT 
        account_id,
        MIN(repetition_date) as earliest_date
    FROM (
        SELECT account_id, repetition_date FROM subscription_items WHERE account_id IS NOT NULL
        UNION ALL
        SELECT account_id, repetition_date FROM revenue_items WHERE account_id IS NOT NULL
    ) combined
    GROUP BY account_id
)
UPDATE finance_items f
SET last_processed_date = ed.earliest_date
FROM earliest_dates ed
WHERE f.id = ed.account_id
AND ed.earliest_date IS NOT NULL;
```

**Warning:** This will create many transactions and significantly change account balances!

## Important Considerations

### 1. Account Balances Will Change

If you process retroactive transactions, account balances will change based on:
- All past subscription occurrences (will DECREASE balance)
- All past revenue occurrences (will INCREASE balance)

**Example:**
- Account currently has: $1,000
- Monthly subscription of $50 for 6 months (retroactive)
- New balance: $1,000 - ($50 × 6) = $700

### 2. Dashboard Projections

The dashboard will continue to show projections, but now it's based on the UPDATED account balances.

### 3. One-Time Revenues

One-time revenues with past `repetition_date` will be processed only once.

### 4. Multiple Currencies

Transaction amounts are stored in their original currency and converted to USD when calculating totals.

## Rollback Plan

If something goes wrong, you can rollback:

### Step 1: Restore Database Backup
```
1. Go to Supabase Dashboard → Database → Backups
2. Select your backup
3. Click "Restore"
```

### Step 2: Revert iOS App
```
1. Git checkout to previous version
2. Redeploy
```

### Step 3: Manual Cleanup (if needed)
```sql
-- Remove transactions table
DROP TABLE IF EXISTS transactions CASCADE;

-- Remove last_processed_date column
ALTER TABLE finance_items DROP COLUMN IF EXISTS last_processed_date;
```

## Common Issues and Solutions

### Issue 1: Balances are incorrect after migration
**Solution:**
1. Check the transactions table for duplicate entries
2. Verify `last_processed_date` for each account
3. Check console logs for processing errors

```sql
-- Check transactions for an account
SELECT * FROM transactions 
WHERE account_id = 'YOUR_ACCOUNT_ID'
ORDER BY transaction_date DESC;

-- Check last_processed_date
SELECT id, name, amount, last_processed_date 
FROM finance_items;
```

### Issue 2: Transactions not being created
**Solution:**
1. Verify subscriptions/revenues have `account_id` set
2. Check if `last_processed_date` is in the past
3. Verify RLS policies are correctly set

```sql
-- Check which subscriptions/revenues are linked to accounts
SELECT id, name, account_id, repetition_date 
FROM subscription_items 
WHERE account_id IS NOT NULL;

SELECT id, name, account_id, repetition_date 
FROM revenue_items 
WHERE account_id IS NOT NULL;
```

### Issue 3: App crashes after update
**Solution:**
1. Check Xcode console for errors
2. Verify all pods/dependencies are up to date
3. Clean build folder (Cmd+Shift+K)
4. Delete app and reinstall

## Gradual Migration Strategy

For production apps with many users, consider a gradual rollout:

### Phase 1: Deploy with Default Behavior
- Deploy the update with `last_processed_date = NOW()`
- No retroactive processing
- Monitor for issues
- Duration: 1-2 weeks

### Phase 2: Opt-in Retroactive Processing
- Add a setting for users to "Sync past transactions"
- When enabled, set `last_processed_date` to earliest date
- Monitor feedback

### Phase 3: Automatic Retroactive Processing
- After confirming stability, enable for all users
- Send notification explaining balance changes

## Verification Checklist

After migration, verify:

- [ ] Database schema updated successfully
- [ ] All RLS policies are in place
- [ ] App opens without crashes
- [ ] Existing account balances are preserved (initially)
- [ ] New subscriptions/revenues create transactions
- [ ] Dashboard shows correct projections
- [ ] Historical balance viewing works
- [ ] Offline mode works
- [ ] Currency conversion is correct
- [ ] No duplicate transactions

## Support

If you encounter issues during migration:

1. Check the console logs for error messages
2. Review the `TRANSACTION_SYSTEM_IMPLEMENTATION.md` file
3. Verify database schema matches expected structure
4. Test with a single account first before rolling out widely

## Post-Migration Notes

### Data Integrity
- The system maintains referential integrity through foreign keys
- Deleting an account will cascade delete all its transactions
- Deleting a subscription/revenue will NOT delete its transactions (by design)

### Performance
- Transaction processing happens on app load
- For accounts with many linked subscriptions/revenues, this may take a few seconds
- Consider adding a loading indicator if this becomes noticeable

### Monitoring
Monitor these metrics after migration:
- Transaction processing time
- Database query performance
- Error rates
- User feedback on balance accuracy

## Success Criteria

The migration is successful when:

✅ All users can open the app without errors
✅ Account balances are accurate
✅ New transactions are created correctly
✅ Historical balance viewing works
✅ No data loss
✅ Performance is acceptable
✅ Users understand the new behavior

## Timeline Recommendation

- **Day 1**: Deploy database changes
- **Day 2**: Deploy iOS app update (with default behavior)
- **Days 3-7**: Monitor and gather feedback
- **Day 8**: Enable retroactive processing (if desired)
- **Days 9-14**: Monitor balance accuracy
- **Day 15+**: Consider complete rollout

Take your time with each phase to ensure a smooth transition!

