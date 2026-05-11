import SwiftUI

struct UsageLimitsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Limiti utilizzo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Image(systemName: "network")
                    .font(.system(size: 8))
                    .foregroundStyle(.blue)
                    .help("Dati da API Anthropic")
            }

            LimitBar(
                label: "Sessione (5h)",
                percentage: appState.rateLimitData?.fiveHourPercentage,
                resetDate: appState.rateLimitData?.fiveHourReset
            )

            LimitBar(
                label: "Settimanale",
                percentage: appState.rateLimitData?.sevenDayPercentage,
                resetDate: appState.rateLimitData?.sevenDayReset
            )

            if let error = appState.rateLimitError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - LimitBar

private struct LimitBar: View {
    let label: String
    let percentage: Double?
    let resetDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                if let pct = percentage {
                    Text("\(Int(pct))%")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(colorForPercentage(pct))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)
                        .frame(height: 6)

                    if let pct = percentage {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(colorForPercentage(pct).gradient)
                            .frame(width: max(2, geo.size.width * CGFloat(pct / 100)), height: 6)
                    }
                }
            }
            .frame(height: 6)

            if let reset = resetDate, reset > Date() {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 9))
                    Text("Reset tra \(Formatting.timeRemaining(until: reset))")
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func colorForPercentage(_ pct: Double) -> Color {
        switch pct {
        case ..<50: .green
        case ..<80: .orange
        default: .red
        }
    }
}
