import SwiftUI
import ShapeCore

struct MonthlyWeightChart: View {
    let calendar: Calendar
    let baseMonth: Date
    let weightManager: WeightManager
    let showsGoalLine: Bool

    var body: some View {
        ChartCard(
            title: monthTitle,
            subtitle: "",
            emptyMessage: "この月のデータがまだ少ないです。"
        ) {
            let points = monthDailyLatestPoints()

            SimpleLineChart(
                points: points.map { CGPoint(x: $0.x, y: $0.y) },
                xRange: 1...CGFloat(max(28, daysInMonth)),
                yPadding: 0.8,
                unitLabelY: "kg",
                unitLabelX: "日",
                goalLineY: (showsGoalLine && weightManager.goalWeight > 0) ? CGFloat(weightManager.goalWeight) : nil,
                xAxisMode: .monthly(daysInMonth: daysInMonth)
            )
        } isEmpty: {
            monthDailyLatestPoints().isEmpty
        }
    }

    private var monthTitle: String {
        baseMonth.formatted(.dateTime.year().month().locale(Locale(identifier: "ja_JP")))
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: baseMonth)?.count ?? 30
    }

    private func monthDailyLatestPoints() -> [(x: CGFloat, y: CGFloat)] {
        let monthRecords = weightManager.records(inSameMonthAs: baseMonth, calendar: calendar)
        let latestByDay = weightManager.latestPerDay(records: monthRecords, calendar: calendar)

        let sorted = latestByDay.sorted { a, b in
            calendar.component(.day, from: a.date) < calendar.component(.day, from: b.date)
        }

        return sorted.map {
            let day = CGFloat(calendar.component(.day, from: $0.date))
            return (x: day, y: CGFloat($0.weight))
        }
    }
}
