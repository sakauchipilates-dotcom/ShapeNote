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

    // MARK: - Layout constants (固定値)

    /// 行全体の高さ（カプセル＋余白）
    private let cellHeight: CGFloat = 65

    /// 行と行の間
    private let gridSpacing: CGFloat = 10

    /// 列と列の間
    private let columnSpacing: CGFloat = 10

    /// 日付カプセルのサイズ（絶対にここだけを使う）
    private let capsuleWidth: CGFloat = 42
    private let capsuleHeight: CGFloat = 65

    /// 角丸
    private let capsuleCornerRadius: CGFloat = 10

    // MARK: - 体調／生理アイコン用レイアウト定数（微調整用）

    /// 顔アイコンのサイズ
    private let healthIconSize: CGFloat = 11

    /// 生理リングのサイズ
    private let phaseIconSize: CGFloat = 11

    /// 顔アイコンとリングの間隔
    private let healthPhaseSpacing: CGFloat = 4

    /// 行全体の横方向オフセット（生理リングが右寄り / 左寄りに見える場合はここを調整）
    /// 例: 少し左に寄せたい → -2, 右に寄せたい → +2
    private let healthPhaseHorizontalOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {

            // MARK: - 曜日ヘッダー
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

            // MARK: - 日付グリッド
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
                        if value.translation.width < -50 {
                            onSwipe(1)
                        } else if value.translation.width > 50 {
                            onSwipe(-1)
                        }
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

    // MARK: - Day Cell

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        if date == Date.distantPast {
            Color.clear
                .frame(height: cellHeight)
        } else {
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let hasWeight = (weightManager.weight(on: date) != nil)
            let dayNumber = calendar.component(.day, from: date)

            Button {
                selectedDate = date
                onDateTap(date)
            } label: {
                ZStack {
                    // 背景カプセル（サイズ固定）
                    RoundedRectangle(cornerRadius: capsuleCornerRadius, style: .continuous)
                        .fill(dayBackground(date: date, isSelected: isSelected, hasWeight: hasWeight))

                    VStack(spacing: 4) {
                        // 日付
                        Text("\(dayNumber)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(dayTextColor(date: date, isSelected: isSelected))

                        // 体重 or ダミー
                        if let w = weightManager.weight(on: date) {
                            Text(String(format: "%.1f", w))
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                                .foregroundColor(Theme.dark.opacity(0.80))
                        } else {
                            Spacer()
                                .frame(height: 12)
                        }

                        // 体調アイコン + 生理リング（高さ固定）
                        healthAndPhaseRow(for: date)
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

    // MARK: - 体調アイコン + 生理リング

    @ViewBuilder
    private func healthAndPhaseRow(for date: Date) -> some View {
        HStack(spacing: healthPhaseSpacing) {
            // 左：体調アイコン（5段階＋従来3段階に対応）
            if let symbol = healthSymbol(for: date) {
                Image(systemName: symbol.name)
                    .font(.system(size: healthIconSize, weight: .semibold))
                    .foregroundColor(symbol.color)
                    .frame(width: healthIconSize, height: healthIconSize, alignment: .center)
            }

            // 右：生理リング
            if weightManager.isMenstruation(on: date) == true {
                Circle()
                    .stroke(Theme.accent, lineWidth: 1.6)
                    .frame(width: phaseIconSize, height: phaseIconSize)
            }
        }
        // カプセル内で中央寄せ（位置を微調整したければ offset をいじる）
        .frame(maxWidth: .infinity, alignment: .center)
        .offset(x: healthPhaseHorizontalOffset)
    }

    /// health フィールド → SF Symbols & 色
    ///
    /// - 5段階ログ想定:
    ///   - "level1" ... "level5"
    /// - 従来:
    ///   - "good" / "normal" / "bad"
    private func healthSymbol(for date: Date) -> (name: String, color: Color)? {
        guard let raw = weightManager.health(on: date) else { return nil }

        // まず "level1"〜"level5" を解釈（5段階）
        if raw.hasPrefix("level"),
           let level = Int(raw.dropFirst("level".count)) {

            switch level {
            case 1: // かなり悪い
                return ("face.dashed", Theme.warning)
            case 2: // やや悪い
                return ("face.dashed", Theme.warning.opacity(0.8))
            case 3: // 普通
                return ("face.smiling", Theme.accent)
            case 4: // 良い
                return ("face.smiling", Theme.sub.opacity(0.9))
            case 5: // かなり良い
                return ("face.smiling", Theme.sub)
            default:
                break
            }
        }

        // 互換：既存の3段階
        switch raw {
        case "good":
            return ("face.smiling", Theme.sub)          // 良い
        case "normal":
            return ("face.smiling", Theme.accent)       // 普通
        case "bad":
            return ("face.dashed", Theme.warning)       // 悪い
        default:
            return nil
        }
    }

    // MARK: - 見た目ユーティリティ

    private func dayBackground(date: Date, isSelected: Bool, hasWeight: Bool) -> Color {
        if isSelected {
            return Theme.sub.opacity(0.25)
        }
        if hasWeight {
            return Theme.accent.opacity(0.18)
        }
        if !isSameMonth(date) {
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
