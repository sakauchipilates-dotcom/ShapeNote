import SwiftUI
import ShapeCore

// MARK: - Firestore health payload
// 例: {"level":"normal","markers":["jogging","menstruation"]}
private struct HealthPayload: Codable {
    let level: String
    let markers: [String]
}

// MARK: - 測定条件＋アイコン
private struct ConditionItem: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
}

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

// MARK: - カスタムマーク
private struct CustomMarker: Identifiable {
    let key: String
    let label: String
    let systemImage: String
    var id: String { key }
}

private let customMarkerCandidates: [CustomMarker] = [
    .init(key: "menstruation", label: "生理",            systemImage: "heart.fill"),
    .init(key: "jogging",      label: "ジョギング",      systemImage: "figure.run"),
    .init(key: "training",     label: "トレーニング",    systemImage: "dumbbell.fill"),
    .init(key: "pilates",      label: "ピラティス/ヨガ", systemImage: "figure.cooldown"),
    .init(key: "lesson",       label: "習い事",          systemImage: "music.note.list"),
    .init(key: "study",        label: "勉強",            systemImage: "book.closed.fill")
]

private let customMarkerKeySet: Set<String> = Set(customMarkerCandidates.map { $0.key })

// MARK: - 体調（HealthLevel5）表示補助（※enum定義はしない）
private let healthLevelsOrdered: [HealthLevel5] = [.veryBad, .bad, .normal, .good, .great]

private func healthColor(_ level: HealthLevel5) -> Color {
    switch level {
    case .veryBad: return Theme.warning.opacity(0.35)
    case .bad:     return Theme.warning.opacity(0.22)
    case .normal:  return Theme.accent.opacity(0.18)
    case .good:    return Theme.sub.opacity(0.20)
    case .great:   return Theme.sub.opacity(0.28)
    }
}

private func healthLabel(_ level: HealthLevel5) -> String {
    switch level {
    case .veryBad: return "とても悪い"
    case .bad:     return "悪い"
    case .normal:  return "ふつう"
    case .good:    return "良い"
    case .great:   return "とても良い"
    }
}

// MARK: - 本体
struct WeightInputSheet: View {
    var date: Date
    @Binding var isPresented: Bool

    var existingWeight: Double? = nil
    var goalWeight: Double? = nil
    var existingCondition: String? = nil
    var existingHealth: String? = nil
    var existingIsMenstruation: Bool? = nil

    /// 編集対象の recordId（新規なら nil）
    var editingRecordId: String? = nil

    /// 編集時に時刻を引き継ぐための初期値
    var initialRecordedAt: Date = Date()

    /// onSave に editingRecordId を渡す（新規/編集を外側で判定）
    var onSave: (Date, Double, String, String?, Bool, Date, String?) -> Void

    // MARK: - State
    @State private var inputWeight: Double = 50.0
    @State private var selectedCondition: String = "起床後"
    @State private var selectedHealth: HealthLevel5 = .normal
    @State private var selectedMarkers: Set<String> = []

    @State private var recordTime: Date = Date()
    @State private var editingDate: Date

    @FocusState private var isKeyboardActive: Bool

    init(
        date: Date,
        isPresented: Binding<Bool>,
        existingWeight: Double? = nil,
        goalWeight: Double? = nil,
        existingCondition: String? = nil,
        existingHealth: String? = nil,
        existingIsMenstruation: Bool? = nil,
        editingRecordId: String? = nil,
        initialRecordedAt: Date = Date(),
        onSave: @escaping (Date, Double, String, String?, Bool, Date, String?) -> Void
    ) {
        self.date = date
        self._isPresented = isPresented
        self.existingWeight = existingWeight
        self.goalWeight = goalWeight
        self.existingCondition = existingCondition
        self.existingHealth = existingHealth
        self.existingIsMenstruation = existingIsMenstruation
        self.editingRecordId = editingRecordId
        self.initialRecordedAt = initialRecordedAt
        self.onSave = onSave
        _editingDate = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    Text(editingRecordId == nil ? "体重を記録" : "記録を編集")
                        .font(.title2.bold())
                        .padding(.top, 16)

                    // 日付 + 記録時刻
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            DatePicker("", selection: $editingDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        .font(.headline)
                        .foregroundColor(.gray.opacity(0.9))

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(.gray.opacity(0.8))
                            Text(recordTime.formatted(date: .omitted, time: .shortened))
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)

                    // スロット式ピッカー
                    SlotPicker(inputWeight: $inputWeight)
                        .padding(.top, 4)

                    // キーボード直接入力
                    VStack(spacing: 6) {
                        Text("タップして直接入力")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.7))

