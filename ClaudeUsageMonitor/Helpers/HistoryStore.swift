import Foundation

@MainActor
@Observable
final class HistoryStore {
    private(set) var entries: [HistoryEntry] = []

    private static let maxEntries = 2016 // 7 giorni a intervalli di 5 min

    private let fileURL: URL

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ClaudeUsageMonitor", isDirectory: true)
        self.fileURL = dir.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
    }

    func append(_ entry: HistoryEntry) {
        entries.append(entry)
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
        save()
    }

    func clearHistory() {
        entries.removeAll()
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Private

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? Self.decoder.decode([HistoryEntry].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? Self.encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
