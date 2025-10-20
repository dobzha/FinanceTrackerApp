
import Foundation

@MainActor
final class AccountsViewModel: ObservableObject {
    @Published var accounts: [FinanceItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func loadAccounts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            accounts = try await SupabaseService.shared.fetchAccounts()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    func createAccount(name: String, amount: Double, currency: String) async -> Bool {
        do {
            let item = FinanceItem(
                id: UUID(),
                userId: UUID(), // Supabase fills user_id via RLS insert check; value here is ignored if using RPC, but kept for Codable shape
                name: name,
                amount: amount,
                currency: currency,
                createdAt: nil,
                updatedAt: nil
            )
            try await SupabaseService.shared.createAccount(item)
            await loadAccounts()
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func updateAccount(_ account: FinanceItem) async -> Bool {
        do {
            try await SupabaseService.shared.updateAccount(account)
            await loadAccounts()
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func deleteAccount(_ account: FinanceItem) async -> Bool {
        do {
            try await SupabaseService.shared.deleteAccount(id: account.id)
            accounts.removeAll { $0.id == account.id }
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func linkedCounts(for accountId: UUID) async -> (subscriptions: Int, revenues: Int) {
        do {
            let subs = try await SupabaseService.shared.fetchSubscriptions().filter { $0.accountId == accountId }
            let revs = try await SupabaseService.shared.fetchRevenues().filter { $0.accountId == accountId }
            return (subs.count, revs.count)
        } catch {
            return (0, 0)
        }
    }
}
