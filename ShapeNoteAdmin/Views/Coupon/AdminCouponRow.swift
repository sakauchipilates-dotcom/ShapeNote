import SwiftUI

struct AdminCouponRow: View {
    let coupon: CouponManagerVM.AdminCoupon
    let onEdit: () -> Void
    let onToggleUsed: (Bool) -> Void
    let onDelete: () -> Void

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

                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(statusBg))
                    .foregroundColor(statusFg)
            }

            HStack {
                Text("有効期限")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(CouponManagerVM.jpDateFormatter.string(from: coupon.validUntil))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            if coupon.isUsed {
                HStack {
                    Text("使用日")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(coupon.usedAt.map { CouponManagerVM.jpDateFormatter.string(from: $0) } ?? "—")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button {
                    onEdit()
                } label: {
                    Label("編集", systemImage: "pencil")
                }
                .buttonStyle(.bordered)

                Button {
                    onToggleUsed(!coupon.isUsed)
                } label: {
                    Label(coupon.isUsed ? "未使用に戻す" : "使用済みにする",
                          systemImage: coupon.isUsed ? "arrow.uturn.backward" : "checkmark.seal")
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var statusText: String {
        if coupon.isUsed { return "使用済み" }
        if coupon.isExpired { return "期限切れ" }
        return "未使用"
    }

    private var statusBg: Color {
        if coupon.isUsed { return Color.gray.opacity(0.15) }
        if coupon.isExpired { return Color.orange.opacity(0.15) }
        return Color.green.opacity(0.15)
    }

    private var statusFg: Color {
        if coupon.isUsed { return .gray }
        if coupon.isExpired { return .orange }
        return .green
    }
}
