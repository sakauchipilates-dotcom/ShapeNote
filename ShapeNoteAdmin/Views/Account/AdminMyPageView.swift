import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import ShapeCore // AuthViewModel 用

struct AdminMyPageView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var name = ""
    @State private var email = ""
    @State private var role = ""
    @State private var selectedRole = "一般"
    @State private var canEditRole = false
    @State private var showSaveAlert = false
    @State private var saveMessage = ""
    @State private var showLogoutAlert = false

    @State private var contacts: [ContactItem] = []
    @State private var isLoadingContacts = false
    @State private var contactsListener: ListenerRegistration?

    @State private var selectedContact: ContactItem?
    @State private var sortMode: SortMode = .unrepliedFirst

    private let db = Firestore.firestore()
    private let roles = ["一般", "管理者", "開発者"]

    enum SortMode: String {
        case unrepliedFirst = "未返信優先"
        case latestFirst = "日付順"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - あなたの管理者情報
                    sectionCard(title: "あなたの情報") {
                        personalInfo
                    }

                    // MARK: - お問い合わせ一覧
                    sectionCard(title: "お問い合わせ一覧") {
                        contactSection
                    }

                    // MARK: - 管理者一覧（開発者のみ）
                    if canEditRole {
                        sectionCard(title: "管理者一覧") {
                            AdminListView()
                                .frame(maxHeight: 400)
                        }
                    }

                    // MARK: - 🎟 クーポン管理（管理者専用）
                    couponSection
                }
                .padding()
            }
            .navigationTitle("管理者ページ")
            .navigationBarTitleDisplayMode(.large) // ← タイトル高さを統一
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    TopRightIcons(
                        onLogout: { showLogoutAlert = true },
                        onNotification: { print("🔔 管理者通知タップ") }
                    )
                }
            }
            .alert("ログアウトしますか？", isPresented: $showLogoutAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("ログアウト", role: .destructive) { logout() }
            }
            .alert(isPresented: $showSaveAlert) {
                Alert(title: Text("保存結果"),
                      message: Text(saveMessage),
                      dismissButton: .default(Text("OK")))
            }
            .onAppear {
                fetchAdminInfo()
                startContactsListener()
            }
            .onDisappear {
                stopContactsListener()
            }
            .sheet(item: $selectedContact) { contact in
                ContactDetailView(contact: contact)
            }
        }
    }

    // MARK: - あなたの情報（ビュー）
    private var personalInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("名前：").bold()
                Text(name)
            }
            HStack {
                Text("メール：").bold()
                Text(email)
            }
            HStack {
                Text("権限レベル：").bold()
                Picker("権限", selection: $selectedRole) {
                    ForEach(roles, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .disabled(!canEditRole)
            }

            if canEditRole {
                Button(action: saveRoleToFirestore) {
                    Text("変更を保存")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 6)
            }
        }
        .font(.subheadline)
    }

    // MARK: - お問い合わせ一覧（ビュー）
    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("並び替え：")
                    .font(.subheadline)
                Picker("", selection: $sortMode) {
                    Text("未返信優先").tag(SortMode.unrepliedFirst)
                    Text("日付順").tag(SortMode.latestFirst)
                }
                .pickerStyle(.segmented)
            }
            .padding(.bottom, 8)

            if isLoadingContacts {
                ProgressView("読み込み中…")
            } else if contacts.isEmpty {
                Text("お問い合わせはありません。")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                ForEach(sortedContacts) { contact in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(contact.name)
                                .font(.headline)
                            Spacer()
                            Text(contact.status == "対応済" ? "返信済み" : "未返信")
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    contact.status == "対応済"
                                    ? Color.green.opacity(0.7)
                                    : Color.orange.opacity(0.8)
                                )
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }

                        Text(contact.message)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundColor(.secondary)

                        if contact.status == "対応済", let reply = contact.reply, !reply.isEmpty {
                            Text("返信: \(reply)")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                                .padding(.top, 2)
                        }

                        Text(contact.timestampString)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(Theme.cardRadius)
                    .shadow(color: Theme.shadow, radius: 5, x: 0, y: 3)
                    .onTapGesture {
                        selectedContact = contact
                    }
                }
            }
        }
    }

    // MARK: - クーポン管理（ビュー）
    private var couponSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(.white)
                    .font(.title3)
                Text("クーポン管理")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            NavigationLink(destination: CouponManagerView()) {
                Text("クーポン管理画面へ")
                    .font(.headline)
                    .foregroundColor(Theme.dark)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(Theme.cardRadius)
                    .shadow(color: Theme.shadow, radius: 5, x: 0, y: 3)
            }
        }
        .padding()
        .background(Theme.main)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: Theme.shadow, radius: 5, x: 0, y: 3)
    }

    // MARK: - 並び替えロジック
    private var sortedContacts: [ContactItem] {
        switch sortMode {
        case .unrepliedFirst:
            return contacts.sorted {
                if $0.status == "対応済" && $1.status != "対応済" { return false }
                if $0.status != "対応済" && $1.status == "対応済" { return true }
                return $0.timestamp.dateValue() > $1.timestamp.dateValue()
            }
        case .latestFirst:
            return contacts.sorted {
                $0.timestamp.dateValue() > $1.timestamp.dateValue()
            }
        }
    }

    // MARK: - 共通カードUI
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.dark)
            Divider()
            content()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: Theme.shadow, radius: 5, x: 0, y: 3)
    }

    // MARK: - Firestore関連
    private func fetchAdminInfo() {
        guard let user = Auth.auth().currentUser else { return }
        db.collection("admins").document(user.uid).getDocument { doc, _ in
            if let data = doc?.data() {
                name = data["name"] as? String ?? "不明"
                email = data["email"] as? String ?? user.email ?? ""
                role = data["role"] as? String ?? "一般"
                selectedRole = role
                canEditRole = (role == "開発者")
                let validRoles = ["一般", "管理者", "開発者"]
                if !validRoles.contains(selectedRole) { selectedRole = "一般" }
            } else {
                name = "不明"
                email = user.email ?? ""
                role = "一般"
                selectedRole = "一般"
                canEditRole = false
            }
        }
    }

    private func startContactsListener() {
        isLoadingContacts = true
        contactsListener?.remove()
        contactsListener = db.collection("contacts")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { snapshot, error in
                isLoadingContacts = false
                if let error = error {
                    print("⚠️ contacts listener error: \(error.localizedDescription)")
                    return
                }
                guard let docs = snapshot?.documents else {
                    contacts = []
                    return
                }
                contacts = docs.compactMap { doc in
                    let d = doc.data()
                    return ContactItem(
                        id: doc.documentID,
                        name: d["name"] as? String ?? "匿名",
                        message: d["message"] as? String ?? "",
                        status: d["status"] as? String ?? "未読",
                        timestamp: d["timestamp"] as? Timestamp ?? Timestamp(),
                        reply: d["reply"] as? String ?? "",
                        repliedAt: d["repliedAt"] as? Timestamp
                    )
                }
            }
    }

    private func stopContactsListener() {
        contactsListener?.remove()
        contactsListener = nil
    }

    private func saveRoleToFirestore() {
        guard canEditRole, let user = Auth.auth().currentUser else { return }
        db.collection("admins").document(user.uid).updateData(["role": selectedRole]) { error in
            if let error = error {
                saveMessage = "❌ Firestore保存エラー: \(error.localizedDescription)"
            } else {
                saveMessage = "✅ 権限レベルを「\(selectedRole)」に変更しました。"
                role = selectedRole
            }
            showSaveAlert = true
        }
    }

    private func logout() {
        authVM.signOut()
        print("🚪 ログアウト完了：ログイン画面へ遷移します")
    }
}
