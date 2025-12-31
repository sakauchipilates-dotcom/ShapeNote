import SwiftUI
import ShapeCore

struct YearlyBMIChart: View {
    let calendar: Calendar
    let yearBase: Date
    let weightManager: WeightManager

    var body: some View {
        ChartCard(
            title: yearTitle,
            subtitle: "",
            emptyMessage: "この年のデータがまだ少ないです。"
        ) {
            let points = yearlyLatestPerMonthBMIPoints()

            SimpleLineChart(
                points: points.map { CGPoint(x: $0.x, y: $0.y) },
                xRange: 1...12,
                yPadding: 0.6,
                unitLabelY: "BMI",
                unitLabelX: "月",
                goalLineY: nil,
                xAxisMode: .yearly
            )
        } isEmpty: {
            yearlyLatestPerMonthBMIPoints().isEmpty
        }
    }

    private var yearTitle: String {
        yearBase.formatted(.dateTime.year().locale(Locale(identifier: "ja_JP")))
    }

    private func yearlyLatestPerMonthBMIPoints() -> [(x: CGFloat, y: CGFloat)] {
        guard weightManager.height > 0 else { return [] }

        let yearRecords = weightManager.records(inSameYearAs: yearBase, calendar: calendar)
        let latestByMonth = weightManager.latestPerMonth(records: yearRecords, calendar: calendar)

        return (1...12).compactMap { m in
            guard let rec = latestByMonth[m] else { return nil }
            let bmi = rec.weight / (weightManager.height * weightManager.height)
            guard bmi.isFinite else { return nil }
            return (x: CGFloat(m), y: CGFloat(bmi))
        }
    }
}
