import SwiftUI
import AppKit

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @State private var copied = false

    private var authIcon: String {
        switch appState.authMethod {
        case .oauth: "person.badge.shield.checkmark.fill"
        case .apiKey: "key.fill"
        case .none: "key.fill"
        }
    }

    private var authColor: Color {
        switch appState.authMethod {
        case .oauth: .green
        case .apiKey: .green
        case .none: .orange
        }
    }

    private var authHelp: String {
        switch appState.authMethod {
        case .oauth: "Connesso via Claude Code OAuth"
        case .apiKey: "API Key configurata — clicca per modificare"
        case .none: "Non configurato — clicca per impostare"
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        Text("Claude Code Usage")
                            .font(.headline)
                        Spacer()

                        if let data = appState.rateLimitData {
                            Button {
                                let text = Formatting.copyableText(from: data)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(text, forType: .string)
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    copied = false
                                }
                            } label: {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    .foregroundStyle(copied ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Copia dati utilizzo")
                        }

                        Button {
                            Task { await appState.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .disabled(appState.isLoading)
                        .help("Aggiorna")

                        Button {
                            openWindow(id: "onboarding")
                        } label: {
                            Image(systemName: authIcon)
                                .foregroundStyle(authColor)
                        }
                        .buttonStyle(.plain)
                        .help(authHelp)

                        Button {
                            openSettings()
                        } label: {
                            Image(systemName: "gear")
                        }
                        .buttonStyle(.plain)
                        .help("Impostazioni")
                    }

                    if let data = appState.rateLimitData,
                       let projection = WeeklyProjection.compute(from: data, entries: appState.historyStore.entries, disabledWeekdays: appState.settings.disabledWeekdays) {
                        WeeklyWarningBanner(projection: projection)
                        WeeklyDetailsView(projection: projection)
                    }

                    UsageLimitsView()

                    if let data = appState.rateLimitData,
                       let projection = WeeklyProjection.compute(from: data, entries: appState.historyStore.entries, disabledWeekdays: appState.settings.disabledWeekdays) {
                        UsageHistoryChartView(projection: projection)
                    }

                    Divider()

                    // Footer
                    HStack {
                        if let date = appState.lastScanDate {
                            Text("Aggiornato \(Formatting.relativeDate(date))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if appState.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                }
                .padding(16)
            }
            .frame(width: 340)
            .frame(maxHeight: 1200)
            .fixedSize(horizontal: false, vertical: true)

            // Full loading overlay on first launch
            if appState.isLoading && appState.rateLimitData == nil {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Caricamento…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            }
        }
    }
}
