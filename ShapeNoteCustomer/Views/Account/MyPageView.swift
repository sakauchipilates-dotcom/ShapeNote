import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import ShapeCore
import Combine

struct MyPageView: View {

    @EnvironmentObject var appState: CustomerAppState
    @EnvironmentObject var imageVM: ProfileImageVM

    @State private var availableCouponCount: Int = 0
    @State private var isLoadingCoupons: Bool = true

    @State private var showGateAlert: Bool = false
    @State private var gateMessage: String = ""

    // ✅ アップグレード導線（会員情報へ遷移）
    @State private var goToMemberInfo: Bool = false

    // ✅ アカウント削除 UI
    @State private var showDeleteConfirm: Bool = false
    @State private var showReauthSheet: Bool = false
    @State private var reauthPassword: String = ""
    @State private var isDeleting: Bool = false
    @State private var deleteErrorMessage: String = ""
    @State private var showDeleteErrorAlert: Bool = false

    // ✅ 記録リマインド（ON/OFFのみ @AppStorage で共有）
    @AppStorage("recordReminderEnabled") private var recordReminderEnabled: Bool = true

    // ✅ 記録リマインドの時刻（DatePicker 用）
    @State private var reminderTime: Date = {
        var comps = DateComponents()
        comps.hour = RecordReminderSettings.default.hour
        comps.minute = RecordReminderSettings.default.minute
        return Calendar.current.date(from: comps) ?? Date()
    }()

    @State private var showReminderTimeSheet: Bool = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {

                    MembershipCardView()
                        .environmentObject(imageVM)
                        .padding(.horizontal, 16)

                    // ✅ クーポン：Premiumのみ
                    if appState.subscriptionState.isPremium {
                        couponQuickCard
                            .padding(.horizontal, 16)
                    } else {
                        lockedQuickCard(
                            title: "クーポン",
                            subtitle: "プレミアム会員で利用できます",
                            systemImage: "ticket.fill"
                        )
                        .padding(.horizontal, 16)
                    }

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
                // ✅ クーポン：無料ユーザーは Firestore に触らない
                if appState.subscriptionState.isPremium {
                    await fetchAvailableCouponCount()
                } else {
                    await MainActor.run {
                        availableCouponCount = 0
                        isLoadingCoupons = false
                    }
                }

                // ✅ 記録リマインド設定をロードして UI と同期
                let loaded = RecordReminderManager.shared.loadSettings()
                await MainActor.run {
                    recordReminderEnabled = loaded.isEnabled

                    var comps = DateComponents()
                    comps.hour = loaded.hour
                    comps.minute = loaded.minute
                    if let date = calendar.date(from: comps) {
                        reminderTime = date
                    }
                }
            }

            // ✅ Premiumゲート：2ボタン + 購入導線（審査向け）
            .alert("プレミアム限定", isPresented: $showGateAlert) {
                Button("アップグレードする") { goToMemberInfo = true }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(gateMessage)
            }

            // ✅ 購入導線（会員情報）
            .navigationDestination(isPresented: $goToMemberInfo) {
                MemberInfoView()
                    .environmentObject(imageVM)
            }

            // ✅ アカウント削除：最終確認
            .alert("アカウントを削除しますか？", isPresented: $showDeleteConfirm) {
                Button("削除する", role: .destructive) {
                    Task { await runDeleteFlow(password: nil) }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。\nログイン情報およびアカウントに紐づくデータが削除されます。")
            }

            // ✅ 削除失敗時アラート
            .alert("削除できませんでした", isPresented: $showDeleteErrorAlert) {
                Button("OK") {}
            } message: {
                Text(deleteErrorMessage)
            }

            // ✅ 再認証（パスワード入力）シート
            .sheet(isPresented: $showReauthSheet) {
                NavigationStack {
                    VStack(spacing: 16) {
                        Text("安全のため、再ログインが必要です。")
                            .font(.headline)

                        Text("パスワードを入力して、アカウント削除を続行してください。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        SecureField("パスワード", text: $reauthPassword)
                            .textContentType(.password)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Button {
                            Task { await runDeleteFlow(password: reauthPassword) }
                        } label: {
                            Text("続行して削除する")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(reauthPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDeleting)

                        Button(role: .cancel) {
                            reauthPassword = ""
                            showReauthSheet = false
                        } label: {
                            Text("キャンセル")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                    .padding(16)
                    .navigationTitle("再ログイン")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("閉じる") {
                                reauthPassword = ""
                                showReauthSheet = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }

            // ✅ 記録リマインド時間設定シート（OK/キャンセルで閉じる）
            .sheet(isPresented: $showReminderTimeSheet) {
                NavigationStack {
                    VStack {
                        DatePicker(
                            "",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxHeight: 250)
                        .padding(.top, 24)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .navigationTitle("記録リマインドの時間")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("キャンセル") {
                                // 変更を破棄して閉じるだけ
                                showReminderTimeSheet = false

                                // 表示だけ元の設定に戻したい場合は、再ロードしても良い
                                let current = RecordReminderManager.shared.loadSettings()
                                var comps = DateComponents()
                                comps.hour = current.hour
                                comps.minute = current.minute
                                if let date = calendar.date(from: comps) {
                                    reminderTime = date
                                }
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("保存") {
                                persistReminderSettings()
                                showReminderTimeSheet = false
                            }
                            .bold()
                        }
                    }
                }
                .presentationDetents([.height(320)])
                .interactiveDismissDisabled(true) // 画面タップでは閉じない
            }

            // ✅ 削除中オーバーレイ
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.18).ignoresSafeArea()
                        ProgressView("削除中…")
                            .padding(16)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 6)
                    }
                }
            }

            // ✅ トグル変更時に設定を保存して通知スケジュールを更新
            .onChange(of: recordReminderEnabled) { _ in
                persistReminderSettings()
            }
        }
    }

