import Foundation
import FirebaseAuth
import FirebaseFirestore
import Security

@MainActor
public final class AuthHandler: ObservableObject, @unchecked Sendable {

    public static let shared = AuthHandler()
    private init() {}

    // MARK: - Firebaseログイン
    public func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let user = result?.user else {
                completion(.failure(NSError(domain: "AuthHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found."])))
                return
            }
            self.saveCredentials(email: email, password: password)
            self.saveLoginDate()
            completion(.success(user))
        }
    }

    // MARK: - Firebase新規登録（Firestore初期登録付き）
    public func signUp(email: String, password: String, name: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let user = result?.user else {
                completion(.failure(NSError(domain: "AuthHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not found."])))
                return
            }

            Task {
                do {
                    try await self.createUserProfile(uid: user.uid, name: name, email: email)
                    self.saveCredentials(email: email, password: password)
                    self.saveLoginDate()
                    completion(.success(user))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Firestoreにユーザー情報を作成（初回のみ）
    public func createUserProfile(uid: String, name: String, email: String) async throws {
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(uid)

        // 既に存在する場合はスキップ
        let snapshot = try await docRef.getDocument()
        if snapshot.exists { return }

        // ✅ ランダム4桁の顧客表示用ID（PTB-XXXX形式）
        let displayId = "PTB-" + String(Int.random(in: 1000...9999))

        // Firestoreに登録
        try await docRef.setData([
            "uid": uid,
            "displayId": displayId,
            "name": name,
            "email": email,
            "membershipRank": "Bronze",
            "visitCount": 0,
            "joinedAt": Timestamp(date: Date())
        ])
        print("✅ Firestoreに新規ユーザー登録完了: \(displayId)")
    }

    // MARK: - Firebaseログアウト
    public func signOut() {
        do {
            try Auth.auth().signOut()
            print("✅ サインアウト完了")
        } catch {
            print("⚠️ サインアウトエラー: \(error.localizedDescription)")
        }
        if let email = Auth.auth().currentUser?.email {
            deleteCredentials(for: email)
        }
        UserDefaults.standard.removeObject(forKey: "lastLoginDate")
    }

    // MARK: - 現在のFirebaseユーザー
    public var currentUser: User? {
        Auth.auth().currentUser
    }

    public var currentUID: String? {
        Auth.auth().currentUser?.uid
    }

    public var currentUserName: String {
        Auth.auth().currentUser?.displayName ??
        Auth.auth().currentUser?.email ??
        "未登録ユーザー"
    }

    // MARK: - Keychain 保存／取得／削除
    public func saveCredentials(email: String, password: String) {
        let data = password.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: email
        ]
        let attrs: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: email,
                kSecValueData as String: data
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
            print("🔑 Keychain新規登録: \(email)")
        } else {
            print("🔁 Keychain更新: \(email)")
        }
        UserDefaults.standard.set(email, forKey: "lastEmail")
    }

    public func loadPassword(for email: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: email,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let password = String(data: data, encoding: .utf8) else { return nil }
        return password
    }

    public func deleteCredentials(for email: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: email
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - ログイン状態チェック
    public func saveLoginDate() {
        UserDefaults.standard.set(Date(), forKey: "lastLoginDate")
    }

    public func isLoginValid(days: Int = 30) -> Bool {
        guard let lastLogin = UserDefaults.standard.object(forKey: "lastLoginDate") as? Date else {
            return false
        }
        let elapsed = Date().timeIntervalSince(lastLogin)
        return elapsed < Double(days * 24 * 60 * 60)
    }

    // MARK: - パスワードリセット（本人確認メール送信）
    public func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            print("📩 パスワードリセットメール送信成功: \(email)")
        } catch {
            print("❌ パスワードリセットメール送信失敗: \(error.localizedDescription)")
            throw error
        }
    }
}
