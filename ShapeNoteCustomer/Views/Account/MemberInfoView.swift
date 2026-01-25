import SwiftUI
import StoreKit
import FirebaseAuth
import FirebaseFirestore
import ShapeCore

struct MemberInfoView: View {

    @EnvironmentObject var vm: ProfileImageVM
    @EnvironmentObject var appState: CustomerAppState

    @State private var showPassword = false
    @State private var displayId: String = "—"
    @State private var password: String = "********"
    @State private var birthDateText: String = "—"

    @State private var isProcessing = false
    @State private var alertTitle = "通知"
    @State private var alertMessage = ""
    @State private var showAlert = false

    // アカウント削除
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false

    // 再認証が必要な場合の入力
    @State private var showReauthSheet = false
    @State private var reauthPasswordInput = ""
    @State private var reauthError: String? = nil

    // ✅ 購入導線（見える化）
    @State private var goToSubscription = false

    // ✅ StoreKit 2 購入窓口
    @StateObject private var subscriptionStore = SubscriptionStore()

    private let db = Firestore.firestore()

    private var isPremiumNow: Bool {
        appState.subscriptionState.isPremium(now: Date())
    }

    var body: some View {
        ZStack {
            Theme.gradientMain
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {

                    // ✅ 最重要：購入導線は「最上段」に固定
                    upgradeEntryCard
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    infoCard
                        .padding(.horizontal, 16)

                    actionCard
                        .padding(.horizontal, 16)

                    Text("アカウント削除はアプリ内で完了します（削除後は復元できません）。")
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
        .disabled(isProcessing || isDeletingAccount)
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
        .alert("アカウントを削除しますか？", isPresented: $showDeleteConfirm) {
            Button("キャンセル", role: .cancel) { }
            Button("削除する", role: .destructive) {
                Task { await startDeleteFlow() }
            }
        } message: {
            Text("アカウントと関連データを削除します。削除後はログインできません。")
        }
        .sheet(isPresented: $showReauthSheet) {
            reauthSheet
                .presentationDetents([.medium])
        }
        .navigationDestination(isPresented: $goToSubscription) {
            SubscriptionInfoView()
        }
    }

    // MARK: - ✅ 購入導線（最上段固定）

    private var upgradeEntryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .foregroundColor(Theme.sub)

                VStack(alignment: .leading, spacing: 2) {
                    Text("プレミアム会員")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Theme.dark)

                    // ✅ 価格・周期は必ず明記
                    Text("月額440円")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isPremiumNow {
                    Text("加入中")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }

            // ✅ 解約場所（設定→サブスクリプション）を必ず明記
            Text("解約はいつでも「設定」→「サブスクリプション」から行えます。")
                .font(.footnote)
                .foregroundColor(.secondary)

            if !isPremiumNow {
                Button {
                    Task {
                        await handleUpgradeTapped()
                    }
                } label: {
                    HStack {
                        Text("アップグレードする")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if subscriptionStore.isPurchasing {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "cart.fill")
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        Theme.sub,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .accessibilityLabel("アップグレードする")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.88))
                .shadow(color: Theme.dark.opacity(0.08), radius: 14, y: 8)
        )
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
                    Text(isDeletingAccount ? "削除中..." : "アカウントを削除する（退会）")
                    Spacer()
                    if isDeletingAccount {
                        ProgressView().scaleEffect(0.9)
                    }
                }
                .foregroundColor(.red)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .disabled(isDeletingAccount)
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

    private var reauthSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("再認証が必要です")
                .font(.headline)

            Text("安全のため、アカウント削除前にパスワードの再入力が必要です。")
                .font(.subheadline)
                .foregroundColor(.secondary)

            SecureField("パスワード", text: $reauthPasswordInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let reauthError {
                Text(reauthError)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                Button("キャンセル", role: .cancel) {
                    reauthPasswordInput = ""
                    reauthError = nil
                    showReauthSheet = false
                }

                Spacer()

                Button {
                    Task { await confirmDeleteWithPassword() }
                } label: {
                    Text(isDeletingAccount ? "削除中..." : "削除を実行")
                        .font(.subheadline.weight(.semibold))
                }
                .disabled(reauthPasswordInput.isEmpty || isDeletingAccount)
            }
            .padding(.top, 4)
        }
        .padding(20)
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

    // MARK: - Purchase

    @MainActor
    private func handleUpgradeTapped() async {
        guard !isPremiumNow else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await subscriptionStore.purchasePremium()

            alertTitle = "アップグレード完了"
            alertMessage = "プレミアム会員へのご登録ありがとうございます。\nこのままプレミアム機能をご利用いただけます。"
            showAlert = true

        } catch let storeError as SubscriptionStore.StoreError {
            // ユーザーキャンセルは静かに無視
            if case .userCancelled = storeError {
                return
            }
            alertTitle = "購入エラー"
            alertMessage = storeError.localizedDescription
            showAlert = true

        } catch {
            alertTitle = "購入エラー"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    // MARK: - Delete Account

    @MainActor
    private func startDeleteFlow() async {
        guard !isDeletingAccount else { return }
        reauthError = nil

        let candidatePassword: String? = (password == "********") ? nil : password

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await appState.deleteAccountNow(passwordForReauth: candidatePassword)
            alertTitle = "削除完了"
            alertMessage = "アカウントを削除しました。ご利用ありがとうございました。"
            showAlert = true
        } catch {
            // 再認証要求なら入力を促す
            if error.localizedDescription.contains("再ログイン") || error.localizedDescription.contains("パスワード") {
                showReauthSheet = true
            } else {
                alertTitle = "エラー"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    @MainActor
    private func confirmDeleteWithPassword() async {
        guard !isDeletingAccount else { return }
        guard !reauthPasswordInput.isEmpty else { return }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await appState.deleteAccountNow(passwordForReauth: reauthPasswordInput)
            showReauthSheet = false
            reauthPasswordInput = ""
            reauthError = nil

            alertTitle = "削除完了"
            alertMessage = "アカウントを削除しました。ご利用ありがとうございました。"
            showAlert = true
        } catch {
            reauthError = error.localizedDescription
        }
    }
}

// MARK: - ✅ 購入導線 “案内画面”（説明用）

private struct SubscriptionInfoView: View {

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 14) {
                Spacer(minLength: 0)

                Image(systemName: "crown.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(Theme.sub)

                Text("プレミアム会員（月額440円）")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Theme.dark.opacity(0.9))

                VStack(spacing: 8) {
                    Text("プレミアム会員で利用できる機能")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.dark.opacity(0.85))

                    Text("・クーポン\n・来店履歴\n・その他プレミアム限定機能")
                        .font(.subheadline)
                        .foregroundColor(Theme.dark.opacity(0.75))
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 22)
                }
                .padding(.top, 4)

                Text("解約はいつでも「設定」→「サブスクリプション」から行えます。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 6)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 24)
        }
        .navigationTitle("プレミアム")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MemberInfoView()
            .environmentObject(ProfileImageVM())
            .environmentObject(CustomerAppState())
    }
}
