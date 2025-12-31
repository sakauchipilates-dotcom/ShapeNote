import SwiftUI
import ShapeCore

/// 年別チャートは後で実装する前提のプレースホルダ
struct YearlyWeightPlaceholder: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.secondary)

            Text("年別表示は準備中です。")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("まずは月別で推移を確認できます。")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.85))
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}
