import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore
import ShapeCore
import Combine

struct MyPageView: View {
    @EnvironmentObject var appState: CustomerAppState
    @EnvironmentObject var imageVM: ProfileImageVM
    private let auth = AuthHandler.shared
    @State private var visitCount: Int = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // 🪪 会員カード（左右余白を統一）
                    MembershipCardView()
                        .environmentObject(imageVM)
                        .padding(.horizontal, 16) // ✅ 下UIと揃える

                    // 📋 メニュー
                    menuSection
                }
                .padding(.top, 16)
                .task { await fetchVisitCount() } // ← Firestoreから来店回数を取得
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
        }
    }

    // MARK: - メニュー
    private var menuSection: some View {
        VStack(spacing: 0) {

            NavigationLink(destination: CouponListView()) {
                Label("クーポン一覧", systemImage: "ticket")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            Divider()

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

            NavigationLink(destination: InfoContactView()) {
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
    }

    // MARK: - Firestoreから来店回数を取得
    private func fetchVisitCount() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if let count = doc.data()?["visitCount"] as? Int {
                await MainActor.run { visitCount = count }
            }
        } catch {
            print("❌ 来店回数の取得に失敗: \(error.localizedDescription)")
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
