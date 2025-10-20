
import Foundation

enum RevenuePeriod: String, Codable, CaseIterable {
    case monthly
    case yearly
    case once
}

struct RevenueItem: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var name: String
    var amount: Double
    var currency: String
    var period: RevenuePeriod
    var repetitionDate: Date?
    var accountId: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case amount
        case currency
        case period
        case repetitionDate = "repetition_date"
        case accountId = "account_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
