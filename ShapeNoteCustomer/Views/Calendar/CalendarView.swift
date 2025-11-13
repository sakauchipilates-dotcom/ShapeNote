import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var currentMonthOffset = 0
    @State private var selectedMonthDate = Date()
    @State private var showWeightSheet = false
    @State private var showGoalAlert = false
    @State private var showHeightAlert = false
    @State private var slideDirection: AnyTransition = .identity
    @State private var chartMode: WeightChartView.ChartMode = .month

    @StateObject private var weightManager = WeightManager()
    private let calendar = Calendar.current

    // MARK: - 月切り替え
    private func changeMonth(by offset: Int) {
        withAnimation(.easeInOut(duration: 0.35)) {
            slideDirection = offset > 0
                ? .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
                : .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
            currentMonthOffset += offset
        }
        if let newDate = calendar.date(byAdding: .month, value: currentMonthOffset, to: Date()) {
            selectedMonthDate = newDate
        }
    }

    // MARK: - 本体
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 月タイトル
                monthHeader

                // カレンダー
                CalendarGridView(
                    calendar: calendar,
                    currentMonthOffset: $currentMonthOffset,
                    selectedDate: $selectedDate,
                    slideDirection: $slideDirection,
                    weightManager: weightManager,
                    onSwipe: changeMonth,
                    onDateTap: { date in
                        selectedDate = date
                        showWeightSheet = true
                    }
                )

                // データ分析
                WeightAnalysisView(
                    chartMode: $chartMode,
                    selectedMonthDate: $selectedMonthDate,
                    weightManager: weightManager
                )

                // BMI & 設定
                bmiAndSettings
            }
            .padding()
        }
        .navigationTitle("カレンダー")
        .task {
            await weightManager.loadWeights()
            selectedMonthDate = Date()
        }
        .onChange(of: currentMonthOffset) { _, newValue in
            if let newDate = calendar.date(byAdding: .month, value: newValue, to: Date()) {
                selectedMonthDate = newDate
            }
        }
        .sheet(isPresented: $showWeightSheet) {
            let currentValue = weightManager.weight(on: selectedDate)
            WeightInputSheet(
                date: selectedDate,
                isPresented: $showWeightSheet,
                existingWeight: currentValue,
                goalWeight: weightManager.goalWeight,  // ← 追加済み
                onSave: { weight, condition, recordedAt in
                    Task {
                        await weightManager.setWeight(
                            for: selectedDate,
                            weight: weight,
                            condition: condition,
                            recordedAt: recordedAt
                        )
                    }
                },
                onDelete: {
                    Task { await weightManager.deleteWeight(for: selectedDate) }
                }
            )
        }
        .alert("目標体重を入力", isPresented: $showGoalAlert) {
            TextField("例: 53.5", value: $weightManager.goalWeight, format: .number)
            Button("保存") { Task { await weightManager.setGoal(weightManager.goalWeight) } }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("身長を入力（m単位）", isPresented: $showHeightAlert) {
            TextField("例: 1.65", value: $weightManager.height, format: .number)
            Button("保存") { Task { await weightManager.setHeight(weightManager.height) } }
            Button("キャンセル", role: .cancel) {}
        }
    }

    // MARK: - 月タイトルビュー
    private var monthHeader: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle)
                .font(.title2.bold())
            Spacer()
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
    }

    // MARK: - BMI & 設定（既存デザイン維持）
    private var bmiAndSettings: some View {
        VStack(spacing: 16) {
            if let bmi = weightManager.bmi {
                Text("最新のBMI：\(String(format: "%.1f", bmi))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            HStack(spacing: 12) {
                Button(action: { showGoalAlert = true }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text("目標体重")
                                .font(.callout.bold())
                                .foregroundColor(.blue)
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.blue.opacity(0.7))
                        }
                        Text(weightManager.goalWeight > 0
                             ? String(format: "%.1f kg", weightManager.goalWeight)
                             : "未設定")
                        .font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(14)
                }

                Button(action: { showHeightAlert = true }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text("身長")
                                .font(.callout.bold())
                                .foregroundColor(.green)
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.green.opacity(0.7))
                        }
                        Text(weightManager.height > 0
                             ? String(format: "%.2f m", weightManager.height)
                             : "未設定")
                        .font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }

    private var monthTitle: String {
        let date = calendar.date(byAdding: .month, value: currentMonthOffset, to: Date())!
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }
}
