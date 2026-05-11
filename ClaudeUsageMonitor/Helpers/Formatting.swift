import Foundation

enum Formatting {
    private nonisolated(unsafe) static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.unitsStyle = .short
        return f
    }()

    static func relativeDate(_ date: Date) -> String {
        relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    static func timeRemaining(until date: Date) -> String {
        let now = Date()
        let seconds = max(0, date.timeIntervalSince(now))
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        } else if m > 0 {
            return "\(m)m"
        } else {
            return "<1m"
        }
    }

    static func copyableText(from data: RateLimitData) -> String {
        var lines: [String] = []

        lines.append("Current session")
        lines.append("  \(Int(data.fiveHourPercentage))% used")
        lines.append("  Resets \(formatReset(data.fiveHourReset))")

        if let weeklyPct = data.sevenDayPercentage, let weeklyReset = data.sevenDayReset {
            lines.append("")
            lines.append("Current week (all models)")
            lines.append("  \(Int(weeklyPct))% used")
            lines.append("  Resets \(formatReset(weeklyReset))")
        }

        return lines.joined(separator: "\n")
    }

    static func daysFormatted(_ days: Double) -> String {
        if days < 0.1 { return "<0.1" }
        return String(format: "%.1f", days)
    }

    static func shortItalianDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEE d MMM, HH:mm"
        return formatter.string(from: date)
    }

    static func italianDayAndTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEEE 'alle' HH:mm"
        return formatter.string(from: date)
    }

    private static func formatReset(_ date: Date) -> String {
        let tz = TimeZone.current
        let tzName = tz.identifier

        let now = Date()
        let hoursUntil = date.timeIntervalSince(now) / 3600

        let formatter = DateFormatter()
        formatter.timeZone = tz

        if hoursUntil <= 24 {
            formatter.dateFormat = "h:mma"
        } else {
            formatter.dateFormat = "MMM d 'at' ha"
        }

        let timeStr = formatter.string(from: date).lowercased()
        return "\(timeStr) (\(tzName))"
    }
}
