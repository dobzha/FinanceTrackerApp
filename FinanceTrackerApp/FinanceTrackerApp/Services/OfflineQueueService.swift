
import Foundation
import UIKit

enum OperationType: String, Codable { case create, update, delete }

enum QueueTable: String, Codable { case finance = "finance_items", subscription = "subscription_items", revenue = "revenue_items" }

struct QueuedOperation: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let type: OperationType
    let table: QueueTable
    let payload: Data // JSON-encoded model for create/update
}

final class OfflineQueueService: ObservableObject {
    static let shared = OfflineQueueService()
    private init() { loadFromStorage() }

    @Published private(set) var queue: [QueuedOperation] = []
    private let storageKey = "offline_queue_storage_v1"

    func startAutoSyncObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        // Kick an initial sync attempt if online
        Task { await processQueueIfOnline() }
    }

    @objc private func appWillEnterForeground() {
        Task { await processQueueIfOnline() }
    }

    func enqueueCreate(_ item: FinanceItem) {
        enqueue(table: .finance, model: item, type: .create)
    }
    func enqueueUpdate(_ item: FinanceItem) {
        enqueue(table: .finance, model: item, type: .update)
    }
    func enqueueDeleteFinance(_ item: FinanceItem) {
        // Represent delete by sending just the id in a tiny struct
        let minimal = ["id": item.id.uuidString]
        enqueue(table: .finance, encodable: minimal, type: .delete)
    }

    func enqueueDeleteFinance(id: UUID) { let minimal = ["id": id.uuidString]; enqueue(table: .finance, encodable: minimal, type: .delete) }


    func enqueueCreate(_ item: SubscriptionItem) { enqueue(table: .subscription, model: item, type: .create) }
    func enqueueUpdate(_ item: SubscriptionItem) { enqueue(table: .subscription, model: item, type: .update) }
    func enqueueDeleteSubscription(_ item: SubscriptionItem) { let minimal = ["id": item.id.uuidString]; enqueue(table: .subscription, encodable: minimal, type: .delete) }

    func enqueueDeleteSubscription(id: UUID) { let minimal = ["id": id.uuidString]; enqueue(table: .subscription, encodable: minimal, type: .delete) }

    func enqueueCreate(_ item: RevenueItem) { enqueue(table: .revenue, model: item, type: .create) }
    func enqueueUpdate(_ item: RevenueItem) { enqueue(table: .revenue, model: item, type: .update) }
    func enqueueDeleteRevenue(_ item: RevenueItem) { let minimal = ["id": item.id.uuidString]; enqueue(table: .revenue, encodable: minimal, type: .delete) }

    func enqueueDeleteRevenue(id: UUID) { let minimal = ["id": id.uuidString]; enqueue(table: .revenue, encodable: minimal, type: .delete) }

    private func enqueue<T: Encodable>(table: QueueTable, model: T, type: OperationType) {
        enqueue(table: table, encodable: model, type: type)
    }

    private func enqueue(table: QueueTable, encodable: Encodable, type: OperationType) {
        guard let data = try? JSONEncoder().encode(AnyEncodable(encodable)) else { return }
        var newQueue = queue
        let op = QueuedOperation(id: UUID(), timestamp: Date(), type: type, table: table, payload: data)
        newQueue.append(op)
        newQueue = resolveConflicts(newQueue)
        queue = newQueue
        saveToStorage()
    }

    private func resolveConflicts(_ list: [QueuedOperation]) -> [QueuedOperation] {
        // Rules:
        // - Add then Delete same item => remove both
        // - Multiple Updates same item => keep latest
        // We'll detect by id inside payload where available
        var result: [QueuedOperation] = []
        var latestByKey: [String: QueuedOperation] = [:]

        func keyFor(_ op: QueuedOperation) -> String? {
            if let dict = try? JSONSerialization.jsonObject(with: op.payload) as? [String: Any], let idStr = dict["id"] as? String {
                return op.table.rawValue + ":" + idStr
            }
            return nil
        }

        for op in list {
            if let key = keyFor(op) {
                if op.type == .delete, let existing = latestByKey[key] {
                    // remove existing and skip delete
                    latestByKey[key] = nil
                    continue
                }
                latestByKey[key] = op
            } else {
                result.append(op)
            }
        }
        result.append(contentsOf: latestByKey.values)
        // Keep order by timestamp
        return result.sorted { $0.timestamp < $1.timestamp }
    }

    private func saveToStorage() {
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey), let saved = try? JSONDecoder().decode([QueuedOperation].self, from: data) else { return }
        queue = saved
    }

    func clear() { queue = []; saveToStorage() }

    func processQueue() async {
        var remaining: [QueuedOperation] = []
        for op in queue {
            let ok = await perform(op)
            if !ok { remaining.append(op) }
        }
        queue = remaining
        saveToStorage()
    }

    private func perform(_ op: QueuedOperation) async -> Bool {
        do {
            switch op.table {
            case .finance:
                if op.type == .delete {
                    let dict = try JSONSerialization.jsonObject(with: op.payload) as? [String: Any]
                    if let idStr = dict?["id"] as? String, let id = UUID(uuidString: idStr) {
                        try await SupabaseService.shared.deleteAccount(id: id)
                    }
                } else {
                    let item = try JSONDecoder().decode(AnyDecodable<FinanceItem>.self, from: op.payload).value
                    if op.type == .create { try await SupabaseService.shared.createAccount(item) } else { try await SupabaseService.shared.updateAccount(item) }
                }
            case .subscription:
                if op.type == .delete {
                    let dict = try JSONSerialization.jsonObject(with: op.payload) as? [String: Any]
                    if let idStr = dict?["id"] as? String, let id = UUID(uuidString: idStr) {
                        try await SupabaseService.shared.deleteSubscription(id: id)
                    }
                } else {
                    let item = try JSONDecoder().decode(AnyDecodable<SubscriptionItem>.self, from: op.payload).value
                    if op.type == .create { try await SupabaseService.shared.createSubscription(item) } else { try await SupabaseService.shared.updateSubscription(item) }
                }
            case .revenue:
                if op.type == .delete {
                    let dict = try JSONSerialization.jsonObject(with: op.payload) as? [String: Any]
                    if let idStr = dict?["id"] as? String, let id = UUID(uuidString: idStr) {
                        try await SupabaseService.shared.deleteRevenue(id: id)
                    }
                } else {
                    let item = try JSONDecoder().decode(AnyDecodable<RevenueItem>.self, from: op.payload).value
                    if op.type == .create { try await SupabaseService.shared.createRevenue(item) } else { try await SupabaseService.shared.updateRevenue(item) }
                }
            }
            return true
        } catch {
            return false
        }
    }

    @MainActor
    func processQueueIfOnline() async {
        if NetworkStatus.shared.isOnline { await processQueue() }
    }
}

// Helpers to encode/decode unknown Encodable/Decodable types
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ value: Encodable) { self._encode = value.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}

struct AnyDecodable<T: Decodable>: Decodable {
    let value: T
}
