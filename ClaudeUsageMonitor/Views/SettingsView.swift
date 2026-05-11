import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var apiKeyInput = ""
    @State private var hasAPIKey = false

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

            Section("Azioni") {
                Button("Aggiorna dati ora") {
                    Task { await appState.refresh() }
                }
                .disabled(appState.isLoading)
            }
        }
        .formStyle(.grouped)
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
