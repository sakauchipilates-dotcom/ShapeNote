import SwiftUI
import ShapeCore

struct YearlyHealthPieChart: View {
    let calendar: Calendar
    let yearBase: Date
    let weightManager: WeightManager

    var body: some View {
        ChartCard(
            title: yearTitle,
            subtitle: "体調（割合）",
            emptyMessage: "この年の体調データがまだありません。"
        ) {
            HealthPieChart(distribution: distribution)
        } isEmpty: {
            distribution.totalCount == 0
        }
    }

    private var yearTitle: String {
        yearBase.formatted(.dateTime.year().locale(Locale(identifier: "ja_JP")))
    }

    private var distribution: HealthDistribution {
        let yearRecords = weightManager.records(inSameYearAs: yearBase, calendar: calendar)
        // 年は「日ごと最新」で集計（同日の複数入力を潰す）
        let latestByDay = weightManager.latestPerDay(records: yearRecords, calendar: calendar)

        var counts: [HealthLevel5: Int] = [:]
        latestByDay.forEach { rec in
            if let level = weightManager.healthLevel5(from: rec.health) {
                counts[level, default: 0] += 1
            }
        }
        return HealthDistribution(counts: counts)
    }
}
