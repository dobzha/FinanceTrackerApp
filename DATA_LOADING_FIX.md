# Data Loading Error Fix

## Summary
This document outlines the fixes implemented to resolve data loading errors when switching between tabs (Accounts, Subscriptions, and Revenue) in the Finance Tracker app.

## Issues Identified

### 1. Date Decoding Error
**Error Message:**
```
Date decoding error for subscriptions: dataCorrupted
Cannot decode date string: 2025-11-07T11:45:05.053904+00:00
```

**Root Cause:**
Supabase returns timestamps with microseconds (6 digits after decimal: `.053904`), but the standard `DateFormatter` and `ISO8601DateFormatter` can have inconsistent behavior with this format, especially when combined with timezone offsets like `+00:00`.

### 2. Request Cancellation Errors
**Error Messages:**
```
Error fetching revenues: Error Domain=NSURLErrorDomain Code=-999 "cancelled"
Failed to load accounts: cancelled
```

**Root Cause:**
- Multiple simultaneous network requests when switching tabs rapidly
- Previous requests getting cancelled when new ones are initiated
- No task management to prevent overlapping requests
- Parallel requests (`async let`) overwhelming the connection

## Fixes Implemented

### 1. Enhanced Date Decoder (`SupabaseService.swift`)

#### What Changed:
- Improved the `decodeFlexibleDate` function to handle microsecond precision
- Added regex-based preprocessing to convert microseconds (6 digits) to milliseconds (3 digits)
- Enhanced format fallback chain for better compatibility

#### How It Works:
```swift
// Example: Converts "2025-11-07T11:45:05.053904+00:00"
//       To: "2025-11-07T11:45:05.053+00:00"
```

The decoder now:
1. First tries iOS 15+ `ISO8601DateFormatter` with fractional seconds
2. Uses regex to truncate microseconds to milliseconds for better compatibility
3. Falls back to multiple `DateFormatter` patterns if needed

#### Code Location:
- File: `Services/SupabaseService.swift`
- Lines: 29-92

### 2. Consistent Decoder Usage

#### What Changed:
Updated `fetchAccounts()` to use the custom decoder like `fetchSubscriptions()` and `fetchRevenues()`.

#### Before:
```swift
let result: [FinanceItem] = try await client
    .from("finance_items")
    .select()
    .execute()
    .value
```

#### After:
```swift
let response = try await client
    .from("finance_items")
    .select()
    .execute()

let result = try customDecoder.decode([FinanceItem].self, from: response.data)
```

#### Code Location:
- File: `Services/SupabaseService.swift`
- Function: `fetchAccounts()`
- Lines: 135-167

### 3. Task Cancellation Handling (All ViewModels)

#### What Changed:
Added proper task management to prevent overlapping requests and gracefully handle cancellations.

#### Key Features:
1. **Task Storage**: Each ViewModel now has a `loadTask` property
2. **Automatic Cancellation**: Previous tasks are cancelled when new ones start
3. **Cancellation Checks**: Regular checks throughout the loading process
4. **Error Filtering**: Cancelled requests (Code -999) are handled gracefully without showing errors to users
5. **Sequential Loading**: Changed from parallel (`async let`) to sequential fetching to reduce connection strain

#### Implementation Pattern:
```swift
private var loadTask: Task<Void, Never>?

func load() async {
    // Cancel previous task
    loadTask?.cancel()
    
    // Create new task
    loadTask = Task {
        do {
            try Task.checkCancellation()
            // Fetch data
            try Task.checkCancellation()
            // Update UI
        } catch is CancellationError {
            // Silent handling
        } catch {
            // Handle real errors
        }
    }
    
    await loadTask?.value
}
```

#### Files Modified:
1. `ViewModels/AccountsViewModel.swift` (Lines 10, 17-66)
2. `ViewModels/SubscriptionsViewModel.swift` (Lines 11, 17-74)
3. `ViewModels/RevenueViewModel.swift` (Lines 11, 17-74)
4. `ViewModels/DashboardViewModel.swift` (Lines 21, 28-87)

### 4. Error Message Improvements

#### What Changed:
- Cancellation errors are now filtered out and don't show alert dialogs
- User-friendly error messages remain for legitimate errors
- Clear console logging differentiates between cancelled tasks and real errors

#### User Experience:
- **Before**: Alert shows "Failed to load accounts: cancelled"
- **After**: No alert for cancellations; silent retry on next tab switch

## Testing Instructions

### 1. Build and Run
1. Open the project in Xcode
2. Select iPhone simulator (iPhone 17 Pro or similar)
3. Build and run the project (⌘R)

### 2. Test Date Decoding
**Goal**: Verify subscriptions and revenues load without date format errors

