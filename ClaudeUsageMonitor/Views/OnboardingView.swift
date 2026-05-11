import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var apiKeyInput = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var hasExistingKey = false
    @State private var hasOAuth = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: hasOAuth ? "person.badge.shield.checkmark.fill" : "key.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(hasOAuth ? "Connessione Claude Code" : "Configura API Key")
                    .font(.headline)
            }

            // OAuth detected
            if hasOAuth {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Credenziali OAuth di Claude Code rilevate automaticamente.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 8) {
                    Text("L'app usa le credenziali di Claude Code per leggere i dati di utilizzo reali (sessione 5h e settimanale).")
                        .font(.callout)

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("Nessun costo aggiuntivo. I dati vengono letti dall'endpoint OAuth senza generare token.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.blue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                HStack {
                    Spacer()
                    Button("OK") {
                        appState.hasCompletedOnboarding = true
                        Task { await appState.refresh() }
                        dismissWindow(id: "onboarding")
                    }
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                // Current status (API key)
                if hasExistingKey {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("API Key già configurata. Inseriscine una nuova per sostituirla.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Explanation
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Credenziali OAuth di Claude Code non trovate.")
                            .font(.callout)
                            .fontWeight(.medium)
                    }

                    Text("Avvia Claude Code almeno una volta ed effettua il login, poi riapri questa app. In alternativa, configura una API key manualmente (dati limitati).")
                        .font(.callout)
                }

                Divider()

                // API key fallback
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key (fallback)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    instructionRow(number: "1", text: "Vai su console.anthropic.com → API Keys → Create Key")
                    instructionRow(number: "2", text: "Copia la key generata (inizia con sk-ant-...)")
                }

                Divider()

                // Input
                VStack(alignment: .leading, spacing: 6) {
                    Text(hasExistingKey ? "Nuova API Key" : "API Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("sk-ant-api03-...", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // Actions
                HStack {
                    Button(hasExistingKey ? "Annulla" : "Salta per ora") {
                        appState.hasCompletedOnboarding = true
                        dismissWindow(id: "onboarding")
                    }
                    .foregroundStyle(.secondary)
                    .keyboardShortcut(.cancelAction)

                    if hasExistingKey {
                        Button("Rimuovi key") {
                            KeychainHelper.delete()
                            hasExistingKey = false
                            appState.rateLimitData = nil
                        }
                        .foregroundStyle(.red)
                    }

                    Spacer()

                    Button {
                        Task { await saveKey() }
                    } label: {
                        Text(hasExistingKey ? "Sostituisci" : "Salva e attiva")
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            hasExistingKey = KeychainHelper.load() != nil
            hasOAuth = KeychainHelper.hasOAuthCredentials
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.caption)
        }
    }

    private func saveKey() async {
        isSaving = true
        errorMessage = nil
        let key = apiKeyInput.trimmingCharacters(in: .whitespaces)

        do {
            try await RateLimitService.validate(apiKey: key)
            try KeychainHelper.save(apiKey: key)
            appState.hasCompletedOnboarding = true
            await appState.refreshRateLimits()
            dismissWindow(id: "onboarding")
        } catch {
            errorMessage = "Verifica fallita: \(error.localizedDescription)"
        }

        isSaving = false
    }
}
