import Foundation

struct HistoryEntry: Codable, Sendable, Identifiable {
    let id: UUID
    let data: RateLimitData

    var date: Date { data.fetchedAt }

    init(data: RateLimitData) {
        self.id = UUID()
        self.data = data
    }
}
