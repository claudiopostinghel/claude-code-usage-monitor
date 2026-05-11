import Foundation

struct ChartPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let percentage: Double
}

struct ChartSegment: Identifiable, Sendable {
    let id = UUID()
    let points: [ChartPoint]
    let isDashed: Bool
}

struct WeeklyProjection: Sendable {
    let windowStart: Date
    let windowEnd: Date
    let timeElapsedFraction: Double
    let currentUtilization: Double
    let projectedExhaustionDate: Date?
    let daysUntilExhaustion: Double?
    let daysWithoutQuota: Double?
    let isOverConsuming: Bool
    let chartSegments: [ChartSegment]
    let projectionPoints: [ChartPoint]

    private static let gapThreshold: TimeInterval = 900 // 15 min

    static func compute(
        from data: RateLimitData,
        entries: [HistoryEntry],
        disabledWeekdays: Set<Int> = []
    ) -> WeeklyProjection? {
        guard let windowEnd = data.sevenDayReset,
              let windowStart = data.sevenDayWindowStart,
              let utilization = data.sevenDayUtilization else {
            return nil
        }

        let now = Date()
        let totalDuration = windowEnd.timeIntervalSince(windowStart)
        guard totalDuration > 0 else { return nil }

        let elapsed = now.timeIntervalSince(windowStart)
        let timeElapsedFraction = max(0, min(1, elapsed / totalDuration))

        // Projection
        var projectedExhaustionDate: Date?
        var daysUntilExhaustion: Double?
        var daysWithoutQuota: Double?
        var isOverConsuming = false

        let activeElapsed = activeSeconds(from: windowStart, to: now, disabledWeekdays: disabledWeekdays)

        if activeElapsed > 0 && utilization > 0 {
            let activeRatePerSecond = utilization / activeElapsed
            let remaining = 1.0 - utilization
            if remaining > 0 {
                let exhaustionDate = findExhaustionDate(
                    from: now,
                    remaining: remaining,
                    activeRate: activeRatePerSecond,
                    disabledWeekdays: disabledWeekdays,
                    deadline: windowEnd
                )
                if let exhaustion = exhaustionDate, exhaustion < windowEnd {
                    projectedExhaustionDate = exhaustion
                    daysUntilExhaustion = exhaustion.timeIntervalSince(now) / 86400
                    daysWithoutQuota = windowEnd.timeIntervalSince(exhaustion) / 86400
                    isOverConsuming = true
                }
            } else {
                // Already at or over 100%
                projectedExhaustionDate = now
                daysUntilExhaustion = 0
                daysWithoutQuota = windowEnd.timeIntervalSince(now) / 86400
                isOverConsuming = true
            }
        }

        // Filter entries to window
        let filtered = entries
            .filter { $0.date >= windowStart && $0.date <= now && $0.data.sevenDayPercentage != nil }
            .sorted { $0.date < $1.date }

        let chartSegments = buildSegments(entries: filtered, windowStart: windowStart, disabledWeekdays: disabledWeekdays)
        let projectionPoints = buildProjection(
            entries: filtered,
            utilization: utilization,
            now: now,
            windowEnd: windowEnd,
            exhaustionDate: projectedExhaustionDate,
            disabledWeekdays: disabledWeekdays
        )

        return WeeklyProjection(
            windowStart: windowStart,
            windowEnd: windowEnd,
            timeElapsedFraction: timeElapsedFraction,
            currentUtilization: utilization,
            projectedExhaustionDate: projectedExhaustionDate,
            daysUntilExhaustion: daysUntilExhaustion,
            daysWithoutQuota: daysWithoutQuota,
            isOverConsuming: isOverConsuming,
            chartSegments: chartSegments,
            projectionPoints: projectionPoints
        )
    }

    // MARK: - Active seconds helper

    private static func activeSeconds(
        from start: Date,
        to end: Date,
        disabledWeekdays: Set<Int>
    ) -> TimeInterval {
        guard !disabledWeekdays.isEmpty else {
            return end.timeIntervalSince(start)
        }

        let calendar = Calendar.current
        var total: TimeInterval = 0
        var cursor = start

        while cursor < end {
            let weekday = calendar.component(.weekday, from: cursor)
            let startOfNextDay = calendar.nextDate(
                after: cursor,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            )!
            let dayEnd = min(startOfNextDay, end)
            let chunk = dayEnd.timeIntervalSince(cursor)

            if !disabledWeekdays.contains(weekday) {
                total += chunk
            }

            cursor = dayEnd
        }

        return total
    }

