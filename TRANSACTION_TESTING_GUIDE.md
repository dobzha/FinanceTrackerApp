# Quick Testing Guide: Transaction System

## Setup for Testing

### 1. Update Database Schema

```sql
-- Run this in Supabase SQL Editor
-- Copy the entire database_setup.sql file and execute it
```

### 2. Clean Install the App

```bash
# Clean build
cd FinanceTrackerApp
xcodebuild clean

# Run from Xcode
# Build and run on simulator or device
```

## Test Scenario 1: Basic Revenue Processing

**Goal:** Verify that a monthly revenue increases the account balance.

### Steps:

1. **Create an Account**
   - Name: "Test Bank"
   - Amount: $100
   - Currency: USD

2. **Create a Monthly Revenue**
   - Name: "Monthly Salary"
   - Amount: $1,000
   - Currency: USD
   - Period: Monthly
   - Repetition Date: 1st of last month (e.g., if today is April 15, set to April 1)
   - **Important:** Link to "Test Bank" account

3. **Force Retroactive Processing**
   - Go to Supabase SQL Editor
   - Run this query to set last_processed_date to 2 months ago:
   ```sql
   UPDATE finance_items 
   SET last_processed_date = NOW() - INTERVAL '2 months'
   WHERE name = 'Test Bank';
   ```

4. **Reload the App**
   - Close and reopen the app (or pull to refresh on Accounts screen)
   - Transaction processing should happen automatically

5. **Verify Results**
   - Go to Accounts tab
   - "Test Bank" should now show: $100 + $1,000 (April) + $1,000 (May) = $2,100 (if today is May)
   
6. **Check Transaction Records**
   ```sql
   SELECT * FROM transactions 
   WHERE account_id = (SELECT id FROM finance_items WHERE name = 'Test Bank')
   ORDER BY transaction_date DESC;
   ```
   - Should see 2 transaction records

**Expected Result:** ✅ Account balance increased by $2,000

---

## Test Scenario 2: Basic Subscription Processing

**Goal:** Verify that a weekly subscription decreases the account balance.

### Steps:

1. **Use the Existing Account**
   - "Test Bank" with current balance from previous test

2. **Create a Weekly Subscription**
   - Name: "Netflix"
   - Amount: $10
   - Currency: USD
   - Period: Weekly
   - Repetition Date: 7 days ago
   - **Important:** Link to "Test Bank" account

3. **Force Processing**
   ```sql
   UPDATE finance_items 
   SET last_processed_date = NOW() - INTERVAL '7 days'
   WHERE name = 'Test Bank';
   ```

4. **Reload the App**
   - Close and reopen

5. **Verify Results**
   - Account balance should decrease by $10
   - Check transactions table for new subscription record

**Expected Result:** ✅ Account balance decreased by $10

---

## Test Scenario 3: Multiple Accounts

**Goal:** Verify that transactions only affect their linked accounts.

### Steps:

1. **Create Second Account**
   - Name: "Savings"
   - Amount: $500
   - Currency: USD

2. **Create Revenue for Savings**
   - Name: "Interest"
   - Amount: $5
   - Period: Monthly
   - Repetition Date: 1 month ago
   - **Important:** Link to "Savings" account

3. **Force Processing**
   ```sql
   UPDATE finance_items 
   SET last_processed_date = NOW() - INTERVAL '1 month'
   WHERE name = 'Savings';
   ```

4. **Reload and Verify**
   - "Savings" should be $505
   - "Test Bank" should remain unchanged

**Expected Result:** ✅ Only linked account affected

---

## Test Scenario 4: Historical Balance View

**Goal:** Verify dashboard calendar shows correct historical balances.

### Steps:

1. **Go to Dashboard**
   - Should see current total balance

2. **Select Date 1 Month Ago**
   - Use the date picker/calendar
   - Select a date from last month

3. **Verify Historical Balance**
   - Should see balance calculation WITHOUT this month's transactions
   - Should be less than current balance

**Expected Result:** ✅ Historical balance is lower than current balance

---

## Test Scenario 5: Currency Conversion

**Goal:** Verify transactions work with different currencies.

### Steps:

1. **Create EUR Account**
   - Name: "Euro Account"
   - Amount: 100
   - Currency: EUR

2. **Create EUR Revenue**
   - Name: "Consulting"
   - Amount: 500
   - Period: Monthly
   - Currency: EUR
   - Repetition Date: 1 month ago
   - **Important:** Link to "Euro Account"

3. **Force Processing**
   ```sql
   UPDATE finance_items 
   SET last_processed_date = NOW() - INTERVAL '1 month';
   ```

4. **Reload and Verify**
   - "Euro Account" should be 600 EUR
   - Dashboard should show converted USD total

**Expected Result:** ✅ EUR account updates correctly, dashboard converts to USD

---

## Test Scenario 6: One-Time Revenue

**Goal:** Verify one-time revenues are processed only once.

### Steps:

1. **Create One-Time Revenue**
   - Name: "Bonus"
   - Amount: $1,000
   - Period: Once
   - Repetition Date: 3 days ago
   - Link to "Test Bank"

2. **Force Processing to 5 Days Ago**
   ```sql
   UPDATE finance_items 
   SET last_processed_date = NOW() - INTERVAL '5 days'
   WHERE name = 'Test Bank';
   ```

