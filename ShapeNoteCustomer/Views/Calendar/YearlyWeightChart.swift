import SwiftUI
import ShapeCore

struct YearlyWeightChart: View {
    let calendar: Calendar
    let yearBase: Date
    let weightManager: WeightManager
    let showsGoalLine: Bool

    var body: some View {
        ChartCard(
            title: yearTitle,
            subtitle: "",
            emptyMessage: "この年のデータがまだ少ないです。"
        ) {
            let points = yearlyLatestPerMonthPoints()

            SimpleLineChart(
                points: points.map { CGPoint(x: $0.x, y: $0.y) },
                xRange: 1...12,
                yPadding: 0.8,
                unitLabelY: "kg",
                unitLabelX: "月",
                goalLineY: (showsGoalLine && weightManager.goalWeight > 0) ? CGFloat(weightManager.goalWeight) : nil,
                xAxisMode: .yearly
            )
        } isEmpty: {
            yearlyLatestPerMonthPoints().isEmpty
        }
    }

    private var yearTitle: String {
        yearBase.formatted(.dateTime.year().locale(Locale(identifier: "ja_JP")))
    }

    private func yearlyLatestPerMonthPoints() -> [(x: CGFloat, y: CGFloat)] {
        let yearRecords = weightManager.records(inSameYearAs: yearBase, calendar: calendar)
        let latestByMonth = weightManager.latestPerMonth(records: yearRecords, calendar: calendar)

        return (1...12).compactMap { m in
            guard let rec = latestByMonth[m] else { return nil }
            return (x: CGFloat(m), y: CGFloat(rec.weight))
        }
    }
}
