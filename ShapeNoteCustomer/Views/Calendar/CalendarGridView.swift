import SwiftUI
import ShapeCore

struct CalendarGridView: View {
    let calendar: Calendar
    @Binding var currentMonthOffset: Int
    @Binding var selectedDate: Date
    @Binding var slideDirection: AnyTransition
    let weightManager: WeightManager
    let onSwipe: (Int) -> Void
    let onDateTap: (Date) -> Void

    // 見た目チューニング（ここを触れば一括で変わる）
    private let cellHeight: CGFloat = 72           // 少し余裕を増やす（体重＋ドット）
    private let dayCircleSize: CGFloat = 34        // 日付背景の丸
    private let gridSpacing: CGFloat = 12
    private let columnSpacing: CGFloat = 10
    private let dotSize: CGFloat = 6               // 体調ドット径

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

            ZStack {
                let days = generateDays()

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
            }
            .animation(.easeInOut(duration: 0.35), value: currentMonthOffset)
            .contentShape(Rectangle())
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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.gradientCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Theme.dark.opacity(0.08), radius: 10, y: 6)
        )
        .padding(.horizontal, 8)
    }

    // MARK: - Day Cell
    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        if date == Date.distantPast {
            Color.clear
                .frame(height: cellHeight)
        } else {
            let isToday = calendar.isDateInToday(date)
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let hasWeight = (weightManager.weight(on: date) != nil)
            let dayNumber = calendar.component(.day, from: date)

            VStack(spacing: 6) {

                // 日付（丸背景 + 状態）
                Text("\(dayNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(dayTextColor(date: date, isSelected: isSelected))
                    .frame(width: dayCircleSize, height: dayCircleSize)
                    .background(dayBackground(date: date, isSelected: isSelected, hasWeight: hasWeight))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isToday ? Theme.sub.opacity(0.9) : .clear, lineWidth: 2)
                    )
                    .onTapGesture {
                        selectedDate = date
                        onDateTap(date)
                    }

                // 体重（Capsuleバッジ）
                if let w = weightManager.weight(on: date) {
                    weightBadge(text: String(format: "%.1f", w))
                } else {
                    Color.clear.frame(height: 18)
                }

                // 体調ドット（healthがある日のみ表示）
                healthDot(date: date)
            }
            .frame(height: cellHeight)
        }
    }

    private func weightBadge(text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundColor(Theme.dark.opacity(0.80))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.65), in: Capsule())
            .overlay(
                Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .frame(height: 18)
    }

    // ✅ 体調ドット（good/normal/bad -> WeightManager.healthColor）
    @ViewBuilder
    private func healthDot(date: Date) -> some View {
        if let c = weightManager.healthColor(on: date) {
            Circle()
                .fill(c.opacity(0.95))
                .frame(width: dotSize, height: dotSize)
                .overlay(
                    Circle().stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .padding(.top, 1)
                .accessibilityLabel("体調あり")
        } else {
            // ドット行の高さを固定して、セル内のブレをなくす
            Color.clear
                .frame(width: dotSize, height: dotSize)
                .padding(.top, 1)
        }
    }

    private func dayBackground(date: Date, isSelected: Bool, hasWeight: Bool) -> some View {
        if isSelected {
            return Theme.sub.opacity(0.25)
        }
        if hasWeight {
            return Theme.accent.opacity(0.18)
        }
        // 同月以外は薄く
        if !isSameMonth(date) {
            return Color.white.opacity(0.35)
        }
        return Color.white.opacity(0.55)
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
        // Sunday: warning（赤系） / Saturday: sub（ブランドグリーン）
        if index == 0 { return Theme.warning.opacity(0.95) }
        if index == 6 { return Theme.sub.opacity(0.95) }
        return Theme.dark.opacity(0.70)
    }
}
