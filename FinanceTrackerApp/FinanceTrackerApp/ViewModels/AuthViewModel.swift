
import Foundation
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentUser: User? = nil

    private var authListenerToken: UUID?

    init() {
        authListenerToken = SupabaseService.shared.observeAuthState { [weak self] _, session in
            Task { @MainActor in
                self?.currentUser = session?.user
                self?.isAuthenticated = (session?.user != nil)
            }
        }
        Task { [weak self] in
            try? await self?.refreshSession()
        }
    }

    deinit {
        if let token = authListenerToken {
            SupabaseService.shared.removeAuthObserver(token)
        }
    }

    func refreshSession() async throws {
        do {
            let user = try await SupabaseService.shared.getCurrentUser()
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = (user != nil)
            }
        } catch {
            await MainActor.run {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }
    }

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        do {
            try await SupabaseService.shared.signInWithGoogle()
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
