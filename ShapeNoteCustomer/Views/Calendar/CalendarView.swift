import SwiftUI
import ShapeCore

// MARK: - CalendarView
struct CalendarView: View {

    // MARK: Dependencies
    @ObservedObject var weightManager: WeightManager
    private let calendar = Calendar(identifier: .gregorian)

    // MARK: UI State
    @State private var currentMonthOffset: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var slideDirection: AnyTransition = .identity

    @State private var showDayDetailSheet: Bool = false
    @State private var showWeightSheet: Bool = false
    @State private var showGoalHeightSheet: Bool = false

    @State private var goalInputText: String = ""
    @State private var heightCmInputText: String = ""

    enum WeightSheetMode: Equatable {
        case addNew(day: Date)
        case edit(record: WeightRecord)
    }
    @State private var weightSheetMode: WeightSheetMode = .addNew(day: Date())

    enum ChartMode: String, CaseIterable {
        case monthly, yearly
    }
    @State private var chartMode: ChartMode = .monthly

    enum AnalyticsMetric: String, CaseIterable {
        case weight = "体重"
        case bmi = "BMI"
        case health = "体調"
    }
    @State private var metric: AnalyticsMetric = .weight

    // MARK: Body
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // ✅ 追加：月表示＋左右移動ボタン（ヘッダー）
                monthHeader

