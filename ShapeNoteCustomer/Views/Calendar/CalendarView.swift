import SwiftUI
import Charts
import ShapeCore

private enum ChartMode {
    case monthly
    case yearly
}

private enum WeightSheetMode: Equatable {
    case addNew(day: Date)
    case edit(record: WeightRecord)

    var day: Date {
        switch self {
        case .addNew(let d): return d
        case .edit(let r): return r.date
        }
    }
}

struct CalendarView: View {

    private let calendar = Calendar(identifier: .gregorian)
    @StateObject private var weightManager = WeightManager()

    @State private var currentMonthOffset: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var slideDirection: AnyTransition = .identity

    @State private var showDayDetailSheet: Bool = false
    @State private var showWeightSheet: Bool = false
    @State private var weightSheetMode: WeightSheetMode = .addNew(day: Date())

    @State private var chartMode: ChartMode = .monthly
    @State private var showGoalAlert: Bool = false
    @State private var goalInputText: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthHeader

                CalendarGridView(
                    calendar: calendar,
                    currentMonthOffset: $currentMonthOffset,
                    selectedDate: $selectedDate,
                    slideDirection: $slideDirection,
                    weightManager: weightManager,
                    onSwipe: { delta in changeMonth(by: delta) },
                    onDateTap: { date in
                        selectedDate = date
                        showDayDetailSheet = true
                    }
                )

                analyticsSection
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .task { await weightManager.loadWeights() }

        // 日別詳細（一覧から record 編集へ）
        .sheet(isPresented: $showDayDetailSheet) {
            DayDetailSheet(
                date: selectedDate,
                calendar: calendar,
                weightManager: weightManager,
                isPresented: $showDayDetailSheet,
                onTapAdd: {
                    weightSheetMode = .addNew(day: selectedDate)
                    showWeightSheet = true
                },
                onTapEditRecord: { record in
                    weightSheetMode = .edit(record: record)
                    showWeightSheet = true
                }
            )
        }

        // 入力（新規 or 編集）
        .sheet(isPresented: $showWeightSheet) {
            weightInputSheet
        }

