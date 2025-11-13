import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AdminListView: View {
    @State private var admins: [AdminRow] = []
    @State private var currentUserIsDeveloper = false
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showToast = false
    @State private var toastMessage = ""

    private let db = Firestore.firestore()
    private let roles = ["一般", "管理者", "開発者"]

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("管理者一覧")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)

                if isLoading {
                    ProgressView("読み込み中…")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if let errorText {
                    Text(errorText)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach($admins) { $admin in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(admin.name)
                                                .font(.headline)
                                            Text(admin.email)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Picker("", selection: $admin.role) {
                                            ForEach(roles, id: \.self) { Text($0).tag($0) }
                                        }
                                        .pickerStyle(.menu)
                                        .disabled(!currentUserIsDeveloper || admin.isDeveloper)
                                        .onChange(of: admin.role) { newRole in
                                            updateRole(for: admin.id, to: newRole)
                                        }
                                    }

                                    Divider()
                                        .background(Color(.systemGray5))
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 16)
                    }
                }
            }

            // ✅ トースト表示
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.subheadline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .padding(.bottom, 40)
                        .transition(.opacity)
                }
            }
        }
        .onAppear(perform: loadData)
        .animation(.easeInOut, value: showToast)
    }

    // MARK: - Firestore I/O
    private func loadData() {
        guard let user = Auth.auth().currentUser else {
            errorText = "ログイン情報が見つかりません。"
            isLoading = false
            return
        }
        db.collection("admins").document(user.uid).getDocument { snap, err in
            if let err { self.errorText = err.localizedDescription; self.isLoading = false; return }
            let role = (snap?.data()?["role"] as? String) ?? "一般"
            self.currentUserIsDeveloper = (role == "開発者")

            db.collection("admins").getDocuments { qs, err in
                if let err { self.errorText = err.localizedDescription; self.isLoading = false; return }
                let allAdmins = qs?.documents.compactMap { doc -> AdminRow? in
                    let data = doc.data()
                    let name = (data["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let email = (data["email"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let role = data["role"] as? String ?? "一般"

                    // 🚫 (no name)・空文字・null を除外
                    if name.isEmpty || name.lowercased() == "(no name)" {
                        // Firestoreからも削除したい場合はこのコメントを外す
                        /*
                        db.collection("admins").document(doc.documentID).delete { delErr in
                            if let delErr = delErr {
                                print("⚠️ 自動削除失敗: \(delErr.localizedDescription)")
                            } else {
                                print("🧹 不正データ削除済み: \(doc.documentID)")
                            }
                        }
                        */
                        return nil
                    }

                    return AdminRow(
                        id: doc.documentID,
                        name: name,
                        email: email,
                        role: role,
                        isDeveloper: role == "開発者"
                    )
                } ?? []

                self.admins = allAdmins
                self.isLoading = false
            }
        }
    }

    private func updateRole(for id: String, to newRole: String) {
        db.collection("admins").document(id).updateData(["role": newRole]) { err in
            if let err {
                self.showTemporaryToast("更新失敗: \(err.localizedDescription)")
            } else {
                self.showTemporaryToast("✅ 「\(newRole)」に変更しました")
            }
        }
    }

    private func showTemporaryToast(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showToast = false }
        }
    }
}

// MARK: - Row Model
struct AdminRow: Identifiable {
    let id: String
    let name: String
    let email: String
    var role: String
    let isDeveloper: Bool
}
