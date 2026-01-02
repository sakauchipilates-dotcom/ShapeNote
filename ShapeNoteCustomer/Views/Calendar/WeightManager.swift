import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine
import ShapeCore
import Foundation

// MARK: - WeightRecord モデル
struct WeightRecord: Identifiable, Equatable {
    let id: String
    let date: Date
    let weight: Double
    let condition: String?
    let health: String?
    let isMenstruation: Bool
    let recordedAt: Date?
}

@MainActor
final class WeightManager: ObservableObject {

    // MARK: - Published
    @Published var weights: [WeightRecord] = []
    @Published var goalWeight: Double = 55.0
    @Published var height: Double = 1.65

    /// ✅ 無料制限に引っかかった等、UI側に通知したい文言
    @Published var gateMessage: String? = nil

    // MARK: - Subscription (injected)
    private(set) var subscriptionState: SubscriptionState = .free

    func setSubscriptionState(_ state: SubscriptionState) {
        self.subscriptionState = state
    }

    // MARK: - Firestore
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
                let rawHealth = d["health"] as? String
                let isMenstruation = d["isMenstruation"] as? Bool ?? false
                let recordedAt = (d["recordedAt"] as? Timestamp)?.dateValue()

                return WeightRecord(
                    id: doc.documentID,
                    date: ts.dateValue(),
                    weight: weight,
                    condition: condition,
                    health: rawHealth,
                    isMenstruation: isMenstruation,
                    recordedAt: recordedAt
                )
            }

            // 目標体重と身長
            let goalDoc = try await db.collection("weights").document(uid).getDocument()
            if let g = goalDoc.data()?["goal"] as? Double { self.goalWeight = g }
            if let h = goalDoc.data()?["height"] as? Double { self.height = h }

        } catch {
            print("⚠️ 体重データ読込エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - Add (新規レコード作成)
    func addRecord(
        for date: Date,
        weight: Double,
        condition: String = "起床後",
        health: String? = nil,
        isMenstruation: Bool = false,
        recordedAt: Date = Date()
    ) async {

        // ✅ 無料：1日1回まで（同日に既に記録があればブロック）
        if !subscriptionState.isPremium {
            let count = records(on: date).count
            if !SNUsageLimit.canAddWeightRecordFree(existingCountForDay: count) {
                gateMessage = "無料会員は1日1回まで記録できます（毎日0時にリセット）。"
                print("⛔️ blocked: free daily limit (count=\(count))")
                return
            }
        }

        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            let docId = Self.makeDocId(date: date, recordedAt: recordedAt)

            var data: [String: Any] = [
                "date": Timestamp(date: date),
                "weight": weight,
                "condition": condition,
                "isMenstruation": isMenstruation,
                "recordedAt": Timestamp(date: recordedAt),
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]

            if let health = health {
                data["health"] = health
            }

            try await db.collection("weights")
                .document(uid)
                .collection("daily")
                .document(docId)
                .setData(data, merge: false)

            await loadWeights()
            print("✅ ADD \(docId)")
        } catch {
            print("⚠️ 体重追加エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - Update (既存レコード更新)
    func updateRecord(
        recordId: String,
        date: Date,
        weight: Double,
        condition: String = "起床後",
        health: String? = nil,
        isMenstruation: Bool = false,
        recordedAt: Date = Date()
    ) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            var data: [String: Any] = [
                "date": Timestamp(date: date),
                "weight": weight,
                "condition": condition,
                "isMenstruation": isMenstruation,
                "recordedAt": Timestamp(date: recordedAt),
                "updatedAt": FieldValue.serverTimestamp()
            ]

            if let health = health {
                data["health"] = health
            } else {
                data["health"] = FieldValue.delete()
            }

            try await db.collection("weights")
                .document(uid)
                .collection("daily")
                .document(recordId)
                .setData(data, merge: true)

            await loadWeights()
            print("✅ UPDATE \(recordId)")
        } catch {
            print("⚠️ 体重更新エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete (レコードID単位で削除)
    func deleteRecord(recordId: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            try await db.collection("weights")
                .document(uid)
                .collection("daily")
                .document(recordId)
                .delete()

            await loadWeights()
            print("🗑️ DELETE \(recordId)")
        } catch {
            print("⚠️ 体重削除エラー: \(error.localizedDescription)")
        }
    }

    // MARK: - Goal / Height
    /// 既存API（残す：他のファイル互換）
    func setGoal(_ value: Double) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("weights").document(uid).setData(["goal": value], merge: true)
            self.goalWeight = value
        } catch {
            print("⚠️ 目標体重保存エラー: \(error.localizedDescription)")
        }
    }

    /// CalendarView が呼ぶ互換API
    func setGoalWeight(_ value: Double) async {
        await setGoal(value)
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

    // MARK: - Query (日付単位で取得) ※複数入力対応
    func records(on day: Date) -> [WeightRecord] {
        let key = Self.dayKey(day)
        return weights
            .filter { Self.dayKey($0.date) == key }
            .sorted {
                let l = $0.recordedAt ?? $0.date
                let r = $1.recordedAt ?? $1.date
                return l > r
            }
    }

    func latestRecord(on day: Date) -> WeightRecord? {
        records(on: day).first
    }

    // 既存API互換（「その日=1件」前提の旧呼び出しが残ってても崩れない）
    func weight(on date: Date) -> Double? { latestRecord(on: date)?.weight }
    func condition(on date: Date) -> String? { latestRecord(on: date)?.condition }
    func health(on date: Date) -> String? { latestRecord(on: date)?.health }
    func isMenstruation(on date: Date) -> Bool { records(on: date).contains(where: { $0.isMenstruation }) }
    func recordedTime(on date: Date) -> Date? { latestRecord(on: date)?.recordedAt }

    // MARK: - Health decode (統一：HealthStoragePayload)
    /// raw が JSON の場合のみ decode して返す（旧形式は nil）
    func healthPayload(from raw: String?) -> HealthStoragePayload? {
        guard let raw,
              let data = raw.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(HealthStoragePayload.self, from: data)
    }

    /// 旧("normal") / 新(JSON) 両対応で HealthLevel5 を返す
    func healthLevel5(from raw: String?) -> HealthLevel5? {
        guard let raw else { return nil }

        // 新形式(JSON)
        if let payload = healthPayload(from: raw),
           let level = HealthLevel5(rawValue: payload.level) {
            return level
        }

        // 旧形式("normal" 等)
        return HealthLevel5(rawValue: raw)
    }

    /// 旧/新 両対応で markers を返す（旧形式は空）
    func healthMarkers(from raw: String?) -> [String] {
        guard let payload = healthPayload(from: raw) else { return [] }
        return payload.markers
    }

    // MARK: - Month/Year helpers（Charts用）
    func records(inSameMonthAs baseMonth: Date, calendar: Calendar) -> [WeightRecord] {
        weights.filter { calendar.isDate($0.date, equalTo: baseMonth, toGranularity: .month) }
    }

    func records(inSameYearAs baseYear: Date, calendar: Calendar) -> [WeightRecord] {
        weights.filter { calendar.isDate($0.date, equalTo: baseYear, toGranularity: .year) }
    }

    // 同日の複数入力を潰して「日ごと最新」にする
    func latestPerDay(records: [WeightRecord], calendar: Calendar) -> [WeightRecord] {
        var latestByKey: [String: WeightRecord] = [:]

        for r in records {
            let key = Self.dayKey(r.date)
            if let existing = latestByKey[key] {
                let a = r.recordedAt ?? r.date
                let b = existing.recordedAt ?? existing.date
                if a > b { latestByKey[key] = r }
            } else {
                latestByKey[key] = r
            }
        }
        return Array(latestByKey.values)
    }

    // 月ごと最新（1..12）
    func latestPerMonth(records: [WeightRecord], calendar: Calendar) -> [Int: WeightRecord] {
        var latest: [Int: WeightRecord] = [:]

        for r in records {
            let m = calendar.component(.month, from: r.date)
            if let existing = latest[m] {
                let a = r.recordedAt ?? r.date
                let b = existing.recordedAt ?? existing.date
                if a > b { latest[m] = r }
            } else {
                latest[m] = r
            }
        }
        return latest
    }

    // MARK: - Utilities
    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = .init(identifier: "ja_JP")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func makeDocId(date: Date, recordedAt: Date) -> String {
        let day = dayKey(date)
        let sec = Int(recordedAt.timeIntervalSince1970)
        return "\(day)_\(sec)"
    }

    private func healthLevelCode(from raw: String?) -> String? {
        guard let raw else { return nil }
        if let payload = healthPayload(from: raw) {
            return payload.level
        }
        return raw
    }

    func healthEmoji(on date: Date) -> String? {
        guard let levelCode = healthLevelCode(from: health(on: date)) else { return nil }
        switch levelCode {
        case "great", "veryGood": return "😄"
        case "good": return "🙂"
        case "normal": return "😐"
        case "bad": return "😢"
        case "veryBad": return "😭"
        default: return nil
        }
    }

    var bmi: Double? {
        let latest = weights
            .sorted {
                let l = $0.recordedAt ?? $0.date
                let r = $1.recordedAt ?? $1.date
                return l > r
            }
            .first

        guard let latest, height > 0 else { return nil }
        return latest.weight / (height * height)
    }

    var last30Days: [WeightRecord] {
        guard let since = Calendar.current.date(byAdding: .day, value: -29, to: Date()) else { return weights }
        return weights.filter { $0.date >= since }
    }
}