    // MARK: - Find exhaustion date

    private static func findExhaustionDate(
        from start: Date,
        remaining: Double,
        activeRate: Double,
        disabledWeekdays: Set<Int>,
        deadline: Date
    ) -> Date? {
        guard !disabledWeekdays.isEmpty else {
            let seconds = remaining / activeRate
            let date = start.addingTimeInterval(seconds)
            return date < deadline ? date : nil
        }

        let calendar = Calendar.current
        var leftover = remaining
        var cursor = start

        while cursor < deadline {
            let weekday = calendar.component(.weekday, from: cursor)
            let startOfNextDay = calendar.nextDate(
                after: cursor,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            )!
            let dayEnd = min(startOfNextDay, deadline)
            let chunk = dayEnd.timeIntervalSince(cursor)

            if !disabledWeekdays.contains(weekday) {
                let consumed = activeRate * chunk
                if consumed >= leftover {
                    let secondsNeeded = leftover / activeRate
                    return cursor.addingTimeInterval(secondsNeeded)
                }
                leftover -= consumed
            }

            cursor = dayEnd
        }

        return nil
    }

    // MARK: - Segments

    private static func buildSegments(entries: [HistoryEntry], windowStart: Date, disabledWeekdays: Set<Int>) -> [ChartSegment] {
        guard let first = entries.first else { return [] }

        var segments: [ChartSegment] = []

        // Leading dashed segment from windowStart to first entry
        if first.date.timeIntervalSince(windowStart) > gapThreshold {
            let startPct: Double = 0
            let endPct = first.data.sevenDayPercentage ?? 0
            let points = staircaseInterpolation(
                from: windowStart, fromPct: startPct,
                to: first.date, toPct: endPct,
                disabledWeekdays: disabledWeekdays
            )
            segments.append(ChartSegment(points: points, isDashed: true))
        }

        var currentPoints: [ChartPoint] = [
            ChartPoint(date: first.date, percentage: first.data.sevenDayPercentage ?? 0)
        ]

        for i in 1..<entries.count {
            let prev = entries[i - 1]
            let curr = entries[i]
            let gap = curr.date.timeIntervalSince(prev.date)

            if gap > gapThreshold {
                // End solid segment
                segments.append(ChartSegment(points: currentPoints, isDashed: false))

                // Dashed bridge with staircase
                let prevPct = prev.data.sevenDayPercentage ?? 0
                let currPct = curr.data.sevenDayPercentage ?? 0
                let bridgePoints = staircaseInterpolation(
                    from: prev.date, fromPct: prevPct,
                    to: curr.date, toPct: currPct,
                    disabledWeekdays: disabledWeekdays
                )
                segments.append(ChartSegment(points: bridgePoints, isDashed: true))

                // Start new solid segment
                currentPoints = [ChartPoint(date: curr.date, percentage: curr.data.sevenDayPercentage ?? 0)]
            } else {
                currentPoints.append(
                    ChartPoint(date: curr.date, percentage: curr.data.sevenDayPercentage ?? 0)
                )
            }
        }

        if !currentPoints.isEmpty {
            segments.append(ChartSegment(points: currentPoints, isDashed: false))
        }

        return segments
    }

