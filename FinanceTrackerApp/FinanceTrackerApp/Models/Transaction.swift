
import Foundation

enum TransactionType: String, Codable, CaseIterable {
    case revenue
    case subscription
}

struct Transaction: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let accountId: UUID
    var amount: Double
    var currency: String
    var transactionDate: Date
    var transactionType: TransactionType
    var sourceId: UUID
    var sourceName: String
    var description: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case accountId = "account_id"
        case amount
        case currency
        case transactionDate = "transaction_date"
        case transactionType = "transaction_type"
        case sourceId = "source_id"
        case sourceName = "source_name"
        case description
        case createdAt = "created_at"
    }
}

