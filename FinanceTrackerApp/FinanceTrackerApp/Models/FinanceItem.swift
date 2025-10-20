
import Foundation

struct FinanceItem: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var name: String
    var amount: Double
    var currency: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case amount
        case currency
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
