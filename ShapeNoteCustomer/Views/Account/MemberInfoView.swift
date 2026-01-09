import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import ShapeCore

struct MemberInfoView: View {

    @EnvironmentObject var vm: ProfileImageVM

    @State private var showPassword = false
    @State private var displayId: String = "—"
    @State private var password: String = "********"
    @State private var birthDateText: String = "—"

    @State private var isProcessing = false
    @State private var alertTitle = "通知"
    @State private var alertMessage = ""
    @State private var showAlert = false

    // 退会（アカウント削除申請）
    @State private var showDeleteConfirm = false
    @State private var isSendingDeletionRequest = false

    private let db = Firestore.firestore()

    var body: some View {
        ZStack {
            Theme.gradientMain
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {

                    // ---- 基本情報カード ----
                    infoCard
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    // ---- アクションカード（ボタンだけ）----
                    actionCard
                        .padding(.horizontal, 16)

                    // ✅ 説明文はカードの外に出す（重なり防止）
                    Text("退会申請後はログインできなくなります。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.top, 2)

                    Spacer(minLength: 30)
                }
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("会員情報")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isProcessing || isSendingDeletionRequest)
        .task {
            await vm.loadProfile()
            await fetchDisplayId()
            await fetchBirthDate()
            loadPasswordFromKeychain()
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("退会しますか？", isPresented: $showDeleteConfirm) {
            Button("キャンセル", role: .cancel) { }
            Button("退会する", role: .destructive) {
                Task { await submitDeletionRequest() }
            }
        } message: {
            Text("退会申請を送信します。送信後はログインできなくなります。")
        }
    }

    // MARK: - UI

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text("基本情報")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                infoRow(title: "氏名", value: vm.name)
                divider

                infoRow(title: "メールアドレス", value: vm.email.isEmpty ? (Auth.auth().currentUser?.email ?? "—") : vm.email)
                divider

                passwordRow
                divider

                infoRow(title: "性別", value: genderLabel(for: vm.gender))
                divider

                infoRow(title: "生年月日", value: birthDateText)
                divider

                infoRow(title: "ランク", value: vm.membershipRank.isEmpty ? "Bronze" : vm.membershipRank)
                divider

                infoRow(title: "会員ID", value: displayId)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: Theme.dark.opacity(0.08), radius: 14, y: 8)
        )
    }

    /// ✅ ボタンカードは「ボタン＋divider」のみ（固定高さにしない）
    private var actionCard: some View {
        VStack(spacing: 0) {

            Button {
                Task { await resetPassword() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .foregroundColor(Theme.sub)

                    Text("パスワードを変更する")
                        .foregroundColor(Theme.sub)

                    Spacer()

                    if isProcessing {
                        ProgressView().scaleEffect(0.9)
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            divider

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.fill.xmark")
                    Text(isSendingDeletionRequest ? "退会申請を送信中..." : "退会する（アカウント削除申請）")
                    Spacer()
                    if isSendingDeletionRequest {
                        ProgressView().scaleEffect(0.9)
                    }
                }
                .foregroundColor(.red)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .disabled(isSendingDeletionRequest)
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: Theme.dark.opacity(0.06), radius: 12, y: 7)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(Theme.dark)

            Spacer()

            Text(value.isEmpty ? "—" : value)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 14)
    }

    private var passwordRow: some View {
        HStack {
            Text("パスワード")
                .foregroundColor(Theme.dark)

            Spacer()

            if showPassword {
                Text(password)
                    .foregroundColor(.secondary)
            } else {
                Text("••••••••")
                    .foregroundColor(.secondary)
            }

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundColor(Theme.sub)
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 14)
    }

    // MARK: - Logic

    private func genderLabel(for value: String) -> String {
        switch value.lowercased() {
        case "male": return "男性"
        case "female": return "女性"
        default: return "不明"
        }
    }

    private func fetchDisplayId() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            displayId = "未設定"
            return
        }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if let data = doc.data() {
                displayId = data["displayId"] as? String ?? "未設定"
            } else {
                displayId = "未設定"
            }
        } catch {
            print("❌ displayId取得失敗: \(error.localizedDescription)")
            displayId = "未設定"
        }
    }

    private func fetchBirthDate() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            guard let data = doc.data() else {
                birthDateText = "未設定"
                return
            }

            if let year = data["birthYear"] as? Int,
               let month = data["birthMonth"] as? Int,
               let day = data["birthDay"] as? Int {
                birthDateText = "\(year)年\(month)月\(day)日"
            } else if let year = data["birthYear"] as? Int {
                birthDateText = "\(year)年"
            } else {
                birthDateText = "未設定"
            }
        } catch {
            print("❌ 生年月日取得失敗: \(error.localizedDescription)")
        }
    }

    private func loadPasswordFromKeychain() {
        if let email = Auth.auth().currentUser?.email,
           let stored = AuthHandler.shared.loadPassword(for: email) {
            password = stored
        }
    }

    private func resetPassword() async {
        guard let email = Auth.auth().currentUser?.email else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await AuthHandler.shared.sendPasswordReset(email: email)
            alertTitle = "通知"
            alertMessage = "パスワード変更用のメールを送信しました。\nメール内のリンクから新しいパスワードを設定してください。"
        } catch {
            alertTitle = "エラー"
            alertMessage = "メール送信に失敗しました: \(error.localizedDescription)"
        }
        showAlert = true
    }

    /// A案：削除「申請」だけ送って、アプリ側はログアウト（以後ログイン不可は AppState 側ガードで固定）
    @MainActor
    private func submitDeletionRequest() async {
        guard !isSendingDeletionRequest else { return }
        guard let user = Auth.auth().currentUser else {
            alertTitle = "エラー"
            alertMessage = "ログイン情報が取得できません。再ログインしてください。"
            showAlert = true
            return
        }

        isSendingDeletionRequest = true
        defer { isSendingDeletionRequest = false }

        do {
            // 申請先は運用に合わせて変更可
            try await db.collection("accountDeletionRequests").document(user.uid).setData([
                "uid": user.uid,
                "email": user.email ?? "",
                "status": "requested",
                "createdAt": FieldValue.serverTimestamp()
            ], merge: true)

            // 申請後はログアウト
            try Auth.auth().signOut()

            alertTitle = "送信しました"
            alertMessage = "退会申請を受け付けました。"
            showAlert = true

        } catch {
            alertTitle = "エラー"
            alertMessage = "退会申請の送信に失敗しました。通信環境をご確認のうえ、再度お試しください。"
            showAlert = true
            print("❌ deletion request error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        MemberInfoView()
            .environmentObject(ProfileImageVM())
    }
}
