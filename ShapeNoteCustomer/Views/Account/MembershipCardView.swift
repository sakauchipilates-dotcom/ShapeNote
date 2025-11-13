import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import ShapeCore

struct MembershipCardView: View {
    @EnvironmentObject var imageVM: ProfileImageVM
    @State private var displayId: String = "—"
    @State private var visitCount: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            // タイトル
            HStack {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)
                Text("会員カード")
                    .font(.title3.bold())
                Spacer()
            }

            // カード本体
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    // 左：ユーザー情報
                    VStack(alignment: .leading, spacing: 8) {
                        Text(displayName)
                            .font(.title3.bold())

                        HStack(spacing: 8) {
                            Text("RANK:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(rankLabel)
                                .font(.subheadline.weight(.semibold))
                        }

                        Text("来店回数: \(visitCount) 回")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // ✅ UID非表示 → 独自IDに変更
                        Text("会員ID：\(displayId)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    // 右：プロフィール画像
                    Button { imageVM.isPickerPresented = true } label: {
                        ZStack {
                            if let url = imageVM.iconURL {
                                let refreshedURL = URL(string: url.absoluteString + "?t=\(Date().timeIntervalSince1970)")!
                                AsyncImage(url: refreshedURL) { phase in
                                    switch phase {
                                    case .empty:
                                        ProgressView().frame(width: 70, height: 70)
                                    case .success(let img):
                                        img.resizable()
                                            .scaledToFill()
                                            .frame(width: 70, height: 70)
                                            .clipShape(Circle())
                                    case .failure:
                                        Image(systemName: "person.crop.circle.badge.exclam")
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 70, height: 70)
                                            .foregroundColor(.gray.opacity(0.6))
                                    @unknown default:
                                        EmptyView().frame(width: 70, height: 70)
                                    }
                                }
                                .id(refreshedURL.absoluteString)
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 70, height: 70)
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                        }
                        .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                    }
                }
            }
            .padding()
            .background(rankBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 1)
        }
        .task {
            await loadUserData()
        }
    }

    // MARK: - Firestoreから表示ID・来店回数取得
    private func loadUserData() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if let data = doc.data() {
                await MainActor.run {
                    displayId = data["displayId"] as? String ?? "未設定"
                    visitCount = data["visitCount"] as? Int ?? 0
                }
            }
        } catch {
            print("❌ ユーザーデータの取得に失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - 表示補助
    private var displayName: String {
        if !imageVM.name.isEmpty { return imageVM.name }
        return Auth.auth().currentUser?.displayName ?? "ゲスト"
    }

    private var rankLabel: String {
        imageVM.membershipRank.isEmpty ? "—" : imageVM.membershipRank
    }

    private var rankBackground: Color {
        switch imageVM.membershipRank {
        case "Gold":   return Color.yellow.opacity(0.18)
        case "Silver": return Color.gray.opacity(0.18)
        case "Bronze": return Color.brown.opacity(0.18)
        default:       return Color(.secondarySystemBackground)
        }
    }
}
