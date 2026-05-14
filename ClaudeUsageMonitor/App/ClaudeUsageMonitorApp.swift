import SwiftUI

@main
struct ClaudeUsageMonitorApp: App {
    @State private var appState = AppState()
    @State private var overlayController: OverlayBarController?
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .onAppear {
                    if overlayController == nil {
                        overlayController = OverlayBarController(appState: appState)
                    }
                    if !appState.hasCompletedOnboarding && appState.authMethod == .none {
                        openWindow(id: "onboarding")
                    }
                }
        } label: {
            MenuBarLabel(appState: appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appState)
        }

        Window("Configura API Key", id: "onboarding") {
            OnboardingView()
                .environment(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

private struct MenuBarLabel: View {
    var appState: AppState

    private enum Status {
        case normal
        case fiveHourExceeded(resetDate: Date)
        case overConsuming(daysWithout: Double)
    }

    private func status(at now: Date) -> Status {
        guard let data = appState.rateLimitData else { return .normal }

        // Priority 1: 5-hour quota exceeded and reset still in the future
        if data.fiveHourUtilization >= 1.0, data.fiveHourReset > now {
            return .fiveHourExceeded(resetDate: data.fiveHourReset)
        }

        // Priority 2: Weekly over-consuming
        if let projection = WeeklyProjection.compute(from: data, entries: appState.historyStore.entries, disabledWeekdays: appState.settings.disabledWeekdays),
           projection.isOverConsuming,
           let daysWithout = projection.daysWithoutQuota {
            return .overConsuming(daysWithout: daysWithout)
        }

        return .normal
    }

    var body: some View {
        let _ = appState.tickCounter
        let info = status(at: Date())
        HStack(spacing: 3) {
            switch info {
            case .normal:
                Image(systemName: "checkmark.circle.fill")
            case .fiveHourExceeded(let resetDate):
                Image(systemName: "timer")
                if !appState.isLoading {
                    Text(Formatting.timeRemaining(until: resetDate))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            case .overConsuming(let daysWithout):
                Image(systemName: "exclamationmark.triangle.fill")
                if !appState.isLoading {
                    Text("\(Formatting.daysFormatted(daysWithout))d")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        }
    }
}
