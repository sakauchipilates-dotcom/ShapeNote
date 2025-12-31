// ChartsCommon.swift

import SwiftUI
import ShapeCore

// MARK: - ChartCard (共通カードUI)
struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    let emptyMessage: String
    let content: () -> Content
    let isEmpty: () -> Bool

    init(
        title: String,
        subtitle: String,
        emptyMessage: String,
        @ViewBuilder content: @escaping () -> Content,
        isEmpty: @escaping () -> Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.emptyMessage = emptyMessage
        self.content = content
        self.isEmpty = isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Theme.dark.opacity(0.92))

                // subtitle が空なら表示しない（余計な "X:..." を消す）
                if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                }
            }

            if isEmpty() {
                Text(emptyMessage)
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.03))
                    )
            } else {
                content()
                    .frame(maxWidth: .infinity, minHeight: 140)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.gradientCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Theme.dark.opacity(0.08), radius: 10, y: 6)
        )
    }
}

// MARK: - Distribution
struct HealthDistribution {
    let counts: [HealthLevel5: Int]

    var totalCount: Int { counts.values.reduce(0, +) }

    var items: [(level: HealthLevel5, count: Int)] {
        HealthLevel5.allCases
            .map { ($0, counts[$0, default: 0]) }
            .filter { $0.1 > 0 }
    }
}

// MARK: - SimpleLineChart
struct SimpleLineChart: View {

    enum XAxisMode: Equatable {
        case none
        case monthly(daysInMonth: Int)   // 5日刻み
        case yearly                      // 1..12
    }

    let points: [CGPoint]
    let xRange: ClosedRange<CGFloat>
    let yPadding: CGFloat
    let unitLabelY: String          // “表示”はしない（目標ラベルで使う）
    let unitLabelX: String          // “表示”はしない
    let goalLineY: CGFloat?
    let xAxisMode: XAxisMode

