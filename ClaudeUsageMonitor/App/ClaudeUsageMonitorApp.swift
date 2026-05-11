import SwiftUI

@main
struct ClaudeUsageMonitorApp: App {
    @State private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .onAppear {
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

    private var statusInfo: (icon: String, label: String, color: Color) {
        guard let data = appState.rateLimitData,
              let projection = WeeklyProjection.compute(from: data, entries: appState.historyStore.entries, disabledWeekdays: appState.settings.disabledWeekdays),
              projection.isOverConsuming,
              let daysWithout = projection.daysWithoutQuota else {
            return ("checkmark.circle.fill", "", .green)
        }
        return ("exclamationmark.triangle.fill", "\(Formatting.daysFormatted(daysWithout))d", .orange)
    }

    var body: some View {
        let info = statusInfo
        HStack(spacing: 3) {
            Image(systemName: info.icon)
                .foregroundStyle(info.color)
            if !appState.isLoading && !info.label.isEmpty {
                Text(info.label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
        }
    }
}
