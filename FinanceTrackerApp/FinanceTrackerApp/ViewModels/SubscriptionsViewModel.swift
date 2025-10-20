
import Foundation

@MainActor
final class SubscriptionsViewModel: ObservableObject {
    @Published var subscriptions: [SubscriptionItem] = []
    @Published var accounts: [FinanceItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let subsTask = SupabaseService.shared.fetchSubscriptions()
            async let accTask = SupabaseService.shared.fetchAccounts()
            let (subs, accs) = try await (subsTask, accTask)
            subscriptions = subs
            accounts = accs
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    func create(name: String, amount: Double, currency: String, period: SubscriptionPeriod, repetitionDate: Date, accountId: UUID?) async -> Bool {
        do {
            let item = SubscriptionItem(id: UUID(), userId: UUID(), name: name, amount: amount, currency: currency, period: period, repetitionDate: repetitionDate, accountId: accountId, createdAt: nil, updatedAt: nil)
            try await SupabaseService.shared.createSubscription(item)
            await load()
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func update(_ item: SubscriptionItem) async -> Bool {
        do {
            try await SupabaseService.shared.updateSubscription(item)
            await load()
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func delete(id: UUID) async -> Bool {
        do {
            try await SupabaseService.shared.deleteSubscription(id: id)
            subscriptions.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }
}
