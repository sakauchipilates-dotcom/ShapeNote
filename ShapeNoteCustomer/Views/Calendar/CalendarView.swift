import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import ShapeCore

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

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                monthHeader

                // ここを太く：カレンダーを主役に
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

                WeightAnalysisView(
                    chartMode: $chartMode,
                    selectedMonthDate: $selectedMonthDate,
                    weightManager: weightManager
                )

                bmiAndSettings
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)     // ← 余白を詰めてカレンダー領域を稼ぐ
            .padding(.bottom, 28)
        }
        .navigationTitle("記録")
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
                goalWeight: weightManager.goalWeight,
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

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.dark.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.70), in: Circle())
            }

            Spacer()

            Text(monthTitle)
                .font(.headline.weight(.semibold))
                .foregroundColor(Theme.dark.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.70), in: Capsule())

            Spacer()

            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.dark.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.70), in: Circle())
            }
        }
        .padding(.horizontal, 4)
    }

    private var bmiAndSettings: some View {
        VStack(spacing: 16) {
            if let bmi = weightManager.bmi {
                Text("最新のBMI：\(String(format: "%.1f", bmi))")
                    .font(.subheadline)
                    .foregroundColor(Theme.dark.opacity(0.55))
            }

            HStack(spacing: 12) {
                Button(action: { showGoalAlert = true }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text("目標体重")
                                .font(.callout.weight(.semibold))
                                .foregroundColor(Theme.sub)
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(Theme.sub.opacity(0.75))
                        }
                        Text(weightManager.goalWeight > 0
                             ? String(format: "%.1f kg", weightManager.goalWeight)
                             : "未設定")
                        .font(.title3.bold())
                        .foregroundColor(Theme.dark.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.sub.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button(action: { showHeightAlert = true }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text("身長")
                                .font(.callout.weight(.semibold))
                                .foregroundColor(Theme.accent)
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(Theme.accent.opacity(0.75))
                        }
                        Text(weightManager.height > 0
                             ? String(format: "%.2f m", weightManager.height)
                             : "未設定")
                        .font(.title3.bold())
                        .foregroundColor(Theme.dark.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.bottom, 24)
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
