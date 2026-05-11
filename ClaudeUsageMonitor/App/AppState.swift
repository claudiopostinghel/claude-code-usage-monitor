import Foundation
import SwiftUI

@MainActor
@Observable
final class AppState {
    var isLoading = false
    var lastScanDate: Date?
    var rateLimitData: RateLimitData?
    var rateLimitError: String?
    let historyStore = HistoryStore()
    let settings = SettingsStore()

    var hasCompletedOnboarding: Bool {
        get { settings.hasCompletedOnboarding }
        set { settings.hasCompletedOnboarding = newValue }
    }

    init() {
        Task { @MainActor [weak self] in
            await self?.refresh()
            while true {
                let interval = self?.settings.refreshIntervalSeconds ?? 300
                try? await Task.sleep(for: .seconds(interval))
                await self?.refresh()
            }
        }
    }

    // MARK: - Menu bar

    var menuBarLabel: String {
        guard let data = rateLimitData else { return "" }
        let sessionPct = Int(data.fiveHourPercentage)
        let weeklyPct = data.sevenDayPercentage.map { Int($0) }
        let maxPct = max(sessionPct, weeklyPct ?? 0)
        return "\(maxPct)%"
    }

    // MARK: - Refresh

    func refresh() async {
        isLoading = true
        await refreshRateLimits()
        lastScanDate = Date()
        if let data = rateLimitData {
            historyStore.append(HistoryEntry(data: data))
        }
        isLoading = false
    }

    var authMethod: AuthMethod {
        if KeychainHelper.hasOAuthCredentials { return .oauth }
        if KeychainHelper.load() != nil { return .apiKey }
        return .none
    }

    enum AuthMethod {
        case oauth, apiKey, none
    }

    func refreshRateLimits() async {
        // Try OAuth first (Claude Code credentials)
        if let token = KeychainHelper.loadOAuthToken() {
            do {
                rateLimitData = try await RateLimitService.fetchViaOAuth(accessToken: token)
                rateLimitError = nil
                return
            } catch {
                // OAuth failed, fall through to API key
            }
        }

        // Fallback to API key
        if let apiKey = KeychainHelper.load() {
            do {
                rateLimitData = try await RateLimitService.fetchViaAPIKey(apiKey: apiKey)
                rateLimitError = nil
                return
            } catch {
                rateLimitError = error.localizedDescription
                return
            }
        }

        rateLimitError = "Effettua il login a Claude Code per rilevare le credenziali OAuth, oppure configura una API key."
    }
}