        .alert("目標体重を入力", isPresented: $showGoalAlert) {
            alertGoalInputContent
        } message: {
            Text("kg 単位で入力してください。")
        }
    }

    // MARK: - Month Header
    private var displayedMonthDate: Date {
        calendar.date(byAdding: .month, value: currentMonthOffset, to: Date()) ?? Date()
    }

    private var monthHeader: some View {
        HStack {
            Button { changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(8)
            }

            Spacer()

            Text(displayedMonthDate, format: Date.FormatStyle().year().month(.wide))
                .font(.title3.bold())

            Spacer()

            Button { changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private func changeMonth(by delta: Int) {
        withAnimation(.easeInOut(duration: 0.33)) {
            currentMonthOffset += delta
            slideDirection = delta > 0
            ? .asymmetric(insertion: .move(edge: .trailing),
                          removal: .move(edge: .leading))
            : .asymmetric(insertion: .move(edge: .leading),
                          removal: .move(edge: .trailing))
        }
    }

    // MARK: - WeightInputSheet wrapper
    private var weightInputSheet: some View {
        switch weightSheetMode {
        case .addNew(let day):
            return WeightInputSheet(
                date: day,
                isPresented: $showWeightSheet,
                existingWeight: nil,
                goalWeight: weightManager.goalWeight,
                existingCondition: nil,
                existingHealth: nil,
                existingIsMenstruation: nil,
                editingRecordId: nil,
                initialRecordedAt: Date(),
                onSave: { newDate, weight, condition, health, isMenstruation, recordedAt, editingRecordId in
                    Task {
                        // 新規は必ず add
                        await weightManager.addRecord(
                            for: newDate,
                            weight: weight,
                            condition: condition,
                            health: health,
                            isMenstruation: isMenstruation,
                            recordedAt: recordedAt
                        )
                    }
                },
                onDelete: nil
            )

        case .edit(let record):
            return WeightInputSheet(
                date: record.date,
                isPresented: $showWeightSheet,
                existingWeight: record.weight,
                goalWeight: weightManager.goalWeight,
                existingCondition: record.condition,
                existingHealth: record.health,
                existingIsMenstruation: record.isMenstruation,
                editingRecordId: record.id,
                initialRecordedAt: record.recordedAt ?? Date(),
                onSave: { newDate, weight, condition, health, isMenstruation, recordedAt, editingRecordId in
                    guard let rid = editingRecordId else { return }
                    Task {
                        await weightManager.updateRecord(
                            recordId: rid,
                            date: newDate,
                            weight: weight,
                            condition: condition,
                            health: health,
                            isMenstruation: isMenstruation,
                            recordedAt: recordedAt
                        )
                    }
                },
                onDelete: {
                    Task { await weightManager.deleteRecord(recordId: record.id) }
                }
            )
        }
    }

    // MARK: - Analytics
    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack {
                Text("データ分析")
                    .font(.headline)

                Spacer()

                Picker("", selection: $chartMode) {
                    Text("月別").tag(ChartMode.monthly)
                    Text("年別").tag(ChartMode.yearly)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(.horizontal, 20)

            Group {
                switch chartMode {
                case .monthly:
                    MonthlyWeightChart(
                        calendar: calendar,
                        baseMonth: displayedMonthDate,
                        weightManager: weightManager
                    )
                case .yearly:
                    YearlyWeightPlaceholder()
                }
            }
            .padding(.horizontal, 20)

            goalSection
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Goal
    private var goalSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("目標体重")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(goalText)
                    .font(.headline)
            }

            Spacer()

            Button("変更") {
                let g = weightManager.goalWeight
                goalInputText = g > 0 ? String(format: "%.1f", g) : ""
                showGoalAlert = true
            }
            .font(.subheadline.bold())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private var goalText: String {
        let g = weightManager.goalWeight
        return g > 0 ? String(format: "%.1f kg", g) : "未設定"
    }

    private var alertGoalInputContent: some View {
        VStack(spacing: 12) {
            TextField("例: 55.0", text: $goalInputText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("キャンセル", role: .cancel) { }
                Spacer()
                Button("保存") {
                    if let v = Double(goalInputText) {
                        Task { await weightManager.setGoal(v) }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Monthly Chart（同一日複数なら最新を採用）

private struct MonthlyPoint: Identifiable {
    let id = UUID()
    let day: Int
    let weight: Double
}

private struct MonthlyWeightChart: View {
    let calendar: Calendar
    let baseMonth: Date
    let weightManager: WeightManager

    private var points: [MonthlyPoint] {
        guard
            let range = calendar.range(of: .day, in: .month, for: baseMonth),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: baseMonth))
        else { return [] }

        var results: [MonthlyPoint] = []

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay),
               let latest = weightManager.latestRecord(on: date) {
                results.append(MonthlyPoint(day: day, weight: latest.weight))
            }
        }
        return results.sorted { $0.day < $1.day }
    }

    private var averageWeight: Double? {
        guard !points.isEmpty else { return nil }
        let sum = points.reduce(0.0) { $0 + $1.weight }
        return sum / Double(points.count)
    }

    private var monthTitle: String {
        baseMonth.formatted(Date.FormatStyle().month(.twoDigits))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(monthTitle)月の体重推移")
                .font(.subheadline.bold())

            if points.isEmpty {
                Text("この月の体重データはまだありません。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    .padding(.top, 16)
            } else {
                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Day", point.day),
                            y: .value("Weight", point.weight)
                        )
                        PointMark(
                            x: .value("Day", point.day),
                            y: .value("Weight", point.weight)
                        )
                    }

                    if let avg = averageWeight {
                        RuleMark(y: .value("平均", avg))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Color.orange.opacity(0.8))
                    }

                    let goal = weightManager.goalWeight
                    if goal > 0 {
                        RuleMark(y: .value("目標", goal))
                            .foregroundStyle(Color.red.opacity(0.8))
                    }
                }
                .chartYAxisLabel("kg")
                .chartXAxis { AxisMarks(values: .stride(by: 5)) }
                .frame(height: 240)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct YearlyWeightPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("年別の体重推移")
                .font(.subheadline.bold())

            Text("年別チャートは今後のアップデートで追加予定です。")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                .padding(.top, 16)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}
