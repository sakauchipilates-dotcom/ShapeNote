import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// 5段階体調レベル（この画面専用）
private enum HealthLevel5: String, CaseIterable {
    case veryBad    // とても悪い
    case bad        // 悪い
    case normal     // ふつう
    case good       // 良い
    case great      // とても良い

    var emoji: String {
        switch self {
        case .veryBad:  return "😫"
        case .bad:      return "😣"
        case .normal:   return "😐"
        case .good:     return "🙂"
        case .great:    return "😄"
        }
    }

    var label: String {
        switch self {
        case .veryBad:  return "とても悪い"
        case .bad:      return "悪い"
        case .normal:   return "ふつう"
        case .good:     return "良い"
        case .great:    return "とても良い"
        }
    }
}

// 測定条件＋アイコン
private struct ConditionItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
}

// 起床後〜就寝前まで（アイコン付き）
private let conditionItems: [ConditionItem] = [
    .init(title: "起床後",  systemImage: "sunrise.fill"),
    .init(title: "朝食後",  systemImage: "sun.max"),
    .init(title: "昼食後",  systemImage: "sun.max.fill"),
    .init(title: "日中",    systemImage: "clock"),
    .init(title: "夕食後",  systemImage: "sunset"),
    .init(title: "入浴前",  systemImage: "drop"),
    .init(title: "入浴後",  systemImage: "drop.fill"),
    .init(title: "就寝前",  systemImage: "bed.double.fill")
]

struct WeightInputSheet: View {
    // CalendarView から渡ってくる引数
    var date: Date
    @Binding var isPresented: Bool
    var existingWeight: Double? = nil
    var goalWeight: Double? = nil
    var existingCondition: String? = nil
    var existingHealth: String? = nil          // Firestore 上は String
    var existingIsMenstruation: Bool? = nil

    /// 保存時コールバック
    /// newDate, weight, condition, health(rawValue), isMenstruation, recordedAt
    var onSave: (Date, Double, String, String?, Bool, Date) -> Void
    var onDelete: (() -> Void)? = nil

    // MARK: - State

    @State private var inputWeight: Double = 0.0
    @State private var selectedCondition: String = "起床後"
    @State private var selectedHealth: HealthLevel5 = .normal
    @State private var isMenstruation: Bool = false
    @State private var recordTime: Date = Date()
    /// シート内で編集する日付（カレンダーから来た日付を初期値に）
    @State private var editingDate: Date

    @FocusState private var isKeyboardActive: Bool

    // 独自 init で editingDate の初期値を設定
    init(
        date: Date,
        isPresented: Binding<Bool>,
        existingWeight: Double? = nil,
        goalWeight: Double? = nil,
        existingCondition: String? = nil,
        existingHealth: String? = nil,
        existingIsMenstruation: Bool? = nil,
        onSave: @escaping (Date, Double, String, String?, Bool, Date) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.date = date
        self._isPresented = isPresented
        self.existingWeight = existingWeight
        self.goalWeight = goalWeight
        self.existingCondition = existingCondition
        self.existingHealth = existingHealth
        self.existingIsMenstruation = existingIsMenstruation
        self.onSave = onSave
        self.onDelete = onDelete
        _editingDate = State(initialValue: date)
    }

    private var editingDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: editingDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // タイトル
                    Text("体重を記録")
                        .font(.title2.bold())
                        .padding(.top, 16)

                    // MARK: 日付 ＋ 記録時刻（横並び）
                    HStack(spacing: 12) {
                        // 日付（編集可能）
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            DatePicker(
                                "",
                                selection: $editingDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                        .font(.headline)
                        .foregroundColor(.gray.opacity(0.9))

                        Spacer()

                        // 記録時刻
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(.gray.opacity(0.8))
                            Text(recordTime.formatted(date: .omitted, time: .shortened))
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)

                    // MARK: スロット式ピッカー
                    SlotPicker(inputWeight: $inputWeight)
                        .padding(.top, 4)

                    // キーボード直接入力
                    VStack(spacing: 6) {
                        Text("タップして直接入力")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))

                        HStack(spacing: 6) {
                            TextField("", value: $inputWeight, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 34, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .frame(width: 130)
                                .focused($isKeyboardActive)

                            Text("kg")
                                .font(.title3.bold())
                                .foregroundColor(.gray.opacity(0.7))
                        }
                    }

                    Divider().padding(.vertical, 6)

