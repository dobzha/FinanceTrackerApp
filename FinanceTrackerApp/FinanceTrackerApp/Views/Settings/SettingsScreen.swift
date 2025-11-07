
import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var toast: ToastManager
    @State private var showSignOutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // User Profile Section
                Section {
                    if auth.isAuthenticated, let user = auth.currentUser {
                        HStack(spacing: 16) {
                            // User Avatar
                            if let avatarURL = user.userMetadata["avatar_url"]?.value as? String,
                               let url = URL(string: avatarURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.blue)
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                // User Name
                                if let name = user.userMetadata["full_name"]?.value as? String {
                                    Text(name)
                                        .font(.headline)
                                } else if let name = user.userMetadata["name"]?.value as? String {
                                    Text(name)
                                        .font(.headline)
                                } else {
                                    Text("User")
                                        .font(.headline)
                                }
                                
                                // User Email
                                if let email = user.email {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Sign-in provider
                                Text("Signed in with Google")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        // Not signed in
                        HStack(spacing: 16) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Not Signed In")
                                    .font(.headline)
                                Text("Sign in to sync your data")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Account Actions
                Section("Account") {
                    if auth.isAuthenticated {
                        Button(action: {
                            showSignOutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                    .foregroundColor(.red)
                                Text("Sign Out")
                                    .foregroundColor(.red)
                            }
                        }
                        .disabled(auth.isLoading)
                    } else {
                        Button(action: {
                            Task {
                                await auth.signInWithGoogle()
                            }
                        }) {
                            HStack {
                                Image(systemName: "g.circle")
                                    .foregroundColor(.blue)
                                Text(auth.isLoading ? "Signing in..." : "Sign in with Google")
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(auth.isLoading)
                    }
                }
                
                // App Information
                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Bundle ID")
                        Spacer()
                        Text("com.financetracker.app")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                // Support
                Section("Support") {
                    Link(destination: URL(string: "mailto:support@financetracker.com")!) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                            Text("Contact Support")
                        }
                    }
                    
                    Link(destination: URL(string: "https://financetracker.com/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(.blue)
                            Text("Privacy Policy")
                        }
                    }
                }
                
                // Debug Info (only in debug builds)
                #if DEBUG
                Section("Debug Info") {
                    HStack {
                        Text("User ID")
                        Spacer()
                        if let userID = auth.currentUser?.id.uuidString {
                            Text(userID.prefix(12) + "...")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .textSelection(.enabled)
                        } else {
                            Text("Not available")
                                .foregroundColor(.red)
                        }
                    }
                    
                    HStack {
                        Text("Authenticated")
                        Spacer()
                        Text(auth.isAuthenticated ? "Yes ✅" : "No ❌")
                            .foregroundColor(auth.isAuthenticated ? .green : .red)
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text("Email")
                        Spacer()
                        if let email = auth.currentUser?.email {
                            Text(email)
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .textSelection(.enabled)
                        } else {
                            Text("Not available")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await auth.clearCacheAndReload()
                            toast.show("✅ Cache cleared! Pull to refresh on each tab.")
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash.circle")
                                .foregroundColor(.orange)
                            Text("Clear Cache & Reload")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Button(action: {
                        Task {
                            toast.show("🔄 Force reloading authentication...")
                            await auth.refreshSession()
                            if auth.isAuthenticated {
                                toast.show("✅ Auth refreshed successfully")
                            } else {
                                toast.show("❌ Not authenticated - please sign in")
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle")
                                .foregroundColor(.blue)
                            Text("Refresh Authentication")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section("Troubleshooting") {
                    Text("If you see errors:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("1. Check 'Authenticated' shows Yes ✅")
                        .font(.caption)
                    Text("2. Run database_setup.sql in Supabase")
                        .font(.caption)
                    Text("3. Tap 'Clear Cache & Reload'")
                        .font(.caption)
                    Text("4. Pull to refresh on each tab")
                        .font(.caption)
                }
                #endif
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await auth.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

#Preview {
    SettingsScreen()
        .environmentObject(AuthViewModel.shared)
}

