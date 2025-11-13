import SwiftUI
import FirebaseFirestore
import ShapeCore

// MARK: - 画面本体
struct AdminVisitHistoryView: View {
    /// 顧客詳細から渡された場合はここに入る。nil なら上部の顧客ピッカーを表示
    var preselectedUser: UserItem? = nil

    @State private var users: [UserItem] = []
    @State private var currentUser: UserItem? = nil

    @State private var items: [AdminVisitRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    // Sheet
    @State private var showSheet = false
    @State private var editingIndex: Int? = nil   // nil: 追加、>=0: 編集

    private let db = Firestore.firestore()

    // 累計金額
    private var totalAmount: Int {
        items.compactMap { $0.price }.reduce(0, +)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // 顧客ピッカー（事前選択がなければ表示）
                if preselectedUser == nil {
                    userPicker
                }

                // 累計金額
                if currentUser != nil {
                    HStack {
                        Text("累計購入金額")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text("¥\(totalAmount.formatted(.number.grouping(.automatic)))")
                            .font(.headline)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                Divider()

                // コンテンツ
                Group {
                    if isLoading {
                        ProgressView("読み込み中…").padding(.top, 40)
                    } else if let err = errorMessage {
                        Text("⚠️ \(err)").foregroundStyle(.red).padding(.top, 40)
                    } else if items.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 48)).foregroundStyle(.gray)
                            Text("来店履歴がまだありません。").foregroundStyle(.secondary)
                        }
                        .padding(.top, 60)
                    } else {
                        List {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, r in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(r.date)               // 例: 2025/11/11
                                            .font(.headline)
                                        Spacer()
                                        if let price = r.price {
                                            Text("¥\(price)")
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Text(r.menu)                  // 例: パーソナルレッスン
                                        .font(.subheadline)

                                    if let pn = r.productName, !pn.isEmpty {
                                        Text(pn)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    if r.isCouponUsed {
                                        Label("回数券を使用", systemImage: "checkmark.seal.fill")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    }
                                }
                                .padding(.vertical, 4)
                                .swipeActions(edge: .trailing) {
                                    Button("編集") {
                                        editingIndex = index
                                        showSheet = true
                                    }
                                    .tint(.blue)

                                    Button("削除", role: .destructive) {
                                        delete(at: IndexSet(integer: index))
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("来店履歴管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentUser != nil {
                        Button {
                            editingIndex = nil
                            showSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.title3)
                        }
                    }
                }
            }
            .task {
                // 事前選択があればセット、なければユーザー一覧取得
                if let pre = preselectedUser {
                    currentUser = pre
                    await fetchVisitHistory(for: pre)
                } else {
                    await fetchUsers()
                }
            }
            .onChange(of: currentUser) { _, newValue in
                Task { await fetchVisitHistory(for: newValue) }
            }
            .sheet(isPresented: $showSheet) {
                if let user = currentUser {
                    let editingRecord: AdminVisitRecord? = {
                        if let idx = editingIndex, items.indices.contains(idx) { return items[idx] }
                        return nil
                    }()

                    AddOrEditVisitSheet(
                        userId: user.id,
                        record: editingRecord
                    ) { saved in
                        // 追加 or 置換
                        if let idx = editingIndex, items.indices.contains(idx) {
                            items[idx] = saved
                        } else {
                            items.append(saved)
                        }
                        // Firestore反映
                        Task { await saveAll(for: user) }
                    }
                }
            }
        }
    }

    // MARK: - ユーザーピッカー
    private var userPicker: some View {
        HStack {
            Text("顧客")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Picker("顧客を選択", selection: $currentUser) {
                Text("顧客を選択してください").tag(Optional<UserItem>(nil))
                ForEach(users) { user in
                    Text(user.name).tag(Optional(user))
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    // MARK: - Firestore: ユーザー一覧
    private func fetchUsers() async {
        do {
            isLoading = true
            let snapshot = try await db.collection("users").getDocuments()
            let fetched: [UserItem] = snapshot.documents.compactMap { doc -> UserItem? in
                let data = doc.data()
                guard let name = data["name"] as? String else { return nil }

                return UserItem(
                    id: doc.documentID,
                    name: name,
                    email: data["email"] as? String ?? "",
                    gender: UserItem.Gender(rawValue: (data["gender"] as? String ?? "").lowercased()) ?? .unknown,
                    birthYear: data["birthYear"] as? Int,
                    joinedAt: (data["joinedAt"] as? Timestamp)?.dateValue(),
                    iconURL: data["iconURL"] as? String,
                    membershipRank: UserItem.Rank(rawValue: data["membershipRank"] as? String ?? ""),
                    displayId: data["displayId"] as? String
                )
            }

            await MainActor.run {
                self.users = fetched.sorted { $0.name < $1.name }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // MARK: - Firestore: 履歴取得
    private func fetchVisitHistory(for user: UserItem?) async {
        guard let user = user else { return }
        do {
            isLoading = true
            let doc = try await db.collection("users").document(user.id).getDocument()
            let raw = (doc.data()?["visitHistory"] as? [[String: Any]]) ?? []

            let loaded: [AdminVisitRecord] = raw.compactMap { AdminVisitRecord.from(dict: $0) }

            // 新→旧
            let sorted = loaded.sorted(by: { $0.sortKeyDate > $1.sortKeyDate })

            await MainActor.run {
                self.items = sorted
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.items = []
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Firestore: 全保存（追加/編集/削除の後に呼ぶ）
    private func saveAll(for user: UserItem) async {
        do {
            let dicts = items.map { $0.toDictionary() }
            try await db.collection("users").document(user.id).updateData([
                "visitHistory": dicts,
                "visitCount": dicts.count
            ])
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }

    // MARK: - 削除
    private func delete(at offsets: IndexSet) {
        guard let user = currentUser else { return }
        items.remove(atOffsets: offsets)
        Task { await saveAll(for: user) }
    }
}

// MARK: - 追加/編集シート
private struct AddOrEditVisitSheet: View {
    let userId: String
    let record: AdminVisitRecord?        // nil なら追加

    var onSaved: (AdminVisitRecord) -> Void

    // 入力
    @State private var date: Date = Date()
    @State private var menu: String = ""                 // 「メニュー」
    @State private var isCouponUsed: Bool = false        // 回数券 使用/未使用
    @State private var optionName: String = ""           // オプション：商品名
    @State private var priceText: String = ""            // オプション：金額

    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    init(userId: String, record: AdminVisitRecord?, onSaved: @escaping (AdminVisitRecord) -> Void) {
        self.userId = userId
        self.record = record
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("来店日", selection: $date, displayedComponents: [.date])
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                Section(header: Text("メイン入力")) {
                    TextField("メニュー（例：パーソナルレッスン）", text: $menu)
                    Toggle("回数券の使用", isOn: $isCouponUsed)
                }

                Section(header: Text("オプション")) {
                    TextField("商品名（任意）", text: $optionName)
                    TextField("金額（任意。半角数字）", text: $priceText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(record == nil ? "来店履歴を追加" : "来店履歴を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(record == nil ? "追加" : "保存") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                if let r = record {
                    // 既存 → 入力へ
                    if let d = AdminVisitRecord.dateFormatter.date(from: r.date) {
                        date = d
                    }
                    menu = r.menu
                    isCouponUsed = r.isCouponUsed
                    optionName = r.productName ?? ""
                    if let p = r.price { priceText = String(p) }
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        // 必須チェック
        guard !menu.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let price: Int? = Int(priceText.filter(\.isNumber))
        let saved = AdminVisitRecord(
            date: AdminVisitRecord.dateFormatter.string(from: date),
            menu: menu,
            isCouponUsed: isCouponUsed,
            productName: optionName.isEmpty ? nil : optionName,
            price: price
        )
        onSaved(saved)
        dismiss()
    }
}

// MARK: - 画面内専用モデル（Firestoreの辞書 <-> モデル）
private struct AdminVisitRecord: Identifiable, Equatable {
    let id = UUID()

    let date: String                // "yyyy/MM/dd"
    let menu: String                // 旧: note
    let isCouponUsed: Bool
    let productName: String?        // 旧: productName
    let price: Int?                 // 旧: price

    // 並べ替え用キー
    var sortKeyDate: Date {
        Self.dateFormatter.date(from: date) ?? .distantPast
    }

    // 変換
    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [
            "date": date,
            "note": menu,                // 既存互換: note にも入れておく
            "isCouponUsed": isCouponUsed
        ]
        if let productName { d["productName"] = productName }
        if let price { d["price"] = price }
        return d
    }

    static func from(dict: [String: Any]) -> Self? {
        // 既存データは "note" がメニューに相当
        guard let date = dict["date"] as? String else { return nil }
        let menu = (dict["menu"] as? String) ?? (dict["note"] as? String) ?? ""
        let used = (dict["isCouponUsed"] as? Bool) ?? false
        let product = dict["productName"] as? String
        let price = dict["price"] as? Int
        return .init(date: date, menu: menu, isCouponUsed: used, productName: product, price: price)
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()
}
