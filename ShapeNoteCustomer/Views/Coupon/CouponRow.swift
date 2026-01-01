import SwiftUI

struct CouponRow: View {
    enum Mode { case available, used }

    let coupon: CouponListVM.Coupon
    let mode: Mode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 10) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(coupon.title)
                        .font(.headline)

                    if !coupon.description.isEmpty {
                        Text(coupon.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Text(coupon.isUsed ? "使用済み" : "未使用")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            coupon.isUsed ? Color.gray.opacity(0.15) : Color.green.opacity(0.15)
                        )
                    )
                    .foregroundColor(coupon.isUsed ? .gray : .green)
            }

            HStack {
                if mode == .used {
                    Text("使用日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(usedDateText)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                } else {
                    Text("有効期限")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatJPDate(coupon.validUntil))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
        .padding(.vertical, 8)
    }

    private var usedDateText: String {
        if let usedAt = coupon.usedAt {
            return formatJPDate(usedAt)
        }
        return "—"
    }

    // MARK: - 日付表示（yyyy年M月d日 に統一）
    private func formatJPDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }
}
