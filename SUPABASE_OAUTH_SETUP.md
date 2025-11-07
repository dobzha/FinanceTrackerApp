# 🔐 Supabase OAuth Setup Guide for iOS App

## ✅ What's Already Done

Your iOS app is now configured with:
- ✅ Google OAuth Client ID for iOS
- ✅ Reversed Client ID URL scheme in Info.plist
- ✅ Supabase redirect URL scheme (`financetracker://auth-callback`)
- ✅ All configuration constants in Config.swift

---

## 🔧 Required Configuration Steps

### **1. Supabase Dashboard Configuration**

Go to: [Supabase Dashboard](https://supabase.com/dashboard) → Your Project → Authentication → URL Configuration

#### **Redirect URLs**
Make sure these URLs are listed:

```
financetracker://auth-callback
https://total-balance-tracker-3.vercel.app/auth/callback
```

Both URLs can coexist! The iOS app will use the first one, and the web app will use the second.

#### **Site URL**
Keep your existing:
```
https://total-balance-tracker-3.vercel.app
```

---

### **2. Google Cloud Console Configuration**

Go to: [Google Cloud Console](https://console.cloud.google.com/apis/credentials)

#### **iOS OAuth 2.0 Client ID**
You've already created this! ✅

**Client ID:** `814400290575-jhrhi3p719dp3mvibl3amnkfbo809ddp.apps.googleusercontent.com`

**Bundle ID:** `com.financetracker.app`

#### **Authorized Redirect URIs**
Make sure your OAuth client has this redirect URI:

```
https://dslaholfbjctbzkgprio.supabase.co/auth/v1/callback
```

This is the Supabase Auth callback URL that works for both web and iOS!

#### **Authorized JavaScript Origins** (for Web)
Keep your existing:
```
https://total-balance-tracker-3.vercel.app
```

---

## 🎯 How Authentication Works

### **iOS App Flow:**
1. User taps "Sign in with Google"
2. App opens Safari/browser with Google OAuth page
3. User authenticates with Google
4. Google redirects to: `https://dslaholfbjctbzkgprio.supabase.co/auth/v1/callback`
5. Supabase processes the authentication
6. Supabase redirects to: `financetracker://auth-callback?access_token=...`
7. iOS opens your app via the URL scheme
8. App handles the callback and creates a session

### **Web App Flow:**
1. User clicks "Sign in with Google"
2. User authenticates with Google
3. Google redirects to: `https://dslaholfbjctbzkgprio.supabase.co/auth/v1/callback`
4. Supabase processes the authentication
5. Supabase redirects to: `https://total-balance-tracker-3.vercel.app/auth/callback`
6. Web app handles the callback

---

## 🔍 Troubleshooting Checklist

If authentication doesn't work:

### **iOS App Issues:**

- [ ] Bundle ID in Xcode matches: `com.financetracker.app`
- [ ] Info.plist has both URL schemes:
  - `financetracker`
  - `com.googleusercontent.apps.814400290575-jhrhi3p719dp3mvibl3amnkfbo809ddp`
- [ ] Supabase redirect URLs include: `financetracker://auth-callback`
- [ ] Google OAuth Client for iOS is properly configured
- [ ] Testing on a real device (not just simulator for best results)

### **Supabase Issues:**

- [ ] Google provider is enabled in Supabase Auth settings
- [ ] Correct Google Client ID and Secret are set in Supabase
- [ ] Redirect URLs are properly configured
- [ ] RLS (Row Level Security) policies are set on database tables

### **Google Cloud Issues:**

- [ ] OAuth consent screen is published (or in testing mode with your email added)
- [ ] iOS bundle ID matches exactly: `com.financetracker.app`
- [ ] Authorized redirect URIs include the Supabase callback

---

## 🗄️ Database Configuration (Important!)

Make sure your Supabase tables have Row Level Security (RLS) policies:

### **Example RLS Policy for `finance_items` table:**

```sql
-- Enable RLS
ALTER TABLE finance_items ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own data
CREATE POLICY "Users can view own finance items"
ON finance_items
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can insert their own data
CREATE POLICY "Users can insert own finance items"
ON finance_items
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own data
CREATE POLICY "Users can update own finance items"
ON finance_items
FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Users can delete their own data
CREATE POLICY "Users can delete own finance items"
ON finance_items
FOR DELETE
USING (auth.uid() = user_id);
```

**Apply similar policies to:**
- `subscription_items`
- `revenue_items`

This ensures users only see their own data when signed in with the same Google account on both web and iOS!

---

## 📱 Testing the Setup

1. **Build and run the app** in Xcode
2. **Tap "Sign in with Google"**
3. **Authenticate** with your Google account
4. App should redirect back and show authenticated state
5. **Create a test account** on iOS
6. **Open your web app** and sign in with the same Google account
7. **Verify** the data appears on both platforms!

---

## 🎉 Data Syncing Between Web & iOS

Once authenticated with the same Google account:

- ✅ Same `user_id` in Supabase Auth
- ✅ Same database tables accessed
- ✅ RLS policies filter by `user_id`
- ✅ Data automatically syncs between platforms!

No additional configuration needed for data syncing - it's automatic! 🚀

---

## 📞 Need Help?

If you encounter issues:

1. Check Xcode console for error messages
2. Check Supabase logs in dashboard
3. Verify all URLs and IDs match exactly
4. Test on a physical iOS device (recommended)
5. Make sure you're using the same Google account on both platforms

---

## 🔑 Your Configuration Summary

**Bundle ID:** `com.financetracker.app`

**Google iOS Client ID:** `814400290575-jhrhi3p719dp3mvibl3amnkfbo809ddp.apps.googleusercontent.com`

**Reversed Client ID:** `com.googleusercontent.apps.814400290575-jhrhi3p719dp3mvibl3amnkfbo809ddp`

**Supabase URL:** `https://dslaholfbjctbzkgprio.supabase.co`

**iOS Redirect URL:** `financetracker://auth-callback`

**Web Redirect URL:** `https://total-balance-tracker-3.vercel.app/auth/callback`

---

Good luck! 🎉

