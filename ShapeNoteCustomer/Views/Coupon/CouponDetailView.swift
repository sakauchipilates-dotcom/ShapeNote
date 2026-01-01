import SwiftUI

struct CouponDetailView: View {
    let coupon: CouponListVM.Coupon
    @ObservedObject var vm: CouponListVM

    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmUse = false
    @State private var showResultAlert = false
    @State private var resultMessage = ""

    var body: some View {
        VStack(spacing: 14) {
            headerCard

            detailCard

            Spacer()

            if coupon.isUsed {
                // 使用済みの場合は操作不可
                Text("このクーポンは使用済みです。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
            } else if coupon.isExpired {
                Text("このクーポンは期限切れです。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)
            } else {
                useButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 18)
            }
        }
        .padding(.top, 16)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("クーポン詳細")
        .navigationBarTitleDisplayMode(.inline)
        .alert("確認", isPresented: $showConfirmUse) {
            Button("キャンセル", role: .cancel) {}
            Button("使用済みにする", role: .destructive) {
                Task { await handleUse() }
            }
        } message: {
            Text("このクーポンを使用済みにしますか？\n（この操作は取り消せません）")
        }
        .alert("通知", isPresented: $showResultAlert) {
            Button("OK") {
                // 一覧に戻す（必要なら残すでもOK）
                dismiss()
            }
        } message: {
            Text(resultMessage)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.secondary)

                Text(coupon.title)
                    .font(.title3.bold())

                Spacer()

                Text(coupon.isUsed ? "使用済み" : "未使用")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(coupon.isUsed ? Color.gray.opacity(0.15) : Color.green.opacity(0.15)))
                    .foregroundColor(coupon.isUsed ? .gray : .green)
            }

            if !coupon.description.isEmpty {
                Text(coupon.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
    }

    private var detailCard: some View {
        VStack(spacing: 12) {
            row(title: "有効期限", value: formatJPDate(coupon.validUntil))

            if coupon.isUsed {
                row(
                    title: "使用日",
                    value: coupon.usedAt.map { formatJPDate($0) } ?? "—"
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .padding(.horizontal, 16)
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
        }
    }

    private var useButton: some View {
        Button {
            showConfirmUse = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.red)
                    .frame(height: 52)

                if vm.isUpdatingUseState {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("使用する")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(vm.isUpdatingUseState)
        .accessibilityLabel("クーポンを使用する")
    }

    private func handleUse() async {
        do {
            try await vm.markCouponUsed(coupon)
            resultMessage = "使用済みにしました。"
        } catch {
            resultMessage = "使用処理に失敗しました: \(error.localizedDescription)"
        }
        showResultAlert = true
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