                    // MARK: 測定時間
                    VStack(alignment: .leading, spacing: 8) {
                        Text("測定時間")
                            .font(.subheadline.bold())
                            .foregroundColor(.gray)

                        ZStack(alignment: .trailing) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(conditionItems) { item in
                                        ConditionChip(
                                            title: item.title,
                                            systemImage: item.systemImage,
                                            isSelected: selectedCondition == item.title
                                        ) {
                                            selectedCondition = item.title
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            // 右スライドのヒント（常にうっすら表示）
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.9)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 28)
                            .allowsHitTesting(false)

                            Image(systemName: "chevron.right")
                                .font(.caption2.bold())
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.trailing, 4)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal)

                    // MARK: 体調（5段階）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("体調")
                            .font(.subheadline.bold())
                            .foregroundColor(.gray)

                        HStack(spacing: 8) {
                            ForEach(HealthLevel5.allCases, id: \.self) { level in
                                VStack(spacing: 4) {
                                    Button {
                                        selectedHealth = level
                                    } label: {
                                        Text(level.emoji)
                                            .font(.system(size: 20))
                                            .frame(width: 40, height: 40)
                                            .background(
                                                Circle()
                                                    .fill(selectedHealth == level
                                                          ? Color.green.opacity(0.12)
                                                          : Color.white)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        selectedHealth == level
                                                        ? Color.green.opacity(0.8)
                                                        : Color.gray.opacity(0.3),
                                                        lineWidth: 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    Text(level.label)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // MARK: 生理
                    VStack(alignment: .leading, spacing: 8) {
                        Text("生理（任意）")
                            .font(.subheadline.bold())
                            .foregroundColor(.gray)

                        Button {
                            isMenstruation.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .stroke(
                                        isMenstruation
                                        ? Color.red.opacity(0.9)
                                        : Color.gray.opacity(0.4),
                                        lineWidth: 1.5
                                    )
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Circle()
                                            .fill(
                                                isMenstruation
                                                ? Color.red.opacity(0.12)
                                                : .clear
                                            )
                                    )

                                Text("生理中")
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        isMenstruation
                                        ? Color.red.opacity(0.09)
                                        : Color.white
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        isMenstruation
                                        ? Color.red.opacity(0.9)
                                        : Color.gray.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        Text("※必要な方のみ記録してください。")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 8)

                    // MARK: 保存ボタン
                    Button(existingWeight == nil ? "保存する" : "更新する") {
                        let healthString = selectedHealth.rawValue
                        onSave(
                            editingDate,
                            inputWeight,
                            selectedCondition,
                            healthString,
                            isMenstruation,
                            recordTime
                        )
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // 削除ボタン
                    if existingWeight != nil {
                        Button("削除する", role: .destructive) {
                            onDelete?()
                            isPresented = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 24)
            }
            .onAppear {
                // 体重初期値
                if let existing = existingWeight {
                    inputWeight = existing
                } else if let goal = goalWeight {
                    inputWeight = goal
                } else {
                    inputWeight = 50.0
                }

                // 測定条件初期値
                if let cond = existingCondition,
                   conditionItems.map(\.title).contains(cond) {
                    selectedCondition = cond
                }

                // 体調初期値
                if let healthStr = existingHealth,
                   let level = HealthLevel5(rawValue: healthStr) {
                    selectedHealth = level
                } else {
                    selectedHealth = .normal
                }

                // 生理
                if let flag = existingIsMenstruation {
                    isMenstruation = flag
                }

                // 日付 & 記録時刻
                editingDate = date
                recordTime = Date()
            }
            .toolbar {
                // キーボードツールバー
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("閉じる") {
                            isKeyboardActive = false
                        }
                        .font(.body.bold())
                    }
                }

                // 右上「閉じる」
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { isPresented = false }
                        .font(.body.bold())
                }
            }
        }
    }
}

// MARK: - 条件チップ（アイコン＋テキスト）

private struct ConditionChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.green.opacity(0.12) : Color.white)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.green.opacity(0.8) : Color.gray.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - スロット入力（既存と同じ）

private struct SlotPicker: View {
    @Binding var inputWeight: Double
    private let minWeight = 30.0
    private let maxWeight = 150.0

    var body: some View {
        let safeWeight = min(max(inputWeight, minWeight), maxWeight)
        let intPart = Int(safeWeight)
        let decimalPart = Int((safeWeight * 10).truncatingRemainder(dividingBy: 10))
        let digits = String(intPart).map { Int(String($0)) ?? 0 }

        HStack(spacing: 0) {
            // 整数部（2〜3桁対応）
            ForEach(Array(digits.enumerated()), id: \.offset) { index, value in
                pickerColumn(value: value, place: digits.count - index - 1)
            }

            Text(".")
                .font(.title)
                .frame(width: 28)

            // 小数部
            pickerColumn(value: decimalPart, place: -1)
        }
        .font(.title)
        .pickerStyle(.wheel)
        .frame(height: 150)
        .padding(.top, 8)
    }

    private func pickerColumn(value: Int, place: Int) -> some View {
        Picker("", selection: Binding(
            get: { value },
            set: { newValue in
                var integerPart = Int(inputWeight)
                var decimal = Int((inputWeight * 10).truncatingRemainder(dividingBy: 10))

                switch place {
                case 2: // 百の位
                    integerPart = (integerPart % 100) + (newValue * 100)
                case 1: // 十の位
                    let ones = integerPart % 10
                    integerPart = (newValue * 10) + ones
                case 0: // 一の位
                    integerPart = (integerPart / 10) * 10 + newValue
                case -1: // 小数第1位
                    decimal = newValue
                default:
                    break
                }

                let newWeight = Double(integerPart) + Double(decimal) / 10.0
                inputWeight = min(max(newWeight, minWeight), maxWeight)
            }
        )) {
            ForEach(0..<10, id: \.self) { Text("\($0)") }
        }
        .frame(width: 60)
        .clipped()
    }
}
