import SwiftUI
import FirebaseFirestore
import ShapeCore

struct AdminMemberDetailView: View {
    // 入力対象ユーザー
    let user: UserItem

    // 氏名・カナ
    @State private var lastName: String
    @State private var firstName: String
    @State private var lastNameKana: String
    @State private var firstNameKana: String

    // 性別・生年月日・ランク
    @State private var gender: UserItem.Gender
    @State private var birthDate: Date?
    @State private var membershipRank: UserItem.Rank

    // UI状態
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var isLoadingExtra = false

    private let db = Firestore.firestore()

    // MARK: - Init
    init(user: UserItem) {
        self.user = user

        let parts = user.name.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let defaultLast = parts.first.map(String.init) ?? user.name
        let defaultFirst = parts.count > 1 ? String(parts[1]) : ""

        _lastName = State(initialValue: defaultLast)
        _firstName = State(initialValue: defaultFirst)
        _lastNameKana = State(initialValue: "")
        _firstNameKana = State(initialValue: "")
        _gender = State(initialValue: user.gender)
        _membershipRank = State(initialValue: user.membershipRank ?? .regular)

        if let y = user.birthYear {
            let comps = DateComponents(year: y, month: 1, day: 1)
            _birthDate = State(initialValue: Calendar.current.date(from: comps))
        } else {
            _birthDate = State(initialValue: nil)
        }
    }

    // MARK: - View
    var body: some View {
        Form {
            // MARK: - 来店履歴セクション
            Section {
                // 🔹 preselectedUserとして現在のuserを渡す
                NavigationLink {
                    AdminVisitHistoryView(preselectedUser: user)
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(.blue)
                        Text("来店履歴を管理")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.tertiaryText)
                    }
                }
            } header: {
                Text("来店履歴")
            } footer: {
                Text("来店履歴の追加・削除・編集は遷移先の画面で行えます。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            // MARK: - 基本情報
            Section(header: Text("基本情報")) {
                HStack {
                    TextField("姓", text: $lastName)
                    TextField("名", text: $firstName)
                }

                HStack {
                    TextField("セイ（カタカナ）", text: $lastNameKana)
                        .textInputAutocapitalization(.characters)
                    TextField("メイ（カタカナ）", text: $firstNameKana)
                        .textInputAutocapitalization(.characters)
                }

                Picker("性別", selection: $gender) {
                    ForEach(UserItem.Gender.allCases, id: \.self) { g in
                        Text(g.label).tag(g)
                    }
                }
                .pickerStyle(.segmented)

                // 生年月日
                DatePicker(
                    "生年月日",
                    selection: Binding<Date>(
                        get: { birthDate ?? Date() },
                        set: { birthDate = $0 }
                    ),
                    displayedComponents: [.date]
                )
                .environment(\.locale, Locale(identifier: "ja_JP"))

                if let date = birthDate {
                    let age = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
                    Text("現在の年齢：\(age)歳")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Picker("ランク", selection: $membershipRank) {
                    ForEach(UserItem.Rank.allCases, id: \.self) { r in
                        Text(r.label).tag(r)
                    }
                }
            }

            // MARK: - 保存
            Section {
                Button {
                    Task { await saveChanges() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Label("変更を保存", systemImage: "square.and.arrow.down")
                    }
                }
                .disabled(isSaving)
            }

            // MARK: - メッセージ
            if let msg = saveMessage {
                Section {
                    Text(msg)
                        .foregroundColor(.secondary)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("会員詳細")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadExtraFieldsIfAny() }
    }

    // MARK: - Firestoreデータ読込
    private func loadExtraFieldsIfAny() async {
        isLoadingExtra = true
        defer { isLoadingExtra = false }

        do {
            let snap = try await db.collection("users").document(user.id).getDocument()
            guard let data = snap.data() else { return }

            let ln = (data["lastName"] as? String) ?? lastName
            let fn = (data["firstName"] as? String) ?? firstName
            let lnk = (data["lastNameKana"] as? String) ?? ""
            let fnk = (data["firstNameKana"] as? String) ?? ""

            var newBirth: Date? = birthDate
            if let y = data["birthYear"] as? Int {
                let m = (data["birthMonth"] as? Int) ?? 1
                let d = (data["birthDay"] as? Int) ?? 1
                newBirth = Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
            }

            await MainActor.run {
                self.lastName = ln
                self.firstName = fn
                self.lastNameKana = lnk
                self.firstNameKana = fnk
                self.birthDate = newBirth
            }
        } catch {
            print("Load extra fields error: \(error.localizedDescription)")
        }
    }

    // MARK: - Firestore保存処理
    private func saveChanges() async {
        guard !lastName.isEmpty, !firstName.isEmpty else {
            saveMessage = "⚠️ 姓名を入力してください"
            return
        }
        guard isKatakana(lastNameKana), isKatakana(firstNameKana) else {
            saveMessage = "⚠️ フリガナはカタカナで入力してください"
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            var update: [String: Any] = [
                "lastName": lastName,
                "firstName": firstName,
                "lastNameKana": lastNameKana,
                "firstNameKana": firstNameKana,
                "gender": gender.rawValue,
                "membershipRank": membershipRank.rawValue,
                "name": "\(lastName) \(firstName)"
            ]

            if let bd = birthDate {
                let c = Calendar.current.dateComponents([.year, .month, .day], from: bd)
                update["birthYear"] = c.year
                update["birthMonth"] = c.month
                update["birthDay"] = c.day
            } else {
                update["birthYear"] = FieldValue.delete()
                update["birthMonth"] = FieldValue.delete()
                update["birthDay"] = FieldValue.delete()
            }

            try await db.collection("users").document(user.id).updateData(update)
            saveMessage = "✅ Firestoreに変更を保存しました"
        } catch {
            saveMessage = "❌ 保存に失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - カタカナ判定
    private func isKatakana(_ text: String) -> Bool {
        if text.isEmpty { return true }
        let pattern = "^[\\u30A0-\\u30FFー\\s]+$"
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Color
private extension Color {
    static let tertiaryText = Color(UIColor.tertiaryLabel)
}
