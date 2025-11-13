import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

// MARK: - WeightRecord モデル拡張
struct WeightRecord: Identifiable {
    let id: String
    let date: Date
    let weight: Double
    let condition: String?
    let recordedAt: Date?
}

@MainActor
final class WeightManager: ObservableObject {
    @Published var weights: [WeightRecord] = []
    @Published var goalWeight: Double = 55.0  // デフォルト目標
    @Published var height: Double = 1.65      // デフォルト身長（m単位）

    private let db = Firestore.firestore()

    // MARK: - 🔹 体重一覧 & 目標体重 + 身長の読込
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
                let recordedAt = (d["recordedAt"] as? Timestamp)?.dateValue()

                return WeightRecord(
                    id: doc.documentID,
                    date: ts.dateValue(),
                    weight: weight,
                    condition: condition,
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

    // MARK: - 🔹 その日の体重を登録/更新（条件＆時刻付き）
    func setWeight(for date: Date, weight: Double, condition: String = "起床後", recordedAt: Date = Date()) async {
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
                    "recordedAt": Timestamp(date: recordedAt),
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)
            await loadWeights()
            print("✅ \(dayKey): \(weight)kg (\(condition)) を保存")
        } catch {
            print("⚠️ 体重保存エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - 🔹 体重削除
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

    // MARK: - 🔹 目標体重を保存
    func setGoal(_ value: Double) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("weights").document(uid).setData(["goal": value], merge: true)
            self.goalWeight = value
        } catch {
            print("⚠️ 目標体重保存エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - 🔹 身長を保存
    func setHeight(_ value: Double) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("weights").document(uid).setData(["height": value], merge: true)
            self.height = value
        } catch {
            print("⚠️ 身長保存エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - 🔹 BMI計算（最新体重使用）
    var bmi: Double? {
        guard let latest = weights.last else { return nil }
        guard height > 0 else { return nil }
        return latest.weight / (height * height)
    }

    // MARK: - 🔹 指定日付の体重（無ければ nil）
    func weight(on date: Date) -> Double? {
        let key = Self.dayKey(date)
        return weights.first(where: { Self.dayKey($0.date) == key })?.weight
    }

    // MARK: - 🔹 指定日の測定条件
    func condition(on date: Date) -> String? {
        let key = Self.dayKey(date)
        return weights.first(where: { Self.dayKey($0.date) == key })?.condition
    }

    // MARK: - 🔹 指定日の記録時刻
    func recordedTime(on date: Date) -> Date? {
        let key = Self.dayKey(date)
        return weights.first(where: { Self.dayKey($0.date) == key })?.recordedAt
    }

    // MARK: - 🔹 折れ線/棒グラフ用の期間抽出（直近30日）
    var last30Days: [WeightRecord] {
        guard let since = Calendar.current.date(byAdding: .day, value: -29, to: Date()) else { return weights }
        return weights.filter { $0.date >= since }
    }

    // MARK: - 🔹 yyyy-MM-dd で日付キー化
    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = .init(identifier: "ja_JP")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
