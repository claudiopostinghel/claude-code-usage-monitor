import SwiftUI

struct OverlayBarView: View {
    let utilization: Double
    var width: CGFloat = 220

    private var percentage: Int {
        Int((utilization * 100).rounded())
    }

    private var barColor: Color {
        let pct = utilization * 100
        switch pct {
        case ..<50: return .green
        case ..<80: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Progress bar
            GeometryReader { geo in
                Capsule()
                    .fill(.white.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(barColor.gradient)
                            .frame(width: max(0, geo.size.width * min(utilization, 1.0)))
                            .animation(.easeInOut(duration: 0.4), value: utilization)
                    }
            }
            .frame(height: 6)

            // Percentage label
            Text("\(percentage)%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: width, height: 28)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 14, bottomTrailingRadius: 14, topTrailingRadius: 0)
                .fill(.black.opacity(0.85))
        )
    }
}
