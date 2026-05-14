import SwiftUI
import AppKit

struct UpdateInstructionsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private static let updatePrompt = """
        Aggiorna Claude Usage Monitor all'ultima versione. Steps:

        1. cd al repo claude-code-usage-monitor (o clonalo da https://github.com/claudiopostinghel/claude-code-usage-monitor)
        2. git pull origin main
        3. Run `xcodegen generate`
        4. Build con `xcodebuild -scheme ClaudeUsageMonitor -configuration Release build`
        5. Copia il .app buildato in /Applications
        6. Rilancia l'app con: open "/Applications/Claude Usage Monitor.app"
        """

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Aggiorna Claude Usage Monitor")
                    .font(.headline)
            }

            HStack(spacing: 4) {
                Text("v\(UpdateChecker.currentVersion)")
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("v\(appState.latestVersion ?? "?")")
                    .foregroundStyle(.blue)
                    .fontWeight(.medium)
            }
            .font(.subheadline)

            Text("Copia il prompt qui sotto e incollalo in Claude Code:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(UpdateInstructionsView.updatePrompt)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxHeight: 180)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3))
            )

            HStack {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(UpdateInstructionsView.updatePrompt, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copiato!" : "Copia prompt")
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button("Chiudi") {
                    dismiss()
                }
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