3. **Reload**
   - Should process the one-time revenue

4. **Force Processing Again**
   ```sql
   UPDATE finance_items 
   SET last_processed_date = NOW() - INTERVAL '5 days'
   WHERE name = 'Test Bank';
   ```

5. **Reload Again**
   - Balance should NOT increase again

**Expected Result:** ✅ One-time revenue processed only once

---

## Test Scenario 7: Offline Mode

**Goal:** Verify transaction system works offline.

### Steps:

1. **Turn on Airplane Mode**
   
2. **Create Local Account**
   - Name: "Offline Account"
   - Amount: $50

3. **Create Local Revenue**
   - Name: "Offline Test"
   - Amount: $100
   - Period: Monthly
   - Link to "Offline Account"

4. **Check Balance**
   - Should still be $50 (no processing yet)

5. **Turn off Airplane Mode**

6. **Sign In (if needed)**
   - Data should sync to cloud

7. **Wait and Reload**
   - Eventually, transaction should process

**Expected Result:** ✅ Works offline, syncs when online

---

## Test Scenario 8: Dashboard Projections

**Goal:** Verify dashboard still shows future projections.

### Steps:

1. **Go to Dashboard**
   - Check current balance
   - Should show updated balances from all accounts

2. **Check Monthly Stats**
   - Monthly subscriptions total
   - Monthly revenues total
   - Should still work correctly

3. **Check Projection Chart**
   - Should show 12-month projection
   - Should start from CURRENT updated balances
   - Should project forward based on recurring items

**Expected Result:** ✅ Dashboard shows updated balances + projections

---

## Common Issues and Solutions

### Issue: Balance Not Updating

**Check:**
```sql
-- Verify subscription/revenue has account_id
SELECT id, name, account_id FROM subscription_items WHERE name = 'YOUR_SUBSCRIPTION_NAME';

-- Check last_processed_date
SELECT name, last_processed_date FROM finance_items WHERE name = 'YOUR_ACCOUNT_NAME';

-- Check if transactions were created
SELECT COUNT(*) FROM transactions;
```

**Solution:**
- Make sure account_id is set when creating subscription/revenue
- Set last_processed_date to past date
- Check console logs for errors

### Issue: Too Many Transactions

**Check:**
```sql
-- Count transactions per account
SELECT 
    f.name,
    COUNT(t.id) as transaction_count
FROM finance_items f
LEFT JOIN transactions t ON f.id = t.account_id
GROUP BY f.name;
```

**Solution:**
- Delete duplicate transactions
- Verify repetition_date is correct
- Check for runaway loops (shouldn't happen)

### Issue: Wrong Historical Balance

**Check:**
```sql
-- Get all transactions for an account
SELECT 
    transaction_date,
    amount,
    transaction_type,
    source_name
FROM transactions
WHERE account_id = 'YOUR_ACCOUNT_ID'
ORDER BY transaction_date;
```

**Solution:**
- Verify transactions were created correctly
- Check date filtering logic
- Verify currency conversions

---

## Debug Queries

### View All Data for an Account

```sql
SELECT 
    f.name as account_name,
    f.amount as current_balance,
    f.currency,
    f.last_processed_date,
    COUNT(DISTINCT s.id) as subscriptions_count,
    COUNT(DISTINCT r.id) as revenues_count,
    COUNT(DISTINCT t.id) as transactions_count
FROM finance_items f
LEFT JOIN subscription_items s ON f.id = s.account_id
LEFT JOIN revenue_items r ON f.id = r.account_id  
LEFT JOIN transactions t ON f.id = t.account_id
GROUP BY f.id, f.name, f.amount, f.currency, f.last_processed_date;
```

### View Transaction History

```sql
SELECT 
    t.transaction_date,
    t.amount,
    t.currency,
    t.transaction_type,
    t.source_name,
    f.name as account_name
FROM transactions t
JOIN finance_items f ON t.account_id = f.id
ORDER BY t.transaction_date DESC
LIMIT 50;
```

### Reset Everything (Nuclear Option)

```sql
-- Delete all transactions
DELETE FROM transactions;

-- Reset all last_processed_dates to now
UPDATE finance_items SET last_processed_date = NOW();

-- Or reset to a specific date
UPDATE finance_items SET last_processed_date = '2024-04-01 00:00:00+00';
```

---

## Performance Testing

### Test with Many Transactions

1. Create account with 12-month-old monthly revenue
2. Set last_processed_date to 1 year ago
3. Reload app
4. Should create 12 transactions quickly (< 2 seconds)

### Test with Multiple Accounts

1. Create 10 accounts
2. Link 5 subscriptions and 5 revenues to different accounts
3. Set all last_processed_dates to 3 months ago
4. Reload app
5. Should process all without hanging

---

## Success Checklist

✅ Account balances update when revenues/subscriptions are linked
✅ Transactions are stored in database
✅ Historical balance viewing works
✅ Dashboard shows updated balances
✅ Projections still work correctly
✅ Multiple currencies work
✅ Offline mode works
✅ No duplicate transactions
✅ One-time revenues process only once
✅ Performance is acceptable

---

## When to Stop Testing

You're ready to deploy when:

1. All test scenarios pass
2. No console errors
3. Database queries show correct data
4. App doesn't crash
5. Performance is good
6. You understand how the system works

Happy testing! 🎉

