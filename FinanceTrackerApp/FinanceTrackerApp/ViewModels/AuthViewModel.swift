
import Foundation
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    static let shared = AuthViewModel()
    
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentUser: User? = nil

    private init() {
        Task { [weak self] in
            await self?.refreshSession()
        }
    }

    func refreshSession() async {
        do {
            let user = try? await SupabaseService.shared.getCurrentUser()
            let wasAuthenticated = self.isAuthenticated
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = (user != nil)
            }
            
            // If user just became authenticated, clear local data and load from Supabase
            if !wasAuthenticated && self.isAuthenticated {
                await clearLocalDataAndRefresh()
            }
            
            // If user just signed out, we can keep local storage for offline use
            if wasAuthenticated && !self.isAuthenticated {
                // Optionally clear data on sign out (currently keeping it for offline mode)
                // LocalStorageService.shared.clearAllData()
            }
        } catch {
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }
    
    private func clearLocalDataAndRefresh() async {
        print("🔄 User authenticated - clearing local storage and loading from Supabase")
        
        // Clear all local cached data (old data created before sign-in)
        LocalStorageService.shared.clearAllData()
        
        // Post notifications to force all ViewModels to refresh from Supabase
        await MainActor.run {
            NotificationCenter.default.post(name: .init("AccountUpdated"), object: nil)
            NotificationCenter.default.post(name: .init("DataRefreshNeeded"), object: nil)
        }
        
        print("✅ Local storage cleared - app will now show Supabase data")
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            try await SupabaseService.shared.signInWithGoogle()
            await refreshSession() // Refresh session after sign in to sync data
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isLoading = false
    }

    func signOut() async {
        isLoading = true
        errorMessage = nil
        do {
            try await SupabaseService.shared.signOut()
            await refreshSession()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Manual Data Refresh
    
    /// Force clear all local cached data and reload from Supabase
    /// Useful for troubleshooting or if old local data is showing
    func clearCacheAndReload() async {
        print("🗑️ Manually clearing all cached data")
        LocalStorageService.shared.clearAllData()
        
        // Post notifications to force all ViewModels to refresh
        await MainActor.run {
            NotificationCenter.default.post(name: .init("AccountUpdated"), object: nil)
            NotificationCenter.default.post(name: .init("DataRefreshNeeded"), object: nil)
        }
        
        print("✅ Cache cleared - app will reload data")
    }
}