    // MARK: - クーポン枠（Premium）
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

    private func lockedQuickCard(title: String, subtitle: String, systemImage: String) -> some View {
        Button {
            gateMessage = "この機能はプレミアム会員（月額440円）で利用できます。\n「アップグレードする」から購入画面（会員情報）へ進めます。"
            showGateAlert = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: Theme.dark.opacity(0.06), radius: 10, y: 6)

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Theme.sub.opacity(0.12))
                            .frame(width: 46, height: 46)

                        Image(systemName: systemImage)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.sub.opacity(0.85))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(Theme.dark)

                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(16)
            }
            .frame(height: 86)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
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

    // MARK: - メニュー
    private var menuSection: some View {
        VStack(spacing: 0) {

            NavigationLink(destination: MemberInfoView().environmentObject(imageVM)) {
                Label("会員情報", systemImage: "person.text.rectangle")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            Divider()

            // ✅ 来店履歴：Premiumのみ
            if appState.subscriptionState.isPremium {
                NavigationLink(destination: VisitHistoryView()) {
                    Label("来店履歴", systemImage: "clock")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else {
                Button {
                    gateMessage = "来店履歴はプレミアム会員（月額440円）で利用できます。\n「アップグレードする」から購入画面（会員情報）へ進めます。"
                    showGateAlert = true
                } label: {
                    HStack {
                        Label("来店履歴", systemImage: "clock")
                        Spacer()
                        Image(systemName: "lock.fill")
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .buttonStyle(.plain)
            }
            Divider()

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

            // ✅ 記録リマインド（ON/OFF + 時刻設定）
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Toggle(isOn: $recordReminderEnabled) {
                        Label("記録リマインド", systemImage: "bell.badge")
                    }

                    Spacer()

                    Button(reminderTimeText) {
                        showReminderTimeSheet = true
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }

                Text("毎日 \(reminderTimeText) ごろにお知らせします。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            Divider()

            // ✅ アカウント削除
            Button {
                showDeleteConfirm = true
            } label: {
                Label("アカウント削除", systemImage: "person.crop.circle.badge.xmark")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .foregroundColor(.red)
            }
            Divider()

            // ✅ ログアウト
            Button {
                Task { await appState.forceLogout() }
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

    private var reminderTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: reminderTime)
    }

    // MARK: - Delete flow
    @MainActor
    private func runDeleteFlow(password: String?) async {
        guard !isDeleting else { return }

        isDeleting = true
        defer { isDeleting = false }

        do {
            try await appState.deleteAccountNow(passwordForReauth: password)

            // 成功したら入力を片付け
            reauthPassword = ""
            showReauthSheet = false

        } catch {
            let ns = error as NSError

            // CustomerAppState 側の「再認証が必要」判定
            let requiresReauth = (ns.userInfo["requiresReauth"] as? Bool) == true
                || ns.code == AuthErrorCode.requiresRecentLogin.rawValue

            if requiresReauth && (password == nil || password?.isEmpty == true) {
                // パスワード入力を促す
                reauthPassword = ""
                showReauthSheet = true
                return
            }

            // それ以外はエラー表示
            deleteErrorMessage = ns.localizedDescription
            showDeleteErrorAlert = true
        }
    }

    // MARK: - 記録リマインド設定の保存

    private func persistReminderSettings() {
        var settings = RecordReminderManager.shared.loadSettings()
        settings.isEnabled = recordReminderEnabled

        let comps = calendar.dateComponents([.hour, .minute], from: reminderTime)
        settings.hour = comps.hour ?? settings.hour
        settings.minute = comps.minute ?? settings.minute

        RecordReminderManager.shared.updateSettings(settings)
    }

    // MARK: - Firestore：利用可能クーポン数（Premiumのみ呼ばれる）

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