                        HStack(spacing: 6) {
                            TextField(
                                "",
                                value: $inputWeight,
                                format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
                            )
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

                    // 測定時間
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
                                        ) { selectedCondition = item.title }
                                    }
                                }
                                .padding(.vertical, 4)
                            }

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

                    // 体調（5段階）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("体調（必須）")
                            .font(.subheadline.bold())
                            .foregroundColor(.gray)

                        HStack(spacing: 12) {
                            ForEach(healthLevelsOrdered, id: \.self) { level in
                                VStack(spacing: 6) {
                                    Button { selectedHealth = level } label: {
                                        Circle()
                                            .fill(healthColor(level))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        selectedHealth == level
                                                        ? Theme.sub.opacity(0.90)
                                                        : Color.gray.opacity(0.30),
                                                        lineWidth: selectedHealth == level ? 2 : 1
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)

                                    Text(healthLabel(level))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // カスタムマーク
                    VStack(alignment: .leading, spacing: 8) {
                        Text("カスタムマーク（任意・最大2つ）")
                            .font(.subheadline.bold())
                            .foregroundColor(.gray)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ],
                            spacing: 8
                        ) {
                            ForEach(customMarkerCandidates) { marker in
                                CustomMarkerChip(
                                    marker: marker,
                                    isSelected: selectedMarkers.contains(marker.key),
                                    action: { toggleMarker(marker.key) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 8)

                    Button(editingRecordId == nil ? "保存する" : "更新する") {
                        let healthString = makeHealthString()
                        let isMenstruation = selectedMarkers.contains("menstruation")

                        onSave(
                            editingDate,
                            inputWeight,
                            selectedCondition,
                            healthString,
                            isMenstruation,
                            recordTime,
                            editingRecordId
                        )
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.sub.opacity(0.90))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .onAppear { applyInitialState() }
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("閉じる") { isKeyboardActive = false }
                            .font(.body.bold())
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { isPresented = false }
                        .font(.body.bold())
                }
            }
        }
    }

    // MARK: - Initial State

    private func applyInitialState() {
        if let existing = existingWeight {
            inputWeight = existing
        } else if let goal = goalWeight, goal > 0 {
            inputWeight = goal
        } else {
            inputWeight = 50.0
        }

        if let cond = existingCondition, !cond.isEmpty {
            selectedCondition = cond
        } else {
            selectedCondition = "起床後"
        }

        loadExistingHealth()
        editingDate = date
        recordTime = (editingRecordId == nil) ? Date() : initialRecordedAt
    }

    private func loadExistingHealth() {
        var initialLevel: HealthLevel5 = .normal
        var initialMarkers: Set<String> = []

        if let raw = existingHealth,
           let data = raw.data(using: .utf8),
           let payload = try? JSONDecoder().decode(HealthPayload.self, from: data) {

            if let level = HealthLevel5(rawValue: payload.level) {
                initialLevel = level
            }
            initialMarkers = Set(payload.markers).intersection(customMarkerKeySet)

        } else if let raw = existingHealth,
                  let level = HealthLevel5(rawValue: raw) {
            initialLevel = level
        }

        if existingIsMenstruation == true {
            initialMarkers.insert("menstruation")
        }

        selectedHealth = initialLevel
        selectedMarkers = initialMarkers
    }

    private func toggleMarker(_ key: String) {
        if selectedMarkers.contains(key) {
            selectedMarkers.remove(key)
        } else {
            guard selectedMarkers.count < 2 else { return }
            selectedMarkers.insert(key)
        }
    }

    private func makeHealthString() -> String? {
        let payload = HealthPayload(level: selectedHealth.rawValue, markers: Array(selectedMarkers))
        guard let data = try? JSONEncoder().encode(payload),
              let string = String(data: data, encoding: .utf8) else {
            return selectedHealth.rawValue
        }
        return string
    }
}

// MARK: - UI Parts

private struct ConditionChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.caption)
                Text(title).font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? Theme.sub.opacity(0.12) : Color(.systemBackground)))
            .overlay(
                Capsule().stroke(isSelected ? Theme.sub.opacity(0.8) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CustomMarkerChip: View {
    let marker: CustomMarker
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: marker.systemImage).font(.caption)
                Text(marker.label).font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(isSelected ? Theme.sub.opacity(0.12) : Color(.systemBackground)))
            .overlay(
                Capsule().stroke(isSelected ? Theme.sub.opacity(0.8) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Slot Picker（表示の安定化：整数部は常に3桁想定で扱う）
private struct SlotPicker: View {
    @Binding var inputWeight: Double
    private let minWeight = 30.0
    private let maxWeight = 150.0

    var body: some View {
        let safeWeight = min(max(inputWeight, minWeight), maxWeight)
        let intPart = Int(safeWeight)
        let decimalPart = Int((safeWeight * 10).truncatingRemainder(dividingBy: 10))

        let padded = String(format: "%03d", intPart)
        let digits = padded.map { Int(String($0)) ?? 0 }

        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { index in
                pickerColumn(value: digits[index], place: 2 - index)
                    .opacity(index == 0 && digits[0] == 0 ? 0.35 : 1.0)
            }

            Text(".").font(.title).frame(width: 28)
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
                case 2:
                    integerPart = (integerPart % 100) + (newValue * 100)
                case 1:
                    let ones = integerPart % 10
                    integerPart = (newValue * 10) + ones
                case 0:
                    integerPart = (integerPart / 10) * 10 + newValue
                case -1:
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
