import SwiftUI
import Charts

struct WeightChartView: View {
    var weights: [WeightRecord]
    var goal: Double
    var mode: ChartMode
    var displayDate: Date   // 表示基準の月・年

    enum ChartMode: String, CaseIterable {
        case month = "月別"
        case year = "年別"
    }

    private let calendar = Calendar.current

    // MARK: - 表示対象データをフィルタリング
    private var filteredWeights: [WeightRecord] {
        switch mode {
        case .month:
            return weights.filter {
                calendar.isDate($0.date, equalTo: displayDate, toGranularity: .month)
            }
        case .year:
            return weights.filter {
                calendar.isDate($0.date, equalTo: displayDate, toGranularity: .year)
            }
        }
    }

    // MARK: - 平均計算
    private var weeklyAverage: Double? {
        let recentWeek = filteredWeights.suffix(7)
        guard !recentWeek.isEmpty else { return nil }
        return recentWeek.map(\.weight).reduce(0, +) / Double(recentWeek.count)
    }

    private var monthlyAverage: Double? {
        guard !filteredWeights.isEmpty else { return nil }
        return filteredWeights.map(\.weight).reduce(0, +) / Double(filteredWeights.count)
    }

    // MARK: - タイトル
    private var titleText: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.dateFormat = (mode == .month) ? "M月の体重推移" : "yyyy年の体重推移"
        return df.string(from: displayDate)
    }

    // MARK: - 本体
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // MARK: タイトル + 凡例（右上）
            HStack {
                Text(titleText)
                    .font(.headline)
                    .bold()
                    .padding(.leading, 8)

                Spacer()

                HStack(spacing: 12) {
                    if monthlyAverage != nil {
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.orange)
                                .frame(width: 14, height: 2)
                            Text("平均")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    if goal > 0 {
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 14, height: 2)
                            Text("目標")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.trailing, 4)
            }

            if filteredWeights.isEmpty {
                Text("記録がまだありません。")
                    .foregroundColor(.gray)
                    .font(.subheadline)
                    .padding(.top, 12)
            } else {
                Chart {
                    // 実際の体重データライン
                    ForEach(filteredWeights) { record in
                        LineMark(
                            x: .value("日付", record.date),
                            y: .value("体重", record.weight)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .symbol(.circle)
                        .interpolationMethod(.catmullRom)
                    }

                    // 平均体重ライン（ラベル削除済）
                    if let monthlyAverage {
                        RuleMark(y: .value("平均", monthlyAverage))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color.orange.opacity(0.7))
                    }

                    // 目標体重ライン（ラベル削除済）
                    if goal > 0 {
                        RuleMark(y: .value("目標", goal))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(Color.red.opacity(0.7))
                    }
                }
                .frame(height: 220)
                .padding(.horizontal, 8)
                .chartXAxis {
                    let stride: Calendar.Component = (mode == .month) ? .day : .month
                    AxisMarks(values: .stride(by: stride, count: (mode == .month ? 5 : 1))) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let dateValue = value.as(Date.self) {
                                let df = DateFormatter()
                                df.locale = Locale(identifier: "ja_JP")
                                df.dateFormat = (mode == .month) ? "d" : "M"
                                return Text(df.string(from: dateValue))
                            } else {
                                return Text("")
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.4), value: filteredWeights.count)
    }
}
