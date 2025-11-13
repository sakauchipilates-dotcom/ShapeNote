import SwiftUI

struct CalendarGridView: View {
    let calendar: Calendar
    @Binding var currentMonthOffset: Int
    @Binding var selectedDate: Date
    @Binding var slideDirection: AnyTransition
    let weightManager: WeightManager
    let onSwipe: (Int) -> Void
    let onDateTap: (Date) -> Void  // ← 追加！

    var body: some View {
        VStack(spacing: 12) {
            // 曜日ヘッダー
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .foregroundColor(day == "日" ? .red : (day == "土" ? .blue : .primary))
                }
            }

            ZStack {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                    ForEach(generateDays(), id: \.self) { date in
                        VStack(spacing: 4) {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.body)
                                .foregroundColor(isSameMonth(date) ? .primary : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(dayFill(for: date))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue.opacity(calendar.isDateInToday(date) ? 0.6 : 0), lineWidth: 2)
                                )
                                .onTapGesture {
                                    selectedDate = date
                                    onDateTap(date)  // ← 修正ポイント
                                }

                            if let w = weightManager.weight(on: date) {
                                Text(String(format: "%.1f", w))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .frame(height: 12)
                            } else {
                                Text(" ")
                                    .font(.caption2)
                                    .frame(height: 12)
                            }
                        }
                        .frame(height: 52)
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
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .shadow(color: .gray.opacity(0.15), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 8)
    }

    private func generateDays() -> [Date] {
        let base = calendar.date(byAdding: .month, value: currentMonthOffset, to: Date())!
        guard let range = calendar.range(of: .day, in: .month, for: base),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: base)) else {
            return []
        }
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
        let current = calendar.date(byAdding: .month, value: currentMonthOffset, to: Date())!
        return calendar.isDate(date, equalTo: current, toGranularity: .month)
    }

    private func dayFill(for date: Date) -> Color {
        if calendar.isDateInToday(date) {
            return Color.blue.opacity(0.15)
        } else if weightManager.weight(on: date) != nil {
            return Color.blue.opacity(0.08)
        } else {
            return Color.gray.opacity(0.05)
        }
    }
}
