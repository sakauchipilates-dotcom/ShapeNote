import SwiftUI

struct CouponListView: View {
    @StateObject private var vm = CouponListVM()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                Picker("", selection: $vm.selectedTab) {
                    Text("未使用クーポン").tag(CouponListVM.Tab.available)
                    Text("使用済みクーポン").tag(CouponListVM.Tab.used)
                    Text("回数券").tag(CouponListVM.Tab.passes)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)

                headerSummary
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                content
            }
            .navigationTitle("クーポン")
            .navigationBarTitleDisplayMode(.inline)
            .task { await vm.fetchCoupons() }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var headerSummary: some View {
        HStack {
            switch vm.selectedTab {
            case .available:
                Text("利用可能")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(vm.availableCount) 枚")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)

            case .used:
                Text("使用済み")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(vm.usedCount) 枚")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)

            case .passes:
                Text("回数券")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text("—")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            ProgressView("読み込み中…")
                .tint(.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 60)

        } else if let err = vm.errorMessage {
            Text("⚠️ \(err)")
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 60)

        } else {
            switch vm.selectedTab {
            case .available:
                couponListAvailable(vm.availableCoupons)

            case .used:
                couponListUsed(vm.usedCoupons)

            case .passes:
                emptyState(icon: "rectangle.stack.badge.person.crop", text: "回数券は準備中です。")
            }
        }
    }

    // MARK: - Available list (tap -> detail)
    @ViewBuilder
    private func couponListAvailable(_ coupons: [CouponListVM.Coupon]) -> some View {
        if coupons.isEmpty {
            emptyState(icon: "ticket", text: "現在ご利用可能なクーポンはありません。")
        } else {
            List(coupons) { coupon in
                NavigationLink {
                    CouponDetailView(coupon: coupon, vm: vm)
                } label: {
                    CouponRow(coupon: coupon, mode: .available)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 10)
        }
    }

    // MARK: - Used list (tap -> detail read-only)
    @ViewBuilder
    private func couponListUsed(_ coupons: [CouponListVM.Coupon]) -> some View {
        if coupons.isEmpty {
            emptyState(icon: "ticket", text: "使用済みのクーポンはありません。")
        } else {
            List(coupons) { coupon in
                NavigationLink {
                    CouponDetailView(coupon: coupon, vm: vm)
                } label: {
                    CouponRow(coupon: coupon, mode: .used)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 10)
        }
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(.gray.opacity(0.7))
            Text(text)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 90)
    }
}
