# 🔄 Database Sync Setup - Connect iOS & Web

## 🎯 What This Does

After following these steps, your iOS app and web app will share the **same database**. When you:
- ✅ Create data on iOS → See it on Web
- ✅ Create data on Web → See it on iOS
- ✅ Update on one platform → Updated on the other
- ✅ Delete on one platform → Deleted on the other

**All automatic!** Just sign in with the same Google account on both platforms.

---

## ✅ What I Fixed in Your iOS Code

### **1. Updated SupabaseService.swift**

**Before:** Fetch queries tried to get ALL data (not filtered by user)
```swift
func fetchAccounts() async throws -> [FinanceItem] {
    try await client.from("finance_items").select().execute().value
}
```

**After:** Fetch queries now filter by the current user's ID
```swift
func fetchAccounts() async throws -> [FinanceItem] {
    guard let user = try? await client.auth.session.user else {
        throw NSError(domain: "SupabaseService", code: 401)
    }
    
    return try await client
        .from("finance_items")
        .select()
        .eq("user_id", value: user.id.uuidString)
        .execute()
        .value
}
```

**Updated for all three tables:**
- ✅ `fetchAccounts()` - Filters by user_id
- ✅ `fetchSubscriptions()` - Filters by user_id
- ✅ `fetchRevenues()` - Filters by user_id

---

## 🗄️ Step 1: Set Up Database Policies (REQUIRED)

Your Supabase database needs **Row Level Security (RLS)** policies to:
1. Ensure users only see their own data
2. Prevent unauthorized access
3. Enable automatic data filtering

### **How to Apply:**

