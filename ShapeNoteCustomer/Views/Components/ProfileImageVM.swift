import SwiftUI
import Combine
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

@MainActor
final class ProfileImageVM: ObservableObject {
    @Published var name: String = ""
    @Published var gender: String = ""
    @Published var birthYear: Int? = nil
    @Published var membershipRank: String = ""
    @Published var email: String = ""
    @Published var password: String = ""

    @Published var iconURL: URL?
    @Published var selectedImage: UIImage?
    @Published var isPickerPresented = false

    private let db = Firestore.firestore()
    // ✅ App初期化後の default instance を使用する（ShapeCore経由）
    private let storage = Storage.storage()
    private var listener: ListenerRegistration?
    private var uid: String? { Auth.auth().currentUser?.uid }

    init() {
        Task {
            await startRealtimeListener()
            await fetchIcon()
        }
    }

    deinit {
        listener?.remove()
    }

    // MARK: - リアルタイム監視
    func startRealtimeListener() async {
        guard let uid = uid else { return }
        listener?.remove()
        listener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let data = snapshot?.data() else {
                    if let error = error {
                        print("❌ Snapshot error: \(error.localizedDescription)")
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.name           = data["name"] as? String ?? ""
                    self.gender         = (data["gender"] as? String ?? "").lowercased()
                    self.birthYear      = data["birthYear"] as? Int
                    self.membershipRank = data["membershipRank"] as? String ?? ""
                    self.email          = data["email"] as? String ?? (Auth.auth().currentUser?.email ?? "")
                    print("🔄 Profile updated from Firestore snapshot")
                }
            }
    }

    // MARK: - 手動読み取り
    func loadProfile() async {
        guard let uid = uid else { return }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            let data = doc.data() ?? [:]
            self.name           = data["name"] as? String ?? ""
            self.gender         = (data["gender"] as? String ?? "").lowercased()
            self.birthYear      = data["birthYear"] as? Int
            self.membershipRank = data["membershipRank"] as? String ?? ""
            self.email          = data["email"] as? String ?? (Auth.auth().currentUser?.email ?? "")
            print("✅ Profile loaded manually")
        } catch {
            print("❌ Profile load failed: \(error.localizedDescription)")
        }
    }

    // MARK: - アイコン関連
    func fetchIcon() async {
        guard let uid = uid else { return }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if let urlString = doc.data()?["iconURL"] as? String,
               let url = URL(string: urlString) {
                self.iconURL = url
            }
        } catch {
            print("❌ アイコンURL取得失敗: \(error.localizedDescription)")
        }
    }

    func uploadIcon(_ image: UIImage) {
        guard let uid = uid else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.85) else { return }

        let path = "user_icons/\(uid)/profile.jpg"
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        print("📤 Upload start: \(path)")

        ref.putData(imageData, metadata: metadata) { [weak self] _, error in
            guard let self else { return }
            if let error = error {
                print("❌ 画像アップロード失敗: \(error.localizedDescription)")
                return
            }
            ref.downloadURL { url, err in
                if let err = err {
                    print("❌ ダウンロードURL取得失敗: \(err.localizedDescription)")
                    return
                }
                guard let url else { return }
                Task {
                    do {
                        try await self.db.collection("users").document(uid)
                            .setData(["iconURL": url.absoluteString], merge: true)
                        self.iconURL = url
                        self.selectedImage = nil
                        self.isPickerPresented = false
                        print("✅ アイコンURL登録成功: \(url.absoluteString)")
                    } catch {
                        print("❌ Firestore更新失敗: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
