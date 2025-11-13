import Foundation
import FirebaseFirestore
import Combine
import ShapeCore

@MainActor
final class AdminUserListVM: ObservableObject {
    @Published private(set) var users: [UserItem] = []
    @Published var searchText: String = ""
    @Published var sortNewToOld: Bool = true
    
    // 🔹複数選択フィルタ
    @Published var selectedGenders: [UserItem.Gender] = []
    @Published var selectedDecades: [Int] = []
    @Published var selectedRanks: [UserItem.Rank] = []
    
    private var listener: ListenerRegistration?
    
    init() {
        startListening()
    }
    deinit { listener?.remove() }
    
    // MARK: - Firestore購読
    func startListening() {
        listener?.remove()
        let db = Firestore.firestore()
        listener = db.collection("users")
            .order(by: "joinedAt", descending: sortNewToOld)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error = error {
                    print("❌ Firestore Listener Error: \(error.localizedDescription)")
                    return
                }
                guard let snapshot else { return }
                let items = snapshot.documents.compactMap(UserItem.from(document:))
                Task { @MainActor in self.users = items }
            }
    }
    
    // MARK: - フィルタリング結果
    var filteredUsers: [UserItem] {
        var result = users
        
        // 🔍 検索
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter { $0.name.lowercased().contains(q) || $0.email.lowercased().contains(q) }
        }
        
        // 🚻 性別（複数可）
        if !selectedGenders.isEmpty {
            result = result.filter { selectedGenders.contains($0.gender) }
        }
        
        // 🎂 年代（複数可）
        if !selectedDecades.isEmpty {
            result = result.filter {
                guard let by = $0.birthYear else { return false }
                let decade = Self.decadeFromBirthYear(by)
                return selectedDecades.contains(decade)
            }
        }
        
        // 🏅 ランク（複数可）
        if !selectedRanks.isEmpty {
            result = result.filter { rank in
                if let r = rank.membershipRank {
                    return selectedRanks.contains(r)
                }
                return false
            }
        }
        
        // ⏰ 並び替え
        result.sort { a, b in
            let ad = a.joinedAt ?? .distantPast
            let bd = b.joinedAt ?? .distantPast
            return sortNewToOld ? ad > bd : ad < bd
        }
        return result
    }
    
    // MARK: - 切替処理（即時反映）
    func toggleGender(label: String) {
        guard let g = UserItem.Gender.fromLabel(label) else { return }
        if selectedGenders.contains(g) {
            selectedGenders.removeAll { $0 == g }
        } else {
            selectedGenders.append(g)
        }
    }
    
    func toggleDecade(label: String) {
        if let val = Int(label.replacingOccurrences(of: "代", with: "")) {
            if selectedDecades.contains(val) {
                selectedDecades.removeAll { $0 == val }
            } else {
                selectedDecades.append(val)
            }
        }
    }
    
    func toggleRank(label: String) {
        guard let r = UserItem.Rank.fromLabel(label) else { return }
        if selectedRanks.contains(r) {
            selectedRanks.removeAll { $0 == r }
        } else {
            selectedRanks.append(r)
        }
    }
    
    // MARK: - 選択状態判定
    func isGenderSelected(label: String) -> Bool {
        guard let g = UserItem.Gender.fromLabel(label) else { return false }
        return selectedGenders.contains(g)
    }
    func isDecadeSelected(label: String) -> Bool {
        if let val = Int(label.replacingOccurrences(of: "代", with: "")) {
            return selectedDecades.contains(val)
        }
        return false
    }
    func isRankSelected(label: String) -> Bool {
        guard let r = UserItem.Rank.fromLabel(label) else { return false }
        return selectedRanks.contains(r)
    }
    
    func resetFilters() {
        selectedGenders.removeAll()
        selectedDecades.removeAll()
        selectedRanks.removeAll()
        searchText = ""
    }
    
    // MARK: - ユーティリティ
    static func decadeFromBirthYear(_ birthYear: Int) -> Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        let age = max(0, currentYear - birthYear)
        let decade = (age / 10) * 10
        return max(10, decade)
    }
}

// MARK: - Enumラベル対応
extension UserItem.Gender {
    static func fromLabel(_ label: String) -> Self? {
        switch label {
        case "男性": .male
        case "女性": .female
        case "不明": .unknown
        default: nil
        }
    }
}

extension UserItem.Rank {
    static func fromLabel(_ label: String) -> Self? {
        switch label {
        case "レギュラー": .regular
        case "ブロンズ": .bronze
        case "シルバー": .silver
        case "ゴールド": .gold
        case "プラチナ": .platinum
        default: nil
        }
    }
}
