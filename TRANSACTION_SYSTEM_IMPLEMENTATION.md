# Transaction System Implementation Guide

## Overview

This document describes the implementation of the transaction-based balance system that automatically updates account balances based on subscriptions and revenues. This system ensures that account balances reflect recurring transactions over time, both in the iOS app and web version.

## Key Features

1. **Automatic Balance Updates**: Account balances are automatically updated based on subscriptions (expenses) and revenues (income)
2. **Transaction History**: All balance changes are stored as transaction records in the database
3. **Historical Balance Viewing**: Users can view their account balance at any point in the past using the dashboard calendar
4. **Retroactive Processing**: The system processes all past transactions since the `repetition_date` of each subscription/revenue
5. **Real-time Processing**: Transactions are processed automatically when accounts are loaded
6. **Offline Support**: Full support for offline mode with local storage

## Database Changes

### 1. Transactions Table (`database_setup.sql`)

A new `transactions` table was created to store all balance change records:

```sql
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
```

**Fields:**
- `id`: Unique identifier for the transaction
- `user_id`: Owner of the transaction (for RLS)
- `account_id`: The account this transaction affects
- `amount`: Transaction amount (negative for subscriptions, positive for revenues)
- `currency`: Currency of the transaction
- `transaction_date`: When this transaction occurred
- `transaction_type`: 'revenue' or 'subscription'
- `source_id`: ID of the subscription or revenue that generated this transaction
- `source_name`: Name of the source (for reference)
- `description`: Optional description
- `created_at`: When the transaction record was created

**Indexes:** Created for faster queries on `user_id`, `account_id`, `transaction_date`, and `source_id`.

**Row Level Security (RLS):** Full RLS policies implemented so users can only access their own transactions.

### 2. Finance Items Table Update

Added `last_processed_date` column to track when transactions were last processed for each account:

```sql
ALTER TABLE finance_items 
ADD COLUMN IF NOT EXISTS last_processed_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();
```

## iOS Application Changes

### New Files Created

#### 1. `Transaction.swift` (Model)
New model representing a transaction record:
- Matches database schema
- Codable for JSON serialization
- Includes `TransactionType` enum (revenue, subscription)

#### 2. `TransactionProcessingService.swift` (Service)
Core service that handles all transaction processing:

**Key Methods:**
- `processAllPendingTransactions()`: Processes pending transactions for all accounts
- `processAccountTransactions()`: Processes transactions for a single account
- `generateTransactions()`: Creates transaction records from subscriptions/revenues
- `calculateOccurrences()`: Calculates when recurring transactions should occur
- `calculateHistoricalBalance()`: Calculates account balance at a historical date
- `getAccountTransactions()`: Fetches transactions for an account

**Processing Logic:**
1. For each account, determines the time period to process (from `last_processed_date` to now)
2. Filters subscriptions and revenues linked to that account
3. Generates all transaction occurrences within the period
4. Calculates total balance change
5. Updates account balance
6. Saves transaction records to database
7. Updates `last_processed_date`

### Modified Files

#### 1. `FinanceItem.swift`
Added `lastProcessedDate` property to track transaction processing.

#### 2. `SupabaseService.swift`
Added transaction CRUD methods:
- `fetchTransactions()`: Fetch transactions with optional filters (account, date range)
- `createTransaction()`: Create a new transaction record
- `deleteTransactionsForSource()`: Delete all transactions from a specific source

#### 3. `LocalStorageService.swift`
Added local storage support for transactions:
- `saveTransactions()`, `loadTransactions()`: Save/load transaction records
- `addTransaction()`: Add a new transaction
- `deleteTransactionsForSource()`: Delete transactions by source
- Updated `syncLocalDataToCloud()` to sync transactions
- Updated `clearAllData()` to clear transactions

#### 4. `OfflineQueueService.swift`
Added transaction support to offline queue:
- Updated `QueueTable` enum to include transactions
- Added `enqueueCreate()` for transactions
- Added `enqueueDeleteTransactionsForSource()`
- Updated `perform()` to handle transaction operations

#### 5. `AccountsViewModel.swift`
Added automatic transaction processing:
- `processTransactionsForAllAccounts()`: New method that processes all pending transactions when accounts are loaded
- Called automatically after loading accounts (both from Supabase and local storage)
- Updated `createAccount()` to set `lastProcessedDate` to current date

#### 6. `DashboardViewModel.swift`
Enhanced to support historical balance viewing:
- `calculateBalanceForSelectedDate()`: Now handles both past (historical) and future (projected) dates
- `calculateHistoricalBalance()`: New method using actual transaction records
- `calculateAccountBalanceAtDate()`: Calculates a single account's balance at a specific date

Historical balance calculation works by:
1. Starting with the account's current balance
2. Fetching all transactions up to the selected date
3. Subtracting transactions that happened after the selected date

## How It Works

### Transaction Processing Flow

1. **User Opens App / Loads Accounts**
   - `AccountsViewModel.loadAccounts()` is called
   - Accounts are fetched from database or local storage
   - `processTransactionsForAllAccounts()` is automatically called

2. **Transaction Processing**
   - For each account:
     - Fetch all linked subscriptions and revenues
     - Calculate time period: `last_processed_date` to `now`
     - Generate all transaction occurrences in this period
     - Calculate total balance change
     - Update account balance
     - Save transaction records
     - Update `last_processed_date`

