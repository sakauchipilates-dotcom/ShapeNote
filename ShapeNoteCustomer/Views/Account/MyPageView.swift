import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import ShapeCore
import Combine

struct MyPageView: View {
    @EnvironmentObject var appState: CustomerAppState
    @EnvironmentObject var imageVM: ProfileImageVM
    private let auth = AuthHandler.shared

    @State private var availableCouponCount: Int = 0
    @State private var isLoadingCoupons: Bool = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {

                    // 🪪 会員カード
                    MembershipCardView()
                        .environmentObject(imageVM)
                        .padding(.horizontal, 16)

                    // 🟩 クーポン枠（会員カードの下）
                    couponQuickCard
                        .padding(.horizontal, 16)

                    // 📋 メニュー
                    menuSection
                }
                .padding(.top, 16)
            }
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $imageVM.isPickerPresented) {
                ImagePicker(
                    selectedImage: $imageVM.selectedImage,
                    onImagePicked: imageVM.uploadIcon
                )
            }
            .task {
                await fetchAvailableCouponCount()
            }
        }
    }

    // MARK: - クーポン枠（大きく押しやすい）
    private var couponQuickCard: some View {
        NavigationLink(destination: CouponListView()) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(couponGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Theme.dark.opacity(0.10), radius: 10, y: 6)

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 46, height: 46)

                        Image(systemName: "ticket.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.92))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("クーポン")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)

                        Text(isLoadingCoupons ? "読み込み中…" : "利用可能 \(availableCouponCount) 枚")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color.white.opacity(0.92))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.85))
                }
                .padding(16)
            }
            .frame(height: 86)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("クーポン一覧へ")
    }

    private var couponGradient: LinearGradient {
        LinearGradient(
            colors: [
                Theme.sub.opacity(0.95),
                Theme.sub.opacity(0.70)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - メニュー（指定順）
    // ・会員情報
    // ・来店履歴
    // ・お問い合わせ（←ここに「チャット」も集約）
    // ・バージョン情報
    // ・ログアウト
    private var menuSection: some View {
        VStack(spacing: 0) {

            NavigationLink(destination: MemberInfoView()) {
                Label("会員情報", systemImage: "person.text.rectangle")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            Divider()

            NavigationLink(destination: VisitHistoryView()) {
                Label("来店履歴", systemImage: "clock")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            Divider()

            // ✅ 旧：InfoContactView 直行 → 新：お問い合わせハブ（お問い合わせ + 管理者チャット）
            NavigationLink(destination: InquiryHubView()) {
                Label("お問い合わせ", systemImage: "envelope")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            Divider()

            NavigationLink(destination: VersionInfoView()) {
                Label("バージョン情報", systemImage: "info.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            Divider()

            Button {
                auth.signOut()
                appState.setLoggedIn(false)
            } label: {
                Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .foregroundColor(.red)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 1)
        .padding(.horizontal)
        .padding(.top, 6)
    }

    // MARK: - Firestore：利用可能クーポン数
    private func fetchAvailableCouponCount() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            await MainActor.run {
                availableCouponCount = 0
                isLoadingCoupons = false
            }
            return
        }

        do {
            await MainActor.run { isLoadingCoupons = true }

            let itemsSnap = try await Firestore.firestore()
                .collection("coupons")
                .document(uid)
                .collection("items")
                .getDocuments()

            if !itemsSnap.documents.isEmpty {
                let now = Date()
                let count = itemsSnap.documents.reduce(0) { partial, doc in
                    let d = doc.data()
                    let isUsed = d["isUsed"] as? Bool ?? false
                    let validUntil = (d["validUntil"] as? Timestamp)?.dateValue() ?? Date.distantPast
                    let isAvailable = (!isUsed && validUntil >= now)
                    return partial + (isAvailable ? 1 : 0)
                }

                await MainActor.run {
                    availableCouponCount = count
                    isLoadingCoupons = false
                }
                return
            }

            let doc = try await Firestore.firestore()
                .collection("coupons")
                .document(uid)
                .getDocument()

            if let data = doc.data() {
                let isUsed = data["isUsed"] as? Bool ?? false
                let validUntil = (data["validUntil"] as? Timestamp)?.dateValue() ?? Date.distantPast
                let isAvailable = (!isUsed && validUntil >= Date())

                await MainActor.run {
                    availableCouponCount = isAvailable ? 1 : 0
                    isLoadingCoupons = false
                }
            } else {
                await MainActor.run {
                    availableCouponCount = 0
                    isLoadingCoupons = false
                }
            }
        } catch {
            print("❌ 利用可能クーポン数の取得に失敗: \(error.localizedDescription)")
            await MainActor.run {
                availableCouponCount = 0
                isLoadingCoupons = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        MyPageView()
            .environmentObject(CustomerAppState())
            .environmentObject(ProfileImageVM())
    }
}
