import SwiftUI

struct WeeklyWarningBanner: View {
    let projection: WeeklyProjection

    var body: some View {
        if projection.isOverConsuming,
           let daysWithout = projection.daysWithoutQuota {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))

                Text("A questo ritmo rimarrai all'asciutto per \(Formatting.daysFormatted(daysWithout)) giorni")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.black)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct WeeklyDetailsView: View {
    let projection: WeeklyProjection

    var body: some View {
        VStack(spacing: 4) {
            let usedPct = Formatting.daysFormatted(projection.currentUtilization * 100)
            let timePct = Formatting.daysFormatted(projection.timeElapsedFraction * 100)

            infoRow("Quota settimanale usata", value: "\(usedPct)%")
            infoRow("Tempo effettivo passato", value: "\(timePct)%")

            Divider()
                .padding(.vertical, 2)

            infoRow("Reset", value: Formatting.italianDayAndTime(projection.windowEnd))

            if let exhaustionDate = projection.projectedExhaustionDate {
                infoRow("Finirai la tua quota", value: Formatting.italianDayAndTime(exhaustionDate))
            }

            if let daysWithout = projection.daysWithoutQuota, projection.isOverConsuming {
                infoRow("Rimarrai all'asciutto", value: "per \(Formatting.daysFormatted(daysWithout)) giorni")
            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium))
        }
    }
}