    /// Interpolates between two points, keeping the line flat on disabled days
    /// and distributing the change only across active days.
    private static func staircaseInterpolation(
        from startDate: Date, fromPct: Double,
        to endDate: Date, toPct: Double,
        disabledWeekdays: Set<Int>
    ) -> [ChartPoint] {
        guard !disabledWeekdays.isEmpty else {
            return [
                ChartPoint(date: startDate, percentage: fromPct),
                ChartPoint(date: endDate, percentage: toPct)
            ]
        }

        let calendar = Calendar.current
        let totalChange = toPct - fromPct
        let activeTime = activeSeconds(from: startDate, to: endDate, disabledWeekdays: disabledWeekdays)

        // If no active time in range, flat line
        guard activeTime > 0 else {
            return [
                ChartPoint(date: startDate, percentage: fromPct),
                ChartPoint(date: endDate, percentage: fromPct)
            ]
        }

        let ratePerSecond = totalChange / activeTime

        var points: [ChartPoint] = [ChartPoint(date: startDate, percentage: fromPct)]
        var currentPct = fromPct
        var cursor = startDate

        while cursor < endDate {
            let weekday = calendar.component(.weekday, from: cursor)
            let startOfNextDay = calendar.nextDate(
                after: cursor,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            )!
            let dayEnd = min(startOfNextDay, endDate)
            let chunk = dayEnd.timeIntervalSince(cursor)

            if disabledWeekdays.contains(weekday) {
                points.append(ChartPoint(date: dayEnd, percentage: currentPct))
            } else {
                currentPct += ratePerSecond * chunk
                points.append(ChartPoint(date: dayEnd, percentage: currentPct))
            }

            cursor = dayEnd
        }

        return points
    }

    // MARK: - Projection

    private static func buildProjection(
        entries: [HistoryEntry],
        utilization: Double,
        now: Date,
        windowEnd: Date,
        exhaustionDate: Date?,
        disabledWeekdays: Set<Int>
    ) -> [ChartPoint] {
        guard let last = entries.last else { return [] }
        let lastPct = last.data.sevenDayPercentage ?? (utilization * 100)

        // Fast path: no disabled days — original linear logic
        guard !disabledWeekdays.isEmpty else {
            var points: [ChartPoint] = [ChartPoint(date: last.date, percentage: lastPct)]
            if let exhaustion = exhaustionDate, exhaustion < windowEnd {
                points.append(ChartPoint(date: exhaustion, percentage: 100))
                points.append(ChartPoint(date: windowEnd, percentage: 100))
            } else {
                let totalRemaining = windowEnd.timeIntervalSince(last.date)
                guard totalRemaining > 0 else { return points }
                let elapsedSinceStart = now.timeIntervalSince(entries.first?.date ?? now)
                guard elapsedSinceStart > 0 else { return points }
                let ratePerSecond = (utilization * 100) / elapsedSinceStart
                let projectedPct = min(100, lastPct + ratePerSecond * totalRemaining)
                points.append(ChartPoint(date: windowEnd, percentage: projectedPct))
            }
            return points
        }

        // Disabled-day-aware projection: staircase pattern
        let activeElapsed = activeSeconds(
            from: entries.first?.date ?? now, to: now, disabledWeekdays: disabledWeekdays
        )
        guard activeElapsed > 0 else {
            return [ChartPoint(date: last.date, percentage: lastPct)]
        }

        let calendar = Calendar.current
        let activeRatePctPerSecond = (utilization * 100) / activeElapsed

        var points: [ChartPoint] = [ChartPoint(date: last.date, percentage: lastPct)]
        var currentPct = lastPct
        var cursor = last.date

        while cursor < windowEnd && currentPct < 100 {
            let weekday = calendar.component(.weekday, from: cursor)
            let startOfNextDay = calendar.nextDate(
                after: cursor,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            )!
            let dayEnd = min(startOfNextDay, windowEnd)
            let chunk = dayEnd.timeIntervalSince(cursor)

            if disabledWeekdays.contains(weekday) {
                // Flat line through disabled day
                points.append(ChartPoint(date: dayEnd, percentage: currentPct))
            } else {
                // Rising line through active day
                let increase = activeRatePctPerSecond * chunk
                let newPct = min(100, currentPct + increase)

                if newPct >= 100 && currentPct < 100 {
                    let secondsTo100 = (100 - currentPct) / activeRatePctPerSecond
                    let hitDate = cursor.addingTimeInterval(secondsTo100)
                    points.append(ChartPoint(date: hitDate, percentage: 100))
                    currentPct = 100
                } else {
                    points.append(ChartPoint(date: dayEnd, percentage: newPct))
                    currentPct = newPct
                }
            }

            cursor = dayEnd
        }

        // If at 100%, extend flat line to window end
        if currentPct >= 100 && cursor < windowEnd {
            points.append(ChartPoint(date: windowEnd, percentage: 100))
        }

        return points
    }
}
