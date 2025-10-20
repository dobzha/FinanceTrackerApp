
import Foundation

@MainActor
final class RevenueViewModel: ObservableObject {
    @Published var revenues: [RevenueItem] = []
    @Published var accounts: [FinanceItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let revTask = SupabaseService.shared.fetchRevenues()
            async let accTask = SupabaseService.shared.fetchAccounts()
            let (revs, accs) = try await (revTask, accTask)
            revenues = revs
            accounts = accs
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    func create(name: String, amount: Double, currency: String, period: RevenuePeriod, repetitionDate: Date?, accountId: UUID?) async -> Bool {
        do {
            let item = RevenueItem(id: UUID(), userId: UUID(), name: name, amount: amount, currency: currency, period: period, repetitionDate: repetitionDate, accountId: accountId, createdAt: nil, updatedAt: nil)
            try await SupabaseService.shared.createRevenue(item)
            await load()
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func update(_ item: RevenueItem) async -> Bool {
        do {
            try await SupabaseService.shared.updateRevenue(item)
            await load()
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }

    func delete(id: UUID) async -> Bool {
        do {
            try await SupabaseService.shared.deleteRevenue(id: id)
            revenues.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = (error as NSError).localizedDescription
            return false
        }
    }
}
