import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import ShapeCore

struct MemberInfoView: View {
    @EnvironmentObject var vm: ProfileImageVM
    @State private var showPassword = false
    @State private var displayId: String = "—"      // 顧客表示用ID
    @State private var password: String = "********" // 実際のパスワード
    @State private var birthDateText: String = "—"  // 年月日表記
    @State private var isProcessing = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        Form {
            // MARK: - 基本情報
            Section(header: Text("基本情報")) {
                infoRow(title: "氏名", value: vm.name)
                infoRow(title: "メールアドレス", value: vm.email.isEmpty ? (Auth.auth().currentUser?.email ?? "—") : vm.email)

                // ✅ パスワード表示／非表示切り替え
                passwordRow

                infoRow(title: "性別", value: genderLabel(for: vm.gender))
                infoRow(title: "生年月日", value: birthDateText)
                infoRow(title: "ランク", value: vm.membershipRank.isEmpty ? "Bronze" : vm.membershipRank)
                infoRow(title: "会員ID", value: displayId)
            }

            // MARK: - パスワード変更セクション
            Section {
                Button {
                    Task { await resetPassword() }
                } label: {
                    Label("パスワードを変更する", systemImage: "key.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .disabled(isProcessing)
        .navigationTitle("会員情報")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.loadProfile()
            await fetchDisplayId()
            await fetchBirthDate()
            loadPasswordFromKeychain()
        }
        .alert("通知", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - 情報行コンポーネント
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .foregroundColor(.gray)
        }
    }

    // MARK: - パスワード欄
    private var passwordRow: some View {
        HStack {
            Text("パスワード")
            Spacer()
            if showPassword {
                Text(password)
                    .foregroundColor(.gray)
            } else {
                SecureField("", text: .constant(password))
                    .disabled(true)
            }
            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(.blue)
            }
        }
    }

    // MARK: - 性別表示の変換
    private func genderLabel(for value: String) -> String {
        switch value.lowercased() {
        case "male": return "男性"
        case "female": return "女性"
        default: return "不明"
        }
    }

    // MARK: - displayId取得
    private func fetchDisplayId() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            displayId = "未設定"
            return
        }
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if let data = doc.data() {
                displayId = data["displayId"] as? String ?? "未設定"
            }
        } catch {
            print("❌ displayId取得失敗: \(error.localizedDescription)")
            displayId = "未設定"
        }
    }

    // MARK: - 生年月日取得（年月日）
    private func fetchBirthDate() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if let data = doc.data() {
                if let year = data["birthYear"] as? Int,
                   let month = data["birthMonth"] as? Int,
                   let day = data["birthDay"] as? Int {
                    birthDateText = "\(year)年\(month)月\(day)日"
                } else if let year = data["birthYear"] as? Int {
                    birthDateText = "\(year)年"
                } else {
                    birthDateText = "未設定"
                }
            }
        } catch {
            print("❌ 生年月日取得失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - パスワード変更メール送信
    private func resetPassword() async {
        guard let email = Auth.auth().currentUser?.email else { return }
        isProcessing = true
        do {
            try await AuthHandler.shared.sendPasswordReset(email: email)
            alertMessage = "パスワード変更用のメールを送信しました。\nメール内のリンクから新しいパスワードを設定してください。"
        } catch {
            alertMessage = "メール送信に失敗しました: \(error.localizedDescription)"
        }
        isProcessing = false
        showAlert = true
    }

    // MARK: - Keychainからパスワード読み込み
    private func loadPasswordFromKeychain() {
        if let email = Auth.auth().currentUser?.email,
           let stored = AuthHandler.shared.loadPassword(for: email) {
            password = stored
        }
    }
}

#Preview {
    NavigationStack {
        MemberInfoView()
            .environmentObject(ProfileImageVM())
    }
}
