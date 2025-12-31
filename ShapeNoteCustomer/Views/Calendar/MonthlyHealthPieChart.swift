import SwiftUI
import ShapeCore

struct MonthlyHealthPieChart: View {
    let calendar: Calendar
    let baseMonth: Date
    let weightManager: WeightManager

    var body: some View {
        ChartCard(
            title: monthTitle,
            subtitle: "体調（割合）",
            emptyMessage: "この月の体調データがまだありません。"
        ) {
            HealthPieChart(distribution: distribution)
        } isEmpty: {
            distribution.totalCount == 0
        }
    }

    private var monthTitle: String {
        baseMonth.formatted(.dateTime.year().month().locale(Locale(identifier: "ja_JP")))
    }

    private var distribution: HealthDistribution {
        let monthRecords = weightManager.records(inSameMonthAs: baseMonth, calendar: calendar)
        let latestByDay = weightManager.latestPerDay(records: monthRecords, calendar: calendar)

        var counts: [HealthLevel5: Int] = [:]
        latestByDay.forEach { rec in
            if let level = weightManager.healthLevel5(from: rec.health) {
                counts[level, default: 0] += 1
            }
        }
        return HealthDistribution(counts: counts)
    }
}
