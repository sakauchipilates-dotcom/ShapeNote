import SwiftUI
import ShapeCore

struct WeightInputSheet: View {
    var date: Date
    @Binding var isPresented: Bool
    var existingWeight: Double? = nil
    var goalWeight: Double? = nil
    var onSave: (Double, String, Date) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var inputWeight: Double = 0.0
    @State private var selectedMeasure: MeasureCondition = .wake
    @State private var selectedHealth: HealthCondition = .normal
    @State private var recordTime: Date = Date()

    @FocusState private var isKeyboardActive: Bool

    // MARK: - Enums
    enum MeasureCondition: String, CaseIterable, Identifiable {
        case wake = "起床後"
        case afterBreakfast = "朝食後"
        case afterLunch = "昼食後"
        case daytime = "日中"
        case afterDinner = "夕食後"
        case beforeBath = "入浴前"
        case afterBath = "入浴後"
        case beforeBed = "就寝前"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .wake: return "sunrise"
            case .afterBreakfast: return "sun.max"
            case .afterLunch: return "sun.max.fill"
            case .daytime: return "clock"
            case .afterDinner: return "fork.knife"
            case .beforeBath: return "drop"
            case .afterBath: return "drop.fill"
            case .beforeBed: return "moon.stars"
            }
        }
    }

    enum HealthCondition: String, CaseIterable, Identifiable {
        case good, normal, bad

        var id: String { rawValue }

        var title: String {
            switch self {
            case .good: return "良い"
            case .normal: return "普通"
            case .bad: return "悪い"
            }
        }

        var icon: String {
            switch self {
            case .good: return "face.smiling"
            case .normal: return "face.neutral"
            case .bad: return "face.dashed"
            }
        }

        /// カレンダーのドットにも使える色（Theme に warning がある想定）
        var tint: Color {
            switch self {
            case .good:
                return Theme.sub
            case .normal:
                return Theme.accent
            case .bad:
                return Theme.semanticColor.warning
            }
        }
    }

    // MARK: - Date label
    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {

                Text(existingWeight == nil ? "体重を記録" : "体重を更新")
                    .font(.title2.bold())
                    .padding(.top, 14)

                Label(dateString, systemImage: "calendar")
                    .font(.headline)
                    .foregroundColor(Theme.dark.opacity(0.65))

                // 🎰 スロット方式（維持）
                SlotPicker(inputWeight: $inputWeight)
                    .padding(.top, 2)

                // ⌨️ 直接入力（維持）
                VStack(spacing: 6) {
                    Text("タップして直接入力")
                        .font(.caption)
                        .foregroundColor(Theme.dark.opacity(0.55))

                    HStack(spacing: 8) {
                        TextField("", value: $inputWeight, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 34, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .frame(width: 140)
                            .focused($isKeyboardActive)

                        Text("kg")
                            .font(.title3.bold())
                            .foregroundColor(Theme.dark.opacity(0.55))
                    }
                }

                Divider().opacity(0.25)

                // ✅ 測定時間：横並びタップ選択
                VStack(alignment: .leading, spacing: 10) {
                    Text("測定時間")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.dark.opacity(0.70))

                    pillRow(items: MeasureCondition.allCases, selection: $selectedMeasure) { item, isSelected in
                        pill(
                            title: item.rawValue,
                            systemImage: item.icon,
                            isSelected: isSelected,
                            selectedTint: Theme.sub
                        )
                    }
                }
                .padding(.horizontal)

                // ✅ 体調：横並びタップ選択
                VStack(alignment: .leading, spacing: 10) {
                    Text("体調")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.dark.opacity(0.70))

                    pillRow(items: HealthCondition.allCases, selection: $selectedHealth) { item, isSelected in
                        pill(
                            title: item.title,
                            systemImage: item.icon,
                            isSelected: isSelected,
                            selectedTint: item.tint
                        )
                    }
                }
                .padding(.horizontal)

                // ⏰ 記録時間（自動）
                HStack {
                    Label("記録時刻", systemImage: "clock")
                        .foregroundColor(Theme.dark.opacity(0.65))
                    Spacer()
                    Text(recordTime.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.dark.opacity(0.85))
                }
                .padding(.horizontal)

                Spacer()

                // ✅ 保存/更新
                Button(existingWeight == nil ? "保存する" : "更新する") {
                    // onSave のシグネチャは変えないため、ここで pack して渡す
                    // 例: "起床後||good"
                    let packed = "\(selectedMeasure.rawValue)||\(selectedHealth.rawValue)"
                    onSave(inputWeight, packed, recordTime)
                    isPresented = false
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.sub.opacity(0.92))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)

                // ❌ 削除
                if existingWeight != nil {
                    Button("削除する", role: .destructive) {
                        onDelete?()
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.semanticColor.warning)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .onAppear {
                if let existing = existingWeight {
                    inputWeight = existing
                } else if let goal = goalWeight {
                    inputWeight = goal
                } else {
                    inputWeight = 50.0
                }
                recordTime = Date()
            }
            .toolbar {
                // キーボードツールバー
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("閉じる") { isKeyboardActive = false }
                            .font(.body.bold())
                    }
                }

                // ナビバー右上「閉じる」
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { isPresented = false }
                        .font(.body.bold())
                }
            }
        }
    }

    // MARK: - Pills UI
    private func pillRow<Item: Identifiable & Hashable>(
        items: [Item],
        selection: Binding<Item>,
        content: @escaping (Item, Bool) -> AnyView
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items, id: \.id) { item in
                    let isSelected = (item == selection.wrappedValue)
                    Button {
                        selection.wrappedValue = item
                    } label: {
                        content(item, isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func pill(title: String, systemImage: String, isSelected: Bool, selectedTint: Color) -> AnyView {
        AnyView(
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundColor(isSelected ? selectedTint : Theme.dark.opacity(0.65))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? selectedTint.opacity(0.16) : Color.white.opacity(0.70))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? selectedTint.opacity(0.35) : Color.black.opacity(0.06), lineWidth: 1)
            )
        )
    }
}

// MARK: - スロット入力（小数点バグ修正版：維持）
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
