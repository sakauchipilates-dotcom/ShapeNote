import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import ShapeCore

private struct HealthPayload: Codable {
    let level: String
    let markers: [String]
}

private enum HealthLevel5: String, CaseIterable {
    case veryBad, bad, normal, good, great

    var color: Color {
        switch self {
        case .veryBad: return Theme.warning.opacity(0.35)
        case .bad:     return Theme.warning.opacity(0.22)
        case .normal:  return Theme.accent.opacity(0.18)
        case .good:    return Theme.sub.opacity(0.20)
        case .great:   return Theme.sub.opacity(0.28)
        }
    }

    var label: String {
        switch self {
        case .veryBad: return "とても悪い"
        case .bad: return "悪い"
        case .normal: return "ふつう"
        case .good: return "良い"
        case .great: return "とても良い"
        }
    }
}

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

struct WeightInputSheet: View {
    var date: Date
    @Binding var isPresented: Bool

    var existingWeight: Double? = nil
    var goalWeight: Double? = nil
    var existingCondition: String? = nil
    var existingHealth: String? = nil
    var existingIsMenstruation: Bool? = nil

    /// ★追加：編集対象の recordId（新規なら nil）
    var editingRecordId: String? = nil

    /// ★追加：編集時に時刻を引き継ぐための初期値
    var initialRecordedAt: Date = Date()

    /// ★変更：onSave に editingRecordId を渡す
    var onSave: (Date, Double, String, String?, Bool, Date, String?) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var inputWeight: Double = 0.0
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
        onSave: @escaping (Date, Double, String, String?, Bool, Date, String?) -> Void,
        onDelete: (() -> Void)? = nil
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
        self.onDelete = onDelete
        _editingDate = State(initialValue: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(editingRecordId == nil ? "体重を記録" : "記録を編集")
                        .font(.title2.bold())
                        .padding(.top, 16)

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
                        }
                    }
                    .padding(.horizontal)

                    SlotPicker(inputWeight: $inputWeight)
                        .padding(.top, 4)

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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("体調（必須）")
                            .font(.subheadline.bold())
                            .foregroundColor(.gray)

                        HStack(spacing: 12) {
                            ForEach(HealthLevel5.allCases, id: \.self) { level in
                                VStack(spacing: 6) {
                                    Button { selectedHealth = level } label: {
                                        Circle()
                                            .fill(level.color)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        selectedHealth == level
                                                        ? Color.green.opacity(0.9)
                                                        : Color.gray.opacity(0.3),
                                                        lineWidth: selectedHealth == level ? 2 : 1
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("カスタムマーク（任意・最大2つ）")
                            .font(.subheadline.bold())
                            .foregroundColor(.gray)

                        let columns = [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ]

                        LazyVGrid(columns: columns, spacing: 8) {
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
                    .background(Color.green.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)

                    if editingRecordId != nil {
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
                if let existing = existingWeight {
                    inputWeight = existing
                } else if let goal = goalWeight {
                    inputWeight = goal
                } else {
                    inputWeight = 50.0
                }

                if let cond = existingCondition {
                    selectedCondition = cond
                }

                loadExistingHealth()

                editingDate = date

                // ★編集なら既存時刻を引き継ぐ（新規は現在時刻）
                recordTime = (editingRecordId == nil) ? Date() : initialRecordedAt
            }
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

    private func loadExistingHealth() {
        var initialLevel: HealthLevel5 = .normal
        var initialMarkers: Set<String> = []

        if let raw = existingHealth,
           let data = raw.data(using: .utf8),
           let payload = try? JSONDecoder().decode(HealthPayload.self, from: data) {
            if let level = HealthLevel5(rawValue: payload.level) { initialLevel = level }
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
            .background(Capsule().fill(isSelected ? Color.green.opacity(0.12) : Color.white))
            .overlay(
                Capsule().stroke(isSelected ? Color.green.opacity(0.8) : Color.gray.opacity(0.3), lineWidth: 1)
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
            .background(Capsule().fill(isSelected ? Color.green.opacity(0.12) : Color.white))
            .overlay(
                Capsule().stroke(isSelected ? Color.green.opacity(0.8) : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

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
            ForEach(Array(digits.enumerated()), id: \.offset) { index, value in
                pickerColumn(value: value, place: digits.count - index - 1)
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