**Steps**:
1. Sign in with Google OAuth
2. Navigate to Subscriptions tab
3. Verify existing subscriptions load without errors
4. Create a new subscription
5. Navigate to Revenue tab
6. Verify existing revenues load without errors
7. Create a new revenue item

**Expected Result**:
- No date decoding errors in console
- All items display correctly
- Console shows: `✅ [SupabaseService] Fetched X subscriptions successfully`

### 3. Test Request Cancellation Handling
**Goal**: Verify rapid tab switching doesn't cause errors

**Steps**:
1. Rapidly switch between tabs: Dashboard → Accounts → Subscriptions → Revenue
2. Repeat 5-10 times quickly
3. Check console for errors
4. Verify each tab eventually loads data

**Expected Result**:
- No "cancelled" error alerts to user
- Console may show: `⚠️ [ViewModel] Network request was cancelled` (this is OK)
- Each tab displays correct data when settled
- No UI freezing or crashes

### 4. Test Tab Refresh
**Goal**: Verify pull-to-refresh works correctly

**Steps**:
1. Go to Accounts tab
2. Pull down to refresh
3. Verify accounts reload
4. Repeat for Subscriptions and Revenue tabs

**Expected Result**:
- Loading indicator appears briefly
- Data refreshes successfully
- No error messages

### 5. Test Error Recovery
**Goal**: Verify real errors still show properly

**Steps**:
1. Turn on Airplane Mode
2. Try to refresh any tab
3. Verify error alert appears
4. Tap "Retry"
5. Turn off Airplane Mode
6. Tap "Retry" again

**Expected Result**:
- Initial error alert shows network error
- Retry after reconnection works
- Data loads successfully

### 6. Console Log Verification

**Successful Load Pattern**:
```
🔍 [SupabaseService] Fetching accounts...
✅ [SupabaseService] User authenticated: <UUID>
✅ [SupabaseService] Fetched 2 accounts successfully
📥 [AccountsViewModel] Loading accounts from Supabase...
✅ [AccountsViewModel] Loaded 2 accounts from Supabase
```

**Graceful Cancellation Pattern** (OK):
```
⚠️ [AccountsViewModel] Network request was cancelled
⚠️ [AccountsViewModel] Load task was cancelled
```

**Real Error Pattern** (should trigger alert):
```
❌ [SupabaseService] Error fetching accounts: <actual error>
❌ [AccountsViewModel] Error loading from Supabase: <actual error>
```

## Technical Details

### Date Format Support
The enhanced decoder now supports:
- ISO8601 with microseconds: `2025-11-07T11:45:05.053904+00:00`
- ISO8601 with milliseconds: `2025-11-07T11:45:05.053+00:00`
- ISO8601 standard: `2025-11-07T11:45:05+00:00`
- UTC format: `2025-11-07T11:45:05Z`
- Date only: `2025-11-07`
- Datetime: `2025-11-07 11:45:05`

### Performance Improvements
- **Sequential Loading**: Reduced connection strain by loading data sequentially instead of in parallel
- **Task Management**: Prevents duplicate requests by cancelling previous tasks
- **Smart Caching**: Error state preserved between cancellations to avoid data loss

### Error Codes Handled
- `-999` / `NSURLErrorCancelled`: Network request cancelled (filtered)
- `CancellationError`: Task cancelled by system (filtered)
- All other errors: Displayed to user with retry option

## Rollback Instructions
If issues occur, revert these commits:
```bash
git log --oneline -5  # Find the commit hash
git revert <commit-hash>
```

## Future Improvements
Consider implementing:
1. **Request Caching**: Cache successful responses to show stale data during loading
2. **Optimistic UI Updates**: Update UI immediately, sync in background
3. **Batch Requests**: Combine multiple fetches into single GraphQL query
4. **Connection Pooling**: Reuse HTTP connections for better performance

## Files Modified Summary
1. `Services/SupabaseService.swift` - Enhanced date decoder, consistent decoder usage
2. `ViewModels/AccountsViewModel.swift` - Task cancellation handling
3. `ViewModels/SubscriptionsViewModel.swift` - Task cancellation handling
4. `ViewModels/RevenueViewModel.swift` - Task cancellation handling
5. `ViewModels/DashboardViewModel.swift` - Task cancellation handling

## Verification Checklist
- [ ] No linter errors in modified files
- [ ] Date decoding works for all Supabase date formats
- [ ] Rapid tab switching doesn't show error alerts
- [ ] Real errors still display properly
- [ ] Pull-to-refresh works correctly
- [ ] Offline/online transitions handled gracefully
- [ ] Console logs are clear and informative
- [ ] No crashes or UI freezing
- [ ] All CRUD operations work (Create, Read, Update, Delete)
- [ ] Multi-user scenario tested (if applicable)

---

**Date**: November 9, 2025
**Status**: ✅ Ready for Testing
**Priority**: High - Fixes critical data loading issues

