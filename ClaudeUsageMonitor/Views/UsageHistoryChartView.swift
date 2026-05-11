import SwiftUI
import Charts

struct UsageHistoryChartView: View {
    let projection: WeeklyProjection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quota settimanale")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Chart {
                // Solid and dashed data segments
                ForEach(projection.chartSegments) { segment in
                    ForEach(segment.points) { point in
                        LineMark(
                            x: .value("Ora", point.date),
                            y: .value("%", point.percentage),
                            series: .value("S", segment.id.uuidString)
                        )
                        .foregroundStyle(Color.purple)
                        .lineStyle(StrokeStyle(
                            lineWidth: 1.5,
                            dash: segment.isDashed ? [4, 3] : []
                        ))
                        .interpolationMethod(segment.isDashed ? .linear : .catmullRom)
                    }
                }

                // Projection line
                ForEach(projection.projectionPoints) { point in
                    LineMark(
                        x: .value("Ora", point.date),
                        y: .value("%", point.percentage),
                        series: .value("S", "projection")
                    )
                    .foregroundStyle(Color.purple.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .interpolationMethod(.linear)
                }

                // 100% ceiling
                RuleMark(y: .value("%", 100))
                    .foregroundStyle(Color.red.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            }
            .chartYScale(domain: 0...105)
            .chartXScale(domain: projection.windowStart...projection.windowEnd)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        Text("\(value.as(Int.self) ?? 0)%")
                            .font(.system(size: 9))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartLegend(.hidden)
            .frame(height: 140)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