                CalendarGridView(
                    calendar: calendar,
                    currentMonthOffset: $currentMonthOffset,
                    selectedDate: $selectedDate,
                    slideDirection: $slideDirection,
                    weightManager: weightManager,
                    onSwipe: { delta in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            slideDirection = delta > 0 ? .move(edge: .trailing) : .move(edge: .leading)
                            currentMonthOffset += delta
                        }
                    },
                    onDateTap: { tappedDate in
                        selectedDate = tappedDate
                        showDayDetailSheet = true
                    }
                )

                analyticsSection

                goalHeightSection
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))

        // Day detail
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

        // Weight sheet
        .sheet(isPresented: $showWeightSheet) {
            weightInputSheet
        }

        // Goal + Height sheet
        .sheet(isPresented: $showGoalHeightSheet) {
            GoalHeightEditSheet(
                goalText: $goalInputText,
                heightCmText: $heightCmInputText,
                onCancel: { showGoalHeightSheet = false },
                onSave: { goalKg, heightCm in
                    Task {
                        if let goalKg, goalKg > 0 {
                            await weightManager.setGoalWeight(goalKg)
                        }
                        if let heightCm, heightCm > 0 {
                            await weightManager.setHeight(heightCm / 100.0)
                        }

                        // 表示用テキストを同期
                        let g = weightManager.goalWeight
                        goalInputText = g > 0 ? String(format: "%.1f", g) : ""

                        let h = weightManager.height
                        heightCmInputText = h > 0 ? String(format: "%.0f", h * 100.0) : ""
                    }
                    showGoalHeightSheet = false
                }
            )
        }
        .onAppear {
            let g = weightManager.goalWeight
            goalInputText = g > 0 ? String(format: "%.1f", g) : ""

            let h = weightManager.height
            heightCmInputText = h > 0 ? String(format: "%.0f", h * 100.0) : ""
        }
    }

    // MARK: - ✅ Month Header（追加）
    private var monthHeader: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    slideDirection = .move(edge: .leading)
                    currentMonthOffset -= 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color(.systemBackground)))
                    .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(displayedMonthTitle)
                .font(.headline.weight(.semibold))
                .foregroundColor(Theme.dark.opacity(0.92))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    slideDirection = .move(edge: .trailing)
                    currentMonthOffset += 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color(.systemBackground)))
                    .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private var displayedMonthTitle: String {
        displayedMonthDate.formatted(.dateTime.year().month().locale(Locale(identifier: "ja_JP")))
    }

    // MARK: - WeightInputSheet wrapper
    @ViewBuilder
    private var weightInputSheet: some View {
        switch weightSheetMode {
        case .addNew(let day):
            WeightInputSheet(
                date: day,
                isPresented: $showWeightSheet,
                existingWeight: nil,
                goalWeight: (weightManager.goalWeight > 0 ? weightManager.goalWeight : nil),
                existingCondition: nil,
                existingHealth: nil,
                existingIsMenstruation: nil,
                editingRecordId: nil,
                initialRecordedAt: Date(),
                onSave: { newDate, weight, condition, health, isMenstruation, recordedAt, _ in
                    Task {
                        await weightManager.addRecord(
                            for: newDate,
                            weight: weight,
                            condition: condition,
                            health: health,
                            isMenstruation: isMenstruation,
                            recordedAt: recordedAt
                        )
                    }
                }
            )

        case .edit(let record):
            WeightInputSheet(
                date: record.date,
                isPresented: $showWeightSheet,
                existingWeight: record.weight,
                goalWeight: (weightManager.goalWeight > 0 ? weightManager.goalWeight : nil),
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
                }
            )
        }
    }

    // MARK: - Analytics
    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {

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

            // ★追加：グラフ種別切り替え
            Picker("", selection: $metric) {
                Text("体重").tag(AnalyticsMetric.weight)
                Text("BMI").tag(AnalyticsMetric.bmi)
                Text("体調").tag(AnalyticsMetric.health)
            }
            .pickerStyle(.segmented)

            Group {
                switch (chartMode, metric) {

                case (.monthly, .weight):
                    MonthlyWeightChart(
                        calendar: calendar,
                        baseMonth: displayedMonthDate,
                        weightManager: weightManager,
                        showsGoalLine: true
                    )

                case (.monthly, .bmi):
                    MonthlyBMIChart(
                        calendar: calendar,
                        baseMonth: displayedMonthDate,
                        weightManager: weightManager
                    )

                case (.monthly, .health):
                    MonthlyHealthPieChart(
                        calendar: calendar,
                        baseMonth: displayedMonthDate,
                        weightManager: weightManager
                    )

                case (.yearly, .weight):
                    YearlyWeightChart(
                        calendar: calendar,
                        yearBase: displayedMonthDate,
                        weightManager: weightManager,
                        showsGoalLine: true
                    )

                case (.yearly, .bmi):
                    YearlyBMIChart(
                        calendar: calendar,
                        yearBase: displayedMonthDate,
                        weightManager: weightManager
                    )

                case (.yearly, .health):
                    YearlyHealthPieChart(
                        calendar: calendar,
                        yearBase: displayedMonthDate,
                        weightManager: weightManager
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var displayedMonthDate: Date {
        calendar.date(byAdding: .month, value: currentMonthOffset, to: Date()) ?? Date()
    }

    // MARK: - Goal + Height + BMI
    private var goalHeightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("目標体重")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(goalText)
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("身長")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(heightText)
                        .font(.headline)
                }
            }

            if let bmi = currentBMI {
                Text("BMI \(String(format: "%.1f", bmi))")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            } else {
                Text("BMI —")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button("変更") {
                    let g = weightManager.goalWeight
                    goalInputText = g > 0 ? String(format: "%.1f", g) : ""

                    let h = weightManager.height
                    heightCmInputText = h > 0 ? String(format: "%.0f", h * 100.0) : ""

                    showGoalHeightSheet = true
                }
                .font(.subheadline.bold())
            }
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
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var goalText: String {
        let g = weightManager.goalWeight
        return g > 0 ? String(format: "%.1f kg", g) : "未設定"
    }

    private var heightText: String {
        let h = weightManager.height
        return h > 0 ? String(format: "%.0f cm", h * 100.0) : "未設定"
    }

    private var currentBMI: Double? {
        let h = weightManager.height
        guard h > 0 else { return nil }

        let latest = weightManager.weights
            .sorted {
                let l = $0.recordedAt ?? $0.date
                let r = $1.recordedAt ?? $1.date
                return l > r
            }
            .first

        guard let w = latest?.weight, w > 0 else { return nil }
        return w / (h * h)
    }
}

// MARK: - Goal/Height Edit Sheet (cm入力)
private struct GoalHeightEditSheet: View {
    @Binding var goalText: String
    @Binding var heightCmText: String

    let onCancel: () -> Void
    let onSave: (_ goalKg: Double?, _ heightCm: Double?) -> Void

    @FocusState private var focus: Field?
    private enum Field { case goal, height }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("目標体重")) {
                    TextField("例: 50.0", text: $goalText)
                        .keyboardType(.decimalPad)
                        .focused($focus, equals: .goal)
                }

                Section(header: Text("身長（cm）")) {
                    TextField("例: 165", text: $heightCmText)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: .height)

                    Text("入力は cm（例: 165）。内部保存は m（1.65）になります。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("目標/身長を変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { onCancel() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let goalKg = parseDouble(goalText)
                        let heightCm = parseDouble(heightCmText)
                        onSave(goalKg, heightCm)
                    }
                    .font(.body.bold())
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    focus = goalText.isEmpty ? .goal : .height
                }
            }
        }
    }

    private func parseDouble(_ s: String) -> Double? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "．", with: ".")
        let removedComma = normalized.replacingOccurrences(of: ",", with: "")
        return Double(removedComma)
    }
}
