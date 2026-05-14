import Foundation

enum UpdateChecker {

    private static let manifestURL = URL(string:
        "https://raw.githubusercontent.com/claudiopostinghel/claude-code-usage-monitor/main/version.json"
    )!

    static let releasesURL = URL(string:
        "https://github.com/claudiopostinghel/claude-code-usage-monitor/releases"
    )!

    /// Returns the remote manifest, or nil on any failure.
    /// Failures are intentionally silent — update checking must never
    /// interfere with the app's primary function.
    static func fetchManifest() async -> VersionManifest? {
        do {
            var request = URLRequest(url: manifestURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return try JSONDecoder().decode(VersionManifest.self, from: data)
        } catch {
            return nil
        }
    }

    /// The running app's version from CFBundleShortVersionString.
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    /// Compares two semver strings. Returns true when `remote` is strictly
    /// greater than `local`.
    static func isNewer(remote: String, than local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }
        let r = remoteParts + Array(repeating: 0, count: max(0, 3 - remoteParts.count))
        let l = localParts + Array(repeating: 0, count: max(0, 3 - localParts.count))
        for i in 0..<3 {
            if r[i] > l[i] { return true }
            if r[i] < l[i] { return false }
        }
        return false
    }
}
