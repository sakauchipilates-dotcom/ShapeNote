import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct WeightInputSheet: View {
    var date: Date
    @Binding var isPresented: Bool
    var existingWeight: Double? = nil
    var goalWeight: Double? = nil
    var onSave: (Double, String, Date) -> Void    // ← 測定条件と時間も渡す
    var onDelete: (() -> Void)? = nil

    @State private var inputWeight: Double = 0.0
    @State private var selectedCondition: String = "起床後"
    @State private var recordTime: Date = Date()
    @FocusState private var isKeyboardActive: Bool

    private let conditions = [
        "起床後", "朝食後", "昼食後", "日中", "夕食後", "入浴前", "入浴後", "就寝前"
    ]

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f.string(from: date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("体重を記録")
                    .font(.title2.bold())
                    .padding(.top, 16)

                Label(dateString, systemImage: "calendar")
                    .font(.headline)
                    .foregroundColor(.gray.opacity(0.8))

                // 🎰 スロット方式
                SlotPicker(inputWeight: $inputWeight)
                    .padding(.top, 4)

                // ⌨️ キーボード入力
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

                // 🕒 測定条件選択
                VStack(alignment: .leading, spacing: 8) {
                    Text("測定条件")
                        .font(.subheadline.bold())
                        .foregroundColor(.gray)

                    Picker("測定条件", selection: $selectedCondition) {
                        ForEach(conditions, id: \.self) { condition in
                            Text(condition).tag(condition)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
                .padding(.horizontal)

                // ⏰ 記録時間（自動）
                HStack {
                    Label("記録時刻", systemImage: "clock")
                        .foregroundColor(.gray.opacity(0.8))
                    Spacer()
                    Text(recordTime.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }
                .padding(.horizontal)

                Spacer()

                // ✅ 保存ボタン
                Button(existingWeight == nil ? "保存する" : "更新する") {
                    onSave(inputWeight, selectedCondition, recordTime)
                    isPresented = false
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.85))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)

                // ❌ 削除ボタン
                if existingWeight != nil {
                    Button("削除する", role: .destructive) {
                        onDelete?()
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(10)
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
                        Button("閉じる") {
                            isKeyboardActive = false
                        }
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
}

// MARK: - スロット入力（小数点バグ修正版）
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
