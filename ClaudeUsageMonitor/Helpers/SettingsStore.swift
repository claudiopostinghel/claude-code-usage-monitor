import Foundation

@MainActor
@Observable
final class SettingsStore {

    // MARK: - Settings fields

    var hasCompletedOnboarding: Bool = false { didSet { save() } }
    var refreshIntervalSeconds: Int = 300 {
        didSet {
            if refreshIntervalSeconds < 60 { refreshIntervalSeconds = 60 }
            save()
        }
    }
    var disabledWeekdays: Set<Int> = [] { didSet { save() } }

    // MARK: - File location

    static let settingsURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ClaudeUsageMonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }()

    // MARK: - Init

    init() {
        load()
        if !FileManager.default.fileExists(atPath: Self.settingsURL.path) {
            save()
        }
    }

    // MARK: - Codable representation

    private struct SettingsData: Codable {
        var hasCompletedOnboarding: Bool?
        var refreshIntervalSeconds: Int?
        var disabledWeekdays: [Int]?
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: Self.settingsURL),
              let decoded = try? JSONDecoder().decode(SettingsData.self, from: data) else { return }
        hasCompletedOnboarding = decoded.hasCompletedOnboarding ?? false
        refreshIntervalSeconds = decoded.refreshIntervalSeconds ?? 300
        disabledWeekdays = Set(decoded.disabledWeekdays ?? [])
    }

    private func save() {
        let payload = SettingsData(
            hasCompletedOnboarding: hasCompletedOnboarding,
            refreshIntervalSeconds: refreshIntervalSeconds,
            disabledWeekdays: disabledWeekdays.sorted()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { return }
        try? data.write(to: Self.settingsURL, options: .atomic)
    }
}
