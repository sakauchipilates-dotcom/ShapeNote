import SwiftUI
import FirebaseAuth

struct CouponManagerView: View {
    @StateObject private var vm = CouponManagerVM()
    @FocusState private var focusedField: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Group {
                        TextField("対象ユーザーID（顧客UID）", text: $vm.selectedUserId)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        TextField("クーポンタイトル", text: $vm.title)
                            .textFieldStyle(.roundedBorder)

                        TextField("説明文", text: $vm.description)
                            .textFieldStyle(.roundedBorder)

                        DatePicker("有効期限", selection: $vm.validUntil, displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                    .padding(.horizontal)

                    if vm.isCreating {
                        ProgressView("発行中…")
                    } else {
                        Button("クーポンを発行") {
                            Task { await vm.createCoupon(for: vm.selectedUserId) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.selectedUserId.isEmpty || vm.title.isEmpty)
                    }

                    if !vm.message.isEmpty {
                        Text(vm.message)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    Divider()

                    // 配布済み一覧
                    if !vm.distributedCoupons.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("発行済みクーポン一覧")
                                .font(.headline)
                            ForEach(vm.distributedCoupons) { coupon in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(coupon.title).font(.headline)
                                    Text(coupon.description)
                                    Text("有効期限: \(coupon.validUntil.formatted(date: .abbreviated, time: .omitted))")
                                    Text(coupon.isUsed ? "✅ 使用済み" : "🟢 未使用")
                                        .foregroundColor(coupon.isUsed ? .gray : .green)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                            }

                            Button(role: .destructive) {
                                Task { await vm.deleteCoupon(for: vm.selectedUserId) }
                            } label: {
                                Label("クーポン削除", systemImage: "trash")
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .navigationTitle("クーポン管理")
        }
    }
}
