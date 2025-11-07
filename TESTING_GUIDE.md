# 🧪 Testing Guide - Data Sync & Cache Clear

## ✅ What I Just Fixed

**Problem:** "Clear Cache & Reload" button wasn't working because screens weren't listening to the notifications.

**Solution:** Added notification listeners to all screens:
- ✅ AccountsScreen
- ✅ SubscriptionsScreen  
- ✅ RevenueScreen
- ✅ DashboardScreen (already had it)

Now when you tap "Clear Cache & Reload", all screens automatically refresh!

---

## 🧪 Test Plan - Follow These Steps EXACTLY

### **Step 1: Build & Run**
1. Open Xcode
2. Press **⌘+R** to build and run
3. Wait for app to launch

### **Step 2: Clear Cache**
1. Navigate to **Settings** tab (gear icon)
2. Scroll down to **"Debug Info"** section
3. Tap **"Clear Cache & Reload"** (orange button)
4. **You should see a toast message:** ✅ "Cache cleared! Pull to refresh on each tab."

### **Step 3: Verify Data is Cleared**
1. Go to **Accounts** tab
   - If you see old data, **pull down to refresh**
   - Old data should disappear
   - If you have web data, it should appear after refresh

2. Go to **Subscriptions** tab
   - Pull down to refresh
   - Should show only Supabase data (or empty if none)

3. Go to **Revenue** tab
   - Pull down to refresh
   - Should show only Supabase data (or empty if none)

4. Go to **Dashboard** tab
   - Should automatically update
   - Should show Supabase data

### **Step 4: Test Web → iOS Sync**
1. **On Web:** Open [https://total-balance-tracker-3.vercel.app](https://total-balance-tracker-3.vercel.app)
2. **Sign in** with your Google account (same one as iOS)
3. **Create a test account:** "Web Test" $100 USD
4. **On iOS:** 
   - Go to Accounts tab
   - **Pull down to refresh**
   - **Should see "Web Test"** ✅

### **Step 5: Test iOS → Web Sync**
1. **On iOS:** Create subscription "Test Sub" $10 Monthly
2. **On Web:** 
   - Refresh the page
   - Go to Subscriptions
   - **Should see "Test Sub"** ✅

---

## 🔍 What to Look For

### **Success Indicators:**

✅ **Toast notification appears** when you tap "Clear Cache & Reload"

✅ **Old local data disappears** after clearing cache and refreshing

✅ **Web data appears on iOS** after pull-to-refresh

✅ **iOS data appears on web** after page refresh

✅ **Updates sync** between platforms in real-time

### **Common Issues:**

❌ **Still seeing old data:**
- Solution: Pull down to refresh on EACH tab
- Or: Sign out and sign back in

❌ **Not seeing web data:**
- Check: Are you signed in with the SAME Google account?
- Check: Did you run `database_setup.sql` in Supabase?
- Check: Settings → Email should match on both platforms

❌ **Button doesn't show toast:**
- Rebuild the app (⌘+R)
- Make sure ToastManager is injected

---

## 📊 Debug Console Output

When you tap "Clear Cache & Reload", check Xcode console for:

```
🗑️ Manually clearing all cached data
✅ Cache cleared - app will reload data
```

When screens reload, you should see:
```
[AccountsScreen] Loading from Supabase
[SubscriptionsScreen] Loading from Supabase
[RevenueScreen] Loading from Supabase
```

---

## 🛠️ Manual Testing Checklist

After building the app:

- [ ] App launches successfully
- [ ] Sign in with Google works
- [ ] Settings shows your real name and email
- [ ] Tap "Clear Cache & Reload" shows toast
- [ ] Pull to refresh on Accounts loads Supabase data
- [ ] Pull to refresh on Subscriptions loads Supabase data
- [ ] Pull to refresh on Revenue loads Supabase data
- [ ] Dashboard automatically updates
- [ ] Create account on web → appears on iOS after refresh
- [ ] Create subscription on iOS → appears on web after refresh
- [ ] Update data on one platform → changes on other
- [ ] Delete data on one platform → deleted on other

---

## 🚨 If Something Doesn't Work

### **1. Check Authentication**
```
Settings → Debug Info
- User ID should show (not "Not available")
- Authenticated should show "Yes" (green)
```

### **2. Check Console for Errors**
Look in Xcode console for:
- Authentication errors
- Network errors
- Supabase API errors

### **3. Verify RLS Policies**
```sql
-- Run this in Supabase SQL Editor to check:
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('finance_items', 'subscription_items', 'revenue_items');

-- All should show rowsecurity = true
```

### **4. Nuclear Option - Complete Reset**
```
1. Settings → Sign Out
2. Settings → Clear Cache & Reload
3. Close and reopen app
4. Sign in with Google
5. Pull to refresh on all tabs
```

---

## 📝 Expected Behavior After Fix

### **Before (BUG):**
- ❌ Tap "Clear Cache & Reload" → Nothing happens
- ❌ Screens don't refresh
- ❌ Old data still shows

### **After (FIXED):**
- ✅ Tap "Clear Cache & Reload" → Toast appears
- ✅ Screens listen to notifications
- ✅ Pull to refresh loads Supabase data
- ✅ Old data is cleared
- ✅ Web ↔ iOS sync works

---

## 🎯 Critical Test Cases

### **Test Case 1: Clear Cache Works**
1. Tap "Clear Cache & Reload"
2. **Expected:** Toast message appears
3. **Expected:** All tabs reload when visited

### **Test Case 2: Web → iOS Sync**
1. Create data on web
2. Pull to refresh on iOS
3. **Expected:** Data appears immediately

### **Test Case 3: iOS → Web Sync**
1. Create data on iOS
2. Refresh web page
3. **Expected:** Data appears immediately

### **Test Case 4: Authentication State**
1. Sign out
2. Data should clear (or show local data)
3. Sign in
4. Pull to refresh
5. **Expected:** Supabase data loads

---

## 💡 Tips for Testing

1. **Always pull to refresh** after clearing cache - automatic refresh may not trigger on inactive tabs

2. **Check both platforms** - Create test data on web, verify on iOS and vice versa

3. **Use unique names** - Name test items like "iOS Test 1", "Web Test 2" so you know where they came from

4. **Watch the console** - Xcode console shows what's happening behind the scenes

5. **Test in order** - Follow the steps above in sequence for best results

---

## ✨ Success Criteria

Your setup is working correctly when:

✅ Clear cache button shows toast notification

✅ Old local data disappears after cache clear + refresh

✅ Data created on web appears on iOS within seconds

✅ Data created on iOS appears on web within seconds

✅ Updates on one platform instantly sync to the other

✅ Deletes on one platform instantly sync to the other

✅ Same data shows on both platforms when signed in with same account

---

**If all test cases pass, congratulations! Your iOS and web apps are fully synced! 🎉**

