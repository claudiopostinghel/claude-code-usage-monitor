import Foundation

struct RateLimitData: Sendable, Codable {
    let fiveHourUtilization: Double
    let fiveHourReset: Date
    let sevenDayUtilization: Double?
    let sevenDayReset: Date?
    let fetchedAt: Date

    var fiveHourPercentage: Double { fiveHourUtilization * 100 }
    var sevenDayPercentage: Double? {
        guard let util = sevenDayUtilization else { return nil }
        return util * 100
    }

    var sevenDayWindowStart: Date? {
        guard let reset = sevenDayReset else { return nil }
        return reset.addingTimeInterval(-7 * 24 * 3600)
    }
}