    init(
        points: [CGPoint],
        xRange: ClosedRange<CGFloat>,
        yPadding: CGFloat,
        unitLabelY: String,
        unitLabelX: String,
        goalLineY: CGFloat?,
        xAxisMode: XAxisMode = .none
    ) {
        self.points = points
        self.xRange = xRange
        self.yPadding = yPadding
        self.unitLabelY = unitLabelY
        self.unitLabelX = unitLabelX
        self.goalLineY = goalLineY
        self.xAxisMode = xAxisMode
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let xs = points.map(\.x)
            let ys = points.map(\.y)

            // X range
            let minX = min(xs.min() ?? xRange.lowerBound, xRange.lowerBound)
            let maxX = max(xs.max() ?? xRange.upperBound, xRange.upperBound)

            // Y range（goalLine を含める）
            let yMinMax: (CGFloat, CGFloat) = {
                var lo = ys.min() ?? 0
                var hi = ys.max() ?? 1
                if let gy = goalLineY {
                    lo = min(lo, gy)
                    hi = max(hi, gy)
                }
                if lo == hi { hi = lo + 1 } // guard
                return (lo, hi)
            }()

            let minY = yMinMax.0
            let maxY = yMinMax.1

            let safeMinY = minY - yPadding
            let safeMaxY = maxY + yPadding

            let denomX = max(maxX - minX, 1)
            let denomY = max(safeMaxY - safeMinY, 0.1)

            let normX: (CGFloat) -> CGFloat = { x in
                (x - minX) / denomX * w
            }
            let normY: (CGFloat) -> CGFloat = { y in
                h - (y - safeMinY) / denomY * h
            }

            let mapped: [CGPoint] = points.map { p in
                CGPoint(x: normX(p.x), y: normY(p.y))
            }

            ZStack {
                // horizontal grid
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.black.opacity(0.04))
                            .frame(height: 1)
                        Spacer()
                    }
                    Rectangle()
                        .fill(Color.black.opacity(0.04))
                        .frame(height: 1)
                }

                // vertical dotted grid (X axis)
                verticalGrid(w: w, h: h, minX: minX, maxX: maxX, normX: normX)

                // goal line
                if let gy = goalLineY {
                    let y = normY(gy)

                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(
                        Color(.systemGreen).opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                    )

                    Text("目標 \(String(format: "%.1f", Double(gy))) \(unitLabelY)")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color(.systemGreen).opacity(0.95))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.06)))
                        .position(x: min(120, w * 0.25), y: max(12, y - 14))
                }

                // line
                if mapped.count >= 2 {
                    Path { p in
                        p.move(to: mapped[0])
                        for pt in mapped.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(Color.black.opacity(0.65), lineWidth: 2)
                }

                // points
                ForEach(Array(mapped.enumerated()), id: \.offset) { _, pt in
                    Circle()
                        .fill(Color.black.opacity(0.75))
                        .frame(width: 4.5, height: 4.5)
                        .position(pt)
                }

                // x-axis tick labels (inside chart bottom)
                xAxisLabels(w: w, h: h, minX: minX, maxX: maxX, normX: normX)
            }
        }
        .padding(6)
    }

    // MARK: - Vertical grid
    @ViewBuilder
    private func verticalGrid(
        w: CGFloat,
        h: CGFloat,
        minX: CGFloat,
        maxX: CGFloat,
        normX: @escaping (CGFloat) -> CGFloat   // ★ここが修正ポイント
    ) -> some View {
        let ticks = xTicks(minX: minX, maxX: maxX)

        ForEach(ticks, id: \.self) { t in
            let x = normX(t)
            Path { p in
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: h))
            }
            .stroke(
                Color.black.opacity(0.10),
                style: StrokeStyle(lineWidth: 1, dash: [3, 6])
            )
        }
    }

    // MARK: - X axis labels
    @ViewBuilder
    private func xAxisLabels(
        w: CGFloat,
        h: CGFloat,
        minX: CGFloat,
        maxX: CGFloat,
        normX: @escaping (CGFloat) -> CGFloat   // ★ここも修正ポイント
    ) -> some View {
        let ticks = xTicks(minX: minX, maxX: maxX)

        let y = h - 10
        ForEach(ticks, id: \.self) { t in
            let x = normX(t)
            Text(xTickLabel(for: t))
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .position(x: x, y: y)
        }
    }

    // MARK: - Tick generation
    private func xTicks(minX: CGFloat, maxX: CGFloat) -> [CGFloat] {
        switch xAxisMode {
        case .none:
            return []

        case .monthly(let daysInMonth):
            let upper = max(1, daysInMonth)
            let base = stride(from: 5, through: upper, by: 5).map { CGFloat($0) }
            return base.filter { $0 >= minX - 0.001 && $0 <= maxX + 0.001 }

        case .yearly:
            return (1...12).map { CGFloat($0) }.filter { $0 >= minX - 0.001 && $0 <= maxX + 0.001 }
        }
    }

    private func xTickLabel(for tick: CGFloat) -> String {
        switch xAxisMode {
        case .none:
            return ""
        case .monthly, .yearly:
            return "\(Int(round(tick)))"
        }
    }
}

// MARK: - Pie chart
struct HealthPieChart: View {
    let distribution: HealthDistribution

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size * 0.32

            HStack(spacing: 14) {
                ZStack {
                    if distribution.totalCount == 0 {
                        Circle()
                            .fill(Color.black.opacity(0.06))
                            .frame(width: radius * 2, height: radius * 2)
                    } else {
                        PieSlices(
                            items: distribution.items,
                            total: distribution.totalCount
                        )
                        .frame(width: radius * 2, height: radius * 2)
                    }
                }
                .frame(width: radius * 2, height: radius * 2)
                .position(x: center.x * 0.60, y: center.y)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(distribution.items, id: \.level) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.level.color)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.black.opacity(0.10), lineWidth: 1))

                            Text(item.level.label)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Theme.dark.opacity(0.82))

                            Spacer()

                            let pct = Double(item.count) / Double(max(distribution.totalCount, 1)) * 100.0
                            Text("\(item.count)  (\(String(format: "%.0f", pct))%)")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
    }
}

private struct PieSlices: View {
    let items: [(level: HealthLevel5, count: Int)]
    let total: Int

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2

            var start = Angle.degrees(-90)

            for item in items {
                let frac = Double(item.count) / Double(max(total, 1))
                let end = start + Angle.degrees(360 * frac)

                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                path.closeSubpath()

                ctx.fill(path, with: .color(item.level.color))
                start = end
            }

            let holeR = radius * 0.55
            var hole = Path()
            hole.addEllipse(
                in: CGRect(
                    x: center.x - holeR,
                    y: center.y - holeR,
                    width: holeR * 2,
                    height: holeR * 2
                )
            )
            ctx.blendMode = .clear
            ctx.fill(hole, with: .color(.clear))
            ctx.blendMode = .normal
        }
    }
}
