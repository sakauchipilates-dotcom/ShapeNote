import SwiftUI
import ShapeCore

// MARK: - health ペイロード（{"level":"normal","markers":["jogging"]}）

private struct HealthPayload: Codable {
    let level: String
    let markers: [String]
}

// 5段階体調レベル（色だけ使う）
private enum HealthLevel5: String {
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
}

struct CalendarGridView: View {
    let calendar: Calendar
    @Binding var currentMonthOffset: Int
    @Binding var selectedDate: Date
    @Binding var slideDirection: AnyTransition
    let weightManager: WeightManager
    let onSwipe: (Int) -> Void
    let onDateTap: (Date) -> Void

    // MARK: - Layout constants

    private let cellHeight: CGFloat = 65
    private let gridSpacing: CGFloat = 10
    private let columnSpacing: CGFloat = 10
    private let capsuleWidth: CGFloat = 42
    private let capsuleHeight: CGFloat = 65
    private let capsuleCornerRadius: CGFloat = 10

    // カスタムマーク用
    private let markerIconSize: CGFloat = 11
    private let markerSpacing: CGFloat = 4
    private let markerHorizontalOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {

            // 曜日ヘッダー
            HStack {
                ForEach(Array(calendar.shortWeekdaySymbols.enumerated()), id: \.offset) { idx, day in
                    Text(day)
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(weekdayColor(index: idx))
                }
            }
            .padding(.horizontal, 4)

            let days = generateDays()

            // 日付グリッド
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: columnSpacing), count: 7),
                spacing: gridSpacing
            ) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    dayCell(date)
                }
            }
            .id(currentMonthOffset)
            .transition(slideDirection)
            .animation(.easeInOut(duration: 0.35), value: currentMonthOffset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.width < -50 { onSwipe(1) }
                        else if value.translation.width > 50 { onSwipe(-1) }
                    }
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.gradientCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Theme.dark.opacity(0.08), radius: 10, y: 6)
        )
        .padding(.horizontal, 8)
    }

    // MARK: - Multi-record helpers

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = .init(identifier: "ja_JP")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func records(for day: Date) -> [WeightRecord] {
        let key = dayKey(day)
        return weightManager.weights
            .filter { dayKey($0.date) == key }
            .sorted {
                let l = $0.recordedAt ?? $0.date
                let r = $1.recordedAt ?? $1.date
                return l > r
            }
    }

    private func latestRecord(for day: Date) -> WeightRecord? {
        records(for: day).first
    }

    private func decodePayload(from raw: String) -> HealthPayload? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(HealthPayload.self, from: data)
    }

    // MARK: - Day Cell

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        if date == Date.distantPast {
            Color.clear
                .frame(height: cellHeight)
        } else {
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let dayNumber = calendar.component(.day, from: date)

            let dayRecords = records(for: date)
            let hasAnyRecord = !dayRecords.isEmpty
            let latest = latestRecord(for: date)

            Button {
                selectedDate = date
                onDateTap(date)
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: capsuleCornerRadius, style: .continuous)
                        .fill(dayBackground(date: date, isSelected: isSelected, hasAnyRecord: hasAnyRecord, latest: latest))

                    VStack(spacing: 4) {
                        Text("\(dayNumber)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(dayTextColor(date: date, isSelected: isSelected))

                        // 体重：最新レコードの値
                        if let w = latest?.weight {
                            Text(String(format: "%.1f", w))
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                                .foregroundColor(Theme.dark.opacity(0.80))
                        } else {
                            Spacer().frame(height: 12)
                        }

                        markerRow(for: date, records: dayRecords)
                            .frame(height: 14)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 6)
                }
                .frame(width: capsuleWidth, height: capsuleHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: capsuleCornerRadius, style: .continuous)
                        .stroke(isSelected ? Theme.sub.opacity(0.9) : .clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .frame(height: cellHeight)
        }
    }

    // MARK: - Marker Row (同一日の全レコードから union)

    @ViewBuilder
    private func markerRow(for date: Date, records: [WeightRecord]) -> some View {
        let keys = markersForDay(records: records)

        if keys.isEmpty {
            Color.clear
        } else {
            HStack(spacing: markerSpacing) {
                ForEach(Array(keys.prefix(2)), id: \.self) { key in
                    if let symbol = markerSymbol(for: key) {
                        Image(systemName: symbol.name)
                            .font(.system(size: markerIconSize, weight: .semibold))
                            .foregroundColor(symbol.color)
                            .frame(width: markerIconSize, height: markerIconSize, alignment: .center)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .offset(x: markerHorizontalOffset)
        }
    }

    private func markersForDay(records: [WeightRecord]) -> [String] {
        var set = Set<String>()

        for r in records {
            if let raw = r.health, let payload = decodePayload(from: raw) {
                payload.markers.forEach { set.insert($0) }
            }
            if r.isMenstruation {
                set.insert("menstruation")
            }
        }

        // 表示順は安定させる（同じ日に追加しても並びが暴れない）
        return Array(set).sorted()
    }

    // MARK: - Health Level for background

    private func healthLevel(latest: WeightRecord?) -> HealthLevel5? {
        guard let latest else { return nil }

        if let raw = latest.health, let payload = decodePayload(from: raw),
           let level = HealthLevel5(rawValue: payload.level) {
            return level
        }

        // 旧データ（"normal" など直入れ）
        if let raw = latest.health, let level = HealthLevel5(rawValue: raw) {
            return level
        }

        return nil
    }

    // MARK: - Marker symbols

    private func markerSymbol(for key: String) -> (name: String, color: Color)? {
        switch key {
        case "menstruation":
            return ("heart.fill", Color.pink.opacity(0.9))
        case "jogging":
            return ("figure.run", Theme.accent)
        case "training":
            return ("dumbbell.fill", Theme.sub)
        case "pilates_yoga":
            return ("figure.mind.and.body", Theme.accent.opacity(0.95))
        case "lesson":
            return ("person.2.fill", Theme.accent.opacity(0.9))
        case "study":
            return ("book.fill", Theme.dark.opacity(0.75))
        default:
            return nil
        }
    }

    // MARK: - Appearance utilities

    private func dayBackground(date: Date, isSelected: Bool, hasAnyRecord: Bool, latest: WeightRecord?) -> Color {
        if isSelected {
            return Theme.sub.opacity(0.25)
        }

        let inMonth = isSameMonth(date)

        if let level = healthLevel(latest: latest) {
            let base = level.color
            return inMonth ? base : base.opacity(0.4)
        }

        if hasAnyRecord {
            return Theme.accent.opacity(inMonth ? 0.18 : 0.08)
        }

        if !inMonth {
            return Color.white.opacity(0.35)
        }

        return Color.white
    }

    private func dayTextColor(date: Date, isSelected: Bool) -> Color {
        if isSelected { return Theme.dark.opacity(0.90) }
        if !isSameMonth(date) { return Theme.dark.opacity(0.35) }
        return Theme.dark.opacity(0.85)
    }

    // MARK: - Month days

    private func generateDays() -> [Date] {
        let base = calendar.date(byAdding: .month, value: currentMonthOffset, to: Date()) ?? Date()

        guard let range = calendar.range(of: .day, in: .month, for: base),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: base))
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay)

        var days: [Date] = Array(repeating: Date.distantPast, count: max(firstWeekday - 1, 0))
        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(d)
            }
        }
        return days
    }

    private func isSameMonth(_ date: Date) -> Bool {
        let current = calendar.date(byAdding: .month, value: currentMonthOffset, to: Date()) ?? Date()
        return calendar.isDate(date, equalTo: current, toGranularity: .month)
    }

    private func weekdayColor(index: Int) -> Color {
        if index == 0 { return Theme.warning.opacity(0.95) } // Sun
        if index == 6 { return Theme.sub.opacity(0.95) }     // Sat
        return Theme.dark.opacity(0.70)
    }
}
