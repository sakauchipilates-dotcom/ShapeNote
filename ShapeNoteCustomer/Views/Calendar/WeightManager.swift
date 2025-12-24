import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine
import ShapeCore

// MARK: - WeightRecord モデル
struct WeightRecord: Identifiable {
    let id: String
    let date: Date
    let weight: Double

    /// 測定条件（起床後/入浴前...）
    let condition: String?

    /// 体調コード（"veryGood" / "good" / "normal" / "bad" / "veryBad"）
    let health: String?

    /// 生理フラグ（任意）
    let isMenstruation: Bool

    /// 記録した時刻
    let recordedAt: Date?
}

@MainActor
final class WeightManager: ObservableObject {
    @Published var weights: [WeightRecord] = []
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
                guard let weight = d["weight"] as? Double,
                      let ts = d["date"] as? Timestamp else { return nil }

                let condition = d["condition"] as? String

                // 旧データ互換用（"good" / "normal" / "bad" だけが入っている可能性）
                let rawHealth = d["health"] as? String
                let healthCode = Self.normalizeHealthCode(rawHealth)

                let isMenstruation = d["isMenstruation"] as? Bool ?? false
                let recordedAt = (d["recordedAt"] as? Timestamp)?.dateValue()

                return WeightRecord(
                    id: doc.documentID,
                    date: ts.dateValue(),
                    weight: weight,
                    condition: condition,
                    health: healthCode,
                    isMenstruation: isMenstruation,
                    recordedAt: recordedAt
                )
            }

            // 目標体重と身長
            let goalDoc = try await db.collection("weights").document(uid).getDocument()
            if let g = goalDoc.data()?["goal"] as? Double {
                self.goalWeight = g
            }
            if let h = goalDoc.data()?["height"] as? Double {
                self.height = h
            }

        } catch {
            print("⚠️ 体重データ読込エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - Save / Update

    /// 体重・条件・体調・生理フラグを保存 / 更新
    func setWeight(
        for date: Date,
        weight: Double,
        condition: String = "起床後",
        health: String? = nil,             // "veryGood" / "good" / "normal" / "bad" / "veryBad"
        isMenstruation: Bool = false,
        recordedAt: Date = Date()
    ) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            let dayKey = Self.dayKey(date)
            try await db.collection("weights")
                .document(uid)
                .collection("daily")
                .document(dayKey)
                .setData([
                    "date": Timestamp(date: date),
                    "weight": weight,
                    "condition": condition,
                    "health": health as Any,
                    "isMenstruation": isMenstruation,
                    "recordedAt": Timestamp(date: recordedAt),
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)

            await loadWeights()
            print("✅ \(dayKey): \(weight)kg / \(condition) / health=\(health ?? "-") / menstruation=\(isMenstruation)")
        } catch {
            print("⚠️ 体重保存エラー: \(error.localizedDescription)")
        }
    }

    // 旧コード互換用（health / isMenstruation を渡さない古い呼び出しが残っていても動くように）
    func setWeight(
        for date: Date,
        weight: Double,
        condition: String,
        recordedAt: Date
    ) async {
        await setWeight(
            for: date,
            weight: weight,
            condition: condition,
            health: nil,
            isMenstruation: false,
            recordedAt: recordedAt
        )
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
    func weight(on date: Date) -> Double? {
        let key = Self.dayKey(date)
        return weights.first(where: { Self.dayKey($0.date) == key })?.weight
    }

    func condition(on date: Date) -> String? {
        let key = Self.dayKey(date)
        return weights.first(where: { Self.dayKey($0.date) == key })?.condition
    }

    func health(on date: Date) -> String? {
        let key = Self.dayKey(date)
        return weights.first(where: { Self.dayKey($0.date) == key })?.health
    }

    func isMenstruation(on date: Date) -> Bool {
        let key = Self.dayKey(date)
        return weights.first(where: { Self.dayKey($0.date) == key })?.isMenstruation ?? false
    }

    /// カレンダー表示用：体調の絵文字
    func healthEmoji(on date: Date) -> String? {
        guard let code = health(on: date) else { return nil }
        switch code {
        case "veryGood":
            return "😄"
        case "good":
            return "🙂"
        case "normal":
            return "😐"
        case "bad":
            return "😢"
        case "veryBad":
            return "😭"
        default:
            return nil
        }
    }

    func recordedTime(on date: Date) -> Date? {
        let key = Self.dayKey(date)
        return weights.first(where: { Self.dayKey($0.date) == key })?.recordedAt
    }

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

    /// 旧 3 段階の health 値を 5 段階コードに寄せる
    private static func normalizeHealthCode(_ raw: String?) -> String? {
        guard let raw else { return nil }
        switch raw {
        case "veryGood", "good", "normal", "bad", "veryBad":
            return raw                      // すでに 5 段階コード
        case "good":
            return "good"
        case "bad":
            return "bad"
        case "normal":
            return "normal"
        default:
            return nil
        }
    }
}