1. **Go to Supabase Dashboard:**
   - Navigate to: [https://supabase.com/dashboard](https://supabase.com/dashboard)
   - Select your project

2. **Open SQL Editor:**
   - Click on **"SQL Editor"** in the left sidebar
   - Click **"New query"**

3. **Copy and Paste:**
   - Open the file: `database_setup.sql` (in your project folder)
   - Copy **ALL** the SQL code
   - Paste it into the Supabase SQL Editor

4. **Run the Script:**
   - Click **"Run"** (or press ⌘+Enter / Ctrl+Enter)
   - Wait for it to complete (should take 1-2 seconds)
   - You should see: ✅ **"Success. No rows returned"**

### **What This Script Does:**

For each table (`finance_items`, `subscription_items`, `revenue_items`):
- ✅ Enables Row Level Security (RLS)
- ✅ Creates SELECT policy (users can only view their own data)
- ✅ Creates INSERT policy (users can only create data with their user_id)
- ✅ Creates UPDATE policy (users can only update their own data)
- ✅ Creates DELETE policy (users can only delete their own data)

---

## 🧪 Step 2: Test Data Sync

### **Test 1: Create on iOS, View on Web**

1. **On iOS:**
   - Open the app
   - Make sure you're **signed in** with your Google account
   - Go to **Accounts** tab
   - Tap **"+" button**
   - Create an account (e.g., "Test Account", $100, USD)
   - Save

2. **On Web:**
   - Open your web app: [https://total-balance-tracker-3.vercel.app](https://total-balance-tracker-3.vercel.app)
   - **Sign in with the SAME Google account**
   - Navigate to Accounts page
   - **You should see the "Test Account"** you just created on iOS! 🎉

### **Test 2: Create on Web, View on iOS**

1. **On Web:**
   - Create a new subscription (e.g., "Netflix", $15.99, Monthly)
   - Save

2. **On iOS:**
   - Go to **Subscriptions** tab
   - **Pull down to refresh**
   - **You should see "Netflix"** appear! 🎉

### **Test 3: Update on One Platform**

1. **On iOS:**
   - Edit "Test Account" → Change amount to $200
   - Save

2. **On Web:**
   - Refresh the page
   - **Amount should now show $200** ✅

---

## 🔍 Troubleshooting

### **Problem: Can't see data from the other platform**

**Possible causes:**

1. **Not signed in with the same Google account**
   - Solution: Make sure you're using the **exact same Google account** on both platforms
   - Check Settings → Should show the same email address

2. **RLS policies not applied**
   - Solution: Go back to Step 1 and run the SQL script
   - Verify: In Supabase Dashboard → Authentication → Policies
   - You should see policies for all three tables

3. **Different user accounts**
   - Solution: Sign out from both platforms and sign in again with the same Google account

4. **Data created before authentication**
   - Solution: Delete old test data and create new data while signed in

### **Problem: "User not authenticated" error**

- Make sure you're signed in (check Settings tab)
- Try signing out and signing back in
- Check that `financetracker://auth-callback` is in Supabase redirect URLs

### **Problem: Can see other users' data (security issue!)**

- This means RLS policies are NOT enabled
- **IMMEDIATELY** run the `database_setup.sql` script
- This is a security risk - other users can see your data!

---

## 🔐 How Data Syncing Works

### **The Flow:**

```
┌─────────────────┐                    ┌─────────────────┐
│   iOS App       │                    │    Web App      │
│                 │                    │                 │
│  User: ABC123   │                    │  User: ABC123   │
└────────┬────────┘                    └────────┬────────┘
         │                                      │
         │  1. Create Account                   │
         │  (user_id: ABC123)                   │
         │                                      │
         ▼                                      │
┌─────────────────────────────────────────────────────────┐
│             SUPABASE DATABASE                            │
│                                                          │
│  finance_items table:                                    │
│  ┌──────────┬─────────┬────────┬────────┐              │
│  │ id       │ user_id │ name   │ amount │              │
│  ├──────────┼─────────┼────────┼────────┤              │
│  │ uuid-1   │ ABC123  │ Test   │ 100    │ ◄── New row │
│  └──────────┴─────────┴────────┴────────┘              │
│                                                          │
│  RLS Policy: WHERE user_id = auth.uid()                 │
└─────────────────────────────────────────────────────────┘
         ▲                                      │
         │                                      │
         │  3. Fetch returns row                │  2. Fetch (user_id: ABC123)
         │     (filtered by user_id)            │
         │                                      ▼
┌────────┴────────┐                    ┌─────────────────┐
│   iOS App       │                    │    Web App      │
│                 │                    │                 │
│  Shows: Test    │                    │  Shows: Test    │
└─────────────────┘                    └─────────────────┘
```

### **Key Points:**

1. **Both apps use the same Supabase database**
2. **All data is tagged with `user_id`**
3. **RLS policies automatically filter by `auth.uid()`**
4. **When you sign in, `auth.uid()` is set to your user ID**
5. **You only see data where `user_id` matches your `auth.uid()`**

---

## 📊 Verify RLS Policies

After running the SQL script, verify it worked:

1. **Go to Supabase Dashboard** → Your Project
2. **Click "Authentication"** in sidebar
3. **Click "Policies"** tab
4. **You should see policies for:**
   - `finance_items` (4 policies: SELECT, INSERT, UPDATE, DELETE)
   - `subscription_items` (4 policies)
   - `revenue_items` (4 policies)

Each policy should show:
- ✅ **Policy name** (e.g., "Users can view own finance items")
- ✅ **Command** (SELECT, INSERT, UPDATE, or DELETE)
- ✅ **Using expression:** `auth.uid() = user_id`

---

## 🎉 Success Checklist

After completing setup, you should be able to:

- [ ] Sign in with Google on iOS
- [ ] Sign in with same Google account on Web
- [ ] Create an account on iOS → See it on Web
- [ ] Create a subscription on Web → See it on iOS
- [ ] Update data on one platform → See changes on the other
- [ ] Delete data on one platform → Deleted on the other
- [ ] Pull to refresh on iOS updates data from server
- [ ] All data is private (you can't see other users' data)

---

## 🚀 What's Enabled Now

### **iOS App:**
- ✅ Fetch queries filter by user_id
- ✅ Real-time data from Supabase
- ✅ Offline support (queues changes when offline)
- ✅ Automatic sync when online

### **Web App:**
- ✅ Same database, same structure
- ✅ RLS policies enforce data privacy
- ✅ Real-time updates

### **Database:**
- ✅ Row Level Security enabled
- ✅ Policies enforce user_id filtering
- ✅ Secure and private per-user data

---

## 📝 Important Notes

1. **Same Google Account Required:**
   - You MUST sign in with the **same Google account** on both platforms
   - Different accounts = Different user_id = Different data

2. **Data Created Before Sign-In:**
   - Data created in "offline mode" (before signing in) won't sync
   - Only data created **after signing in** will be synced

3. **Offline Mode:**
   - iOS app supports offline mode
   - Changes are queued and synced when you're back online

4. **Security:**
   - RLS policies are your security layer
   - Without them, anyone could see anyone's data
   - Always keep RLS enabled in production!

---

## 🔧 Files Changed

1. **SupabaseService.swift**
   - Updated `fetchAccounts()` to filter by user_id
   - Updated `fetchSubscriptions()` to filter by user_id
   - Updated `fetchRevenues()` to filter by user_id

2. **database_setup.sql** (NEW)
   - SQL script to enable RLS and create policies
   - Run this in Supabase SQL Editor

---

## 🎯 Next Steps

1. **Run the SQL script** in Supabase (Step 1 above)
2. **Build and run** the iOS app (⌘+R in Xcode)
3. **Test data sync** (Step 2 above)
4. **Verify** data appears on both platforms
5. **Celebrate!** 🎉 Your apps are now synced!

---

**Need help?** Check the troubleshooting section above or review the SQL script for details on what's being set up.

Good luck! 🚀

