
import Foundation

struct FinanceItem: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var name: String
    var amount: Double
    var currency: String
    var lastProcessedDate: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case amount
        case currency
        case lastProcessedDate = "last_processed_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
