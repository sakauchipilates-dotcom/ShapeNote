import SwiftUI
import FirebaseAuth

struct CouponListView: View {
    @StateObject private var vm = CouponListVM()

    var body: some View {
        NavigationView {
            VStack {
                if vm.coupons.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "ticket")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("現在ご利用可能なクーポンはありません。")
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 100)
                } else {
                    List(vm.coupons) { coupon in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(coupon.title)
                                .font(.headline)
                            Text(coupon.description)
                                .font(.subheadline)
                            Text("有効期限: \(coupon.validUntil.formatted(date: .abbreviated, time: .omitted))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Text(coupon.isUsed ? "✅ 使用済み" : "🟢 未使用")
                                .font(.footnote)
                                .foregroundColor(coupon.isUsed ? .gray : .green)
                        }
                        .padding(.vertical, 6)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("クーポン一覧")
            .task { await vm.fetchCoupons() }
        }
    }
}