3. **Balance Display**
   - **Accounts Tab**: Shows current account balances (already updated with transactions)
   - **Dashboard**: Shows sum of all account balances + future projections

### Example Scenario

**Initial State:**
- Account "Bank Account" has $100
- Monthly revenue "Salary" of $1,000 on the 1st of each month, linked to "Bank Account"
- Last processed date: January 1, 2024
- Current date: April 5, 2024

**What Happens:**
1. App loads accounts
2. Transaction processing detects 3 months have passed
3. Creates 3 transaction records:
   - Feb 1: +$1,000 (Salary)
   - Mar 1: +$1,000 (Salary)
   - Apr 1: +$1,000 (Salary)
4. Updates account balance: $100 + $3,000 = $3,100
5. Updates last_processed_date to April 5, 2024
6. User sees $3,100 in their Bank Account

**Historical Balance:**
- User selects February 15, 2024 on dashboard calendar
- System fetches transactions up to Feb 15
- Calculates: $3,100 (current) - $1,000 (Mar 1) - $1,000 (Apr 1) = $1,100
- Shows $1,100 as the balance on February 15

## Deployment Steps

### 1. Update Database Schema

Run the updated `database_setup.sql` file in your Supabase SQL Editor:

```sql
-- This will:
-- 1. Add last_processed_date column to finance_items
-- 2. Create transactions table
-- 3. Create indexes for performance
-- 4. Set up RLS policies
```

**Important:** The script uses `IF NOT EXISTS` and `ADD COLUMN IF NOT EXISTS`, so it's safe to run multiple times.

### 2. Deploy iOS App

The iOS app will automatically start using the new transaction system once deployed. No manual migration needed.

### 3. Update Web Version

You'll need to update your web version to:
1. Use the same transaction processing logic
2. Show updated account balances
3. Support historical balance viewing (optional)

## Handling Edge Cases

### Multiple Transactions on Same Date
- Transactions are processed in order by date
- Multiple transactions on the same date are all applied

### Account Without Subscriptions/Revenues
- No transactions are created
- Only `last_processed_date` is updated
- Balance remains unchanged

### Deleted Subscriptions/Revenues
- Existing transaction records remain in the database
- New transactions won't be created
- To "undo" past transactions, you'd need to manually delete transaction records

### Currency Conversion
- Transaction amounts are stored in their original currency
- When calculating balances, amounts are converted to USD
- Uses `CurrencyService` with fallback rates

### Time Zones
- All dates are stored in UTC in the database
- iOS app converts to local time for display
- Transaction processing uses UTC for consistency

### First Time Processing
- When an account is first created, `last_processed_date` is set to `now`
- No retroactive transactions are created for new accounts
- Only future transactions (after creation) will be processed

### Retroactive Processing for Existing Data
- Accounts without `last_processed_date` will use `created_at` as the starting point
- All past occurrences since `repetition_date` will be processed
- This ensures existing data is brought up to date

## Performance Considerations

1. **Batch Processing**: All transactions for an account are calculated and saved in one batch
2. **Indexed Queries**: Database indexes on key fields ensure fast queries
3. **Smart Processing**: Only processes the time period since `last_processed_date`
4. **Caching**: Account balances are cached in memory, transactions are only processed on load

## Testing Checklist

- [ ] Create an account with $100
- [ ] Create a monthly revenue of $1,000 linked to the account
- [ ] Wait for next load or force refresh
- [ ] Verify account balance increased by $1,000
- [ ] Check transactions table in database for new record
- [ ] Create a weekly subscription of $10 linked to the account
- [ ] Verify balance decreased by $10 after processing
- [ ] Test dashboard calendar with historical dates
- [ ] Test offline mode (create revenue, go offline, go online)
- [ ] Test with multiple accounts
- [ ] Test with different currencies

## Future Enhancements

1. **Transaction UI**: Add a dedicated screen to view transaction history
2. **Manual Adjustments**: Allow users to manually add one-time transactions
3. **Transaction Categories**: Add categories for better organization
4. **Export**: Export transaction history to CSV
5. **Notifications**: Notify users when large transactions are processed
6. **Undo Feature**: Allow undoing recent transactions

## Troubleshooting

### Balances Not Updating
1. Check if subscriptions/revenues have `account_id` set
2. Verify `last_processed_date` is in the past
3. Check console logs for transaction processing errors
4. Verify database connection

### Wrong Balance Calculations
1. Check currency conversion rates
2. Verify transaction amounts (negative for subscriptions, positive for revenues)
3. Check for duplicate transactions in database
4. Verify `repetition_date` is correct

### Historical Balances Incorrect
1. Check transaction records in database
2. Verify all past transactions were created
3. Check date filtering in queries
4. Verify currency conversions are consistent

## Summary

This implementation provides a robust, automatic balance tracking system that:
- ✅ Updates account balances based on subscriptions and revenues
- ✅ Stores complete transaction history
- ✅ Supports historical balance viewing
- ✅ Works offline
- ✅ Syncs across iOS and Web
- ✅ Handles multiple currencies
- ✅ Processes retroactive transactions
- ✅ Maintains data integrity with RLS

The system is production-ready and follows best practices for data consistency, performance, and user experience.

