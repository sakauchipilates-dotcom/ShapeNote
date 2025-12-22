import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine
import ShapeCore

// MARK: - WeightRecord（モデル）
struct WeightRecord: Identifiable {
    let id: String
    let date: Date
    let weight: Double

    /// 測定条件（起床後/入浴前...）
    let condition: String?

    /// 体調（good/normal/bad）
    let health: String?

    /// 記録時刻
    let recordedAt: Date?
}

@MainActor
final class WeightManager: ObservableObject {

    @Published var weights: [WeightRecord] = []

    // ここは既存仕様維持
    @Published var goalWeight: Double = 55.0
    @Published var height: Double = 1.65

    private let db = Firestore.firestore()

    // MARK: - Load
    func loadWeights() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            let snapshot = try await db.collection("weights")
                .document(uid)
                .collection("daily")
                .order(by: "date", descending: false)
                .getDocuments()

            self.weights = snapshot.documents.compactMap { doc in
                let d = doc.data()

                guard
                    let weight = d["weight"] as? Double,
                    let ts = d["date"] as? Timestamp
                else { return nil }

                let condition = d["condition"] as? String
                let health = d["health"] as? String
                let recordedAt = (d["recordedAt"] as? Timestamp)?.dateValue()

                return WeightRecord(
                    id: doc.documentID,
                    date: ts.dateValue(),
                    weight: weight,
                    condition: condition,
                    health: health,
                    recordedAt: recordedAt
                )
            }

            // 目標体重と身長（weights/{uid}）
            let goalDoc = try await db.collection("weights").document(uid).getDocument()
            if let g = goalDoc.data()?["goal"] as? Double { self.goalWeight = g }
            if let h = goalDoc.data()?["height"] as? Double { self.height = h }

        } catch {
            print("⚠️ 体重データ読込エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - Save / Update（本命API：condition + health を分離して保存）
    func setWeight(
        for date: Date,
        weight: Double,
        condition: String = "起床後",
        health: String? = nil,
        recordedAt: Date = Date()
    ) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            let dayKey = Self.dayKey(date)

            var data: [String: Any] = [
                "date": Timestamp(date: date),
                "weight": weight,
                "condition": condition,
                "recordedAt": Timestamp(date: recordedAt),
                "updatedAt": FieldValue.serverTimestamp()
            ]

            // nil のときは保存しない（フィールドを汚さない）
            if let health {
                data["health"] = health
            }

            try await db.collection("weights")
                .document(uid)
                .collection("daily")
                .document(dayKey)
                .setData(data, merge: true)

            await loadWeights()
            print("✅ \(dayKey): \(weight)kg / condition=\(condition) / health=\(health ?? "-") saved")

        } catch {
            print("⚠️ 体重保存エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - 互換API（WeightInputSheet が "起床後||good" を渡しても動く）
    /// - Parameter conditionPacked:
    ///   - 旧: "起床後"
    ///   - 新: "起床後||good" のように packed される（WeightInputSheetがそう渡す）
    func setWeight(
        for date: Date,
        weight: Double,
        conditionPacked: String = "起床後",
        recordedAt: Date = Date()
    ) async {
        let (condition, health) = Self.unpackCondition(conditionPacked)
        await setWeight(for: date, weight: weight, condition: condition, health: health, recordedAt: recordedAt)
    }

    // 既存呼び出し互換（引数ラベルが condition のままでもOK）
    func setWeight(
        for date: Date,
        weight: Double,
        condition: String = "起床後",
        recordedAt: Date = Date()
    ) async {
        await setWeight(for: date, weight: weight, conditionPacked: condition, recordedAt: recordedAt)
    }

    // MARK: - Delete
    func deleteWeight(for date: Date) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let dayKey = Self.dayKey(date)

        do {
            try await db.collection("weights")
                .document(uid)
                .collection("daily")
                .document(dayKey)
                .delete()
            print("🗑️ \(dayKey) の体重を削除しました")
            await loadWeights()
        } catch {
            print("⚠️ 体重削除エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - Goal / Height
    func setGoal(_ value: Double) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("weights").document(uid).setData(["goal": value], merge: true)
            self.goalWeight = value
        } catch {
            print("⚠️ 目標体重保存エラー: \(error.localizedDescription)")
        }
    }

    func setHeight(_ value: Double) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("weights").document(uid).setData(["height": value], merge: true)
            self.height = value
        } catch {
            print("⚠️ 身長保存エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - BMI
    var bmi: Double? {
        guard let latest = weights.last else { return nil }
        guard height > 0 else { return nil }
        return latest.weight / (height * height)
    }

    // MARK: - Query Helpers
    func record(on date: Date) -> WeightRecord? {
        let key = Self.dayKey(date)
        return weights.first(where: { Self.dayKey($0.date) == key })
    }

    func weight(on date: Date) -> Double? { record(on: date)?.weight }
    func condition(on date: Date) -> String? { record(on: date)?.condition }
    func health(on date: Date) -> String? { record(on: date)?.health }
    func recordedTime(on date: Date) -> Date? { record(on: date)?.recordedAt }

    /// CalendarGridView 用：体調ドット色
    /// ※ Theme.semanticColor.warning が存在しない構成でも落ちないようにしている
    func healthColor(on date: Date) -> Color? {
        guard let raw = health(on: date) else { return nil }
        switch raw {
        case "good":
            return Theme.sub
        case "normal":
            return Theme.accent
        case "bad":
            // warning 定義が無い場合に備えて accent を濃くして代用
            if let c = ThemeWarningColorProvider.warningOrNil {
                return c
            } else {
                return Theme.accent.opacity(0.95)
            }
        default:
            return nil
        }
    }

    // MARK: - Chart Helpers
    var last30Days: [WeightRecord] {
        guard let since = Calendar.current.date(byAdding: .day, value: -29, to: Date()) else { return weights }
        return weights.filter { $0.date >= since }
    }

    // MARK: - Utilities
    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = .init(identifier: "ja_JP")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// "起床後||good" を (condition, health) に分解
    /// - 旧データ "起床後" は condition のみ（health=nil）
    private static func unpackCondition(_ packed: String) -> (String, String?) {
        // "起床後||good" -> split("|", omittingEmpty=true) で ["起床後", "good"]
        let parts = packed.split(separator: "|", omittingEmptySubsequences: true).map(String.init)
        if parts.count >= 2 {
            return (parts[0], parts[1])
        } else {
            return (packed, nil)
        }
    }
}

// MARK: - Theme warning の安全アクセス（ビルド構成差異の吸収）
private enum ThemeWarningColorProvider {
    /// Theme.semanticColor.warning があるプロジェクトではそれを返す。
    /// 無い場合は nil を返す（呼び出し側でフォールバックする）
    static var warningOrNil: Color? {
        // ここは「Theme に warning を足した構成」なら差し替えてOK
        // 例：return Theme.semanticColor.warning
        nil
    }
}
