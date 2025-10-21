
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
            
            // If user just became authenticated, sync local data
            if !wasAuthenticated && self.isAuthenticated {
                await syncLocalDataToCloud()
            }
        } catch {
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }
    
    private func syncLocalDataToCloud() async {
        let success = await LocalStorageService.shared.syncLocalDataToCloud()
        if success {
            print("Successfully synced local data to cloud")
            // Post notification to refresh all views
            NotificationCenter.default.post(name: .init("AccountUpdated"), object: nil)
        } else {
            print("Failed to sync local data to cloud")
        }
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
}
