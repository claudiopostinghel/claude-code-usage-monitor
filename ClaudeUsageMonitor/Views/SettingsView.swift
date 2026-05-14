import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var apiKeyInput = ""
    @State private var hasAPIKey = false
    @State private var showUpdateInstructions = false

    var body: some View {
        Form {
            Section("Autenticazione") {
                LabeledContent("Metodo") {
                    switch appState.authMethod {
                    case .oauth:
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("OAuth Claude Code")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    case .apiKey:
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("API Key")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Rimuovi") {
                                KeychainHelper.delete()
                                hasAPIKey = false
                                appState.rateLimitData = nil
                            }
                            .font(.caption)
                        }
                    case .none:
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("Non configurato")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                LabeledContent("Stato") {
                    if let data = appState.rateLimitData {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Aggiornato ")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(data.fetchedAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(" fa")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let err = appState.rateLimitError {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Text("Non ancora aggiornato")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Cronologia") {
                LabeledContent("Punti dati") {
                    Text("\(appState.historyStore.entries.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Cancella cronologia", role: .destructive) {
                    appState.historyStore.clearHistory()
                }
            }

            Section {
                ForEach(weekdayItems, id: \.number) { item in
                    Toggle(item.name, isOn: weekdayBinding(for: item.number))
                        .toggleStyle(GreenSwitchStyle())
                }
            } header: {
                Text("Giorni di utilizzo di Claude")
            } footer: {
                Text("I giorni disattivati vengono stimati con consumo zero nelle proiezioni")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Section("Overlay Bar") {
                let screens = NSScreen.screens
                LabeledContent("Schermo") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(screens.indices, id: \.self) { i in
                            HStack(spacing: 6) {
                                Image(systemName: appState.settings.overlayScreenIndex == i ? "circle.fill" : "circle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(appState.settings.overlayScreenIndex == i ? Color.accentColor : .secondary)
                                Text(i == 0 ? "Schermo principale" : "Schermo \(i + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { appState.settings.overlayScreenIndex = i }
                        }
                    }
                }

                LabeledContent("Larghezza") {
                    HStack(spacing: 6) {
                        TextField("", value: Binding(
                            get: { appState.settings.overlayWidth },
                            set: { appState.settings.overlayWidth = max(80, $0) }
                        ), format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        Text("px")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Distanza dall'alto") {
                    HStack(spacing: 6) {
                        TextField("", value: Binding(
                            get: { appState.settings.overlayTopOffset },
                            set: { appState.settings.overlayTopOffset = max(0, $0) }
                        ), format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        Text("px")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Azioni") {
                Button("Aggiorna dati ora") {
                    Task { await appState.refresh() }
                }
                .disabled(appState.isLoading)
            }

            Section {
                LabeledContent("Versione") {
                    Text(UpdateChecker.currentVersion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if appState.updateAvailable, let version = appState.latestVersion {
                    LabeledContent("Aggiornamento") {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.caption)
                            Text("v\(version) disponibile")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Apri istruzioni di aggiornamento") {
                        showUpdateInstructions = true
                    }
                } else {
                    LabeledContent("Aggiornamento") {
                        Text("Nessun aggiornamento disponibile")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Controlla aggiornamenti") {
                    Task { await appState.checkForUpdate() }
                }
            } header: {
                Text("Informazioni")
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showUpdateInstructions) {
            UpdateInstructionsView()
                .environment(appState)
        }
        .frame(width: 400)
        .padding()
        .onAppear {
            hasAPIKey = KeychainHelper.load() != nil
        }
    }

    // MARK: - Weekday helpers

    private var weekdayItems: [(number: Int, name: String)] {
        let symbols = Calendar.current.weekdaySymbols // ["Sunday", "Monday", ...]
        let mondayFirst = [2, 3, 4, 5, 6, 7, 1]
        return mondayFirst.map { weekday in
            (number: weekday, name: symbols[weekday - 1].capitalized)
        }
    }

    private func weekdayBinding(for weekday: Int) -> Binding<Bool> {
        Binding(
            get: { !appState.settings.disabledWeekdays.contains(weekday) },
            set: { isOn in
                if isOn {
                    appState.settings.disabledWeekdays.remove(weekday)
                } else {
                    appState.settings.disabledWeekdays.insert(weekday)
                }
            }
        )
    }
}

// MARK: - Custom green switch for macOS

private struct GreenSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Capsule()
                .fill(configuration.isOn ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 38, height: 22)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .shadow(radius: 1)
                        .padding(2)
                }
                .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
                .onTapGesture { configuration.isOn.toggle() }
        }
    }
}
