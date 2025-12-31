import SwiftUI
import ShapeCore

struct MonthlyBMIChart: View {
    let calendar: Calendar
    let baseMonth: Date
    let weightManager: WeightManager

    var body: some View {
        ChartCard(
            title: monthTitle,
            subtitle: "",
            emptyMessage: "この月のデータがまだ少ないです。"
        ) {
            let points = monthDailyLatestBMIPoints()

            SimpleLineChart(
                points: points.map { CGPoint(x: $0.x, y: $0.y) },
                xRange: 1...CGFloat(max(28, daysInMonth)),
                yPadding: 0.6,
                unitLabelY: "BMI",
                unitLabelX: "日",
                goalLineY: nil,
                xAxisMode: .monthly(daysInMonth: daysInMonth)
            )
        } isEmpty: {
            monthDailyLatestBMIPoints().isEmpty
        }
    }

    private var monthTitle: String {
        baseMonth.formatted(.dateTime.year().month().locale(Locale(identifier: "ja_JP")))
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: baseMonth)?.count ?? 30
    }

    private func monthDailyLatestBMIPoints() -> [(x: CGFloat, y: CGFloat)] {
        guard weightManager.height > 0 else { return [] }

        let monthRecords = weightManager.records(inSameMonthAs: baseMonth, calendar: calendar)
        let latestByDay = weightManager.latestPerDay(records: monthRecords, calendar: calendar)

        let sorted = latestByDay.sorted { a, b in
            calendar.component(.day, from: a.date) < calendar.component(.day, from: b.date)
        }

        return sorted.compactMap { rec in
            let bmi = rec.weight / (weightManager.height * weightManager.height)
            guard bmi.isFinite else { return nil }
            let day = CGFloat(calendar.component(.day, from: rec.date))
            return (x: day, y: CGFloat(bmi))
        }
    }
}
