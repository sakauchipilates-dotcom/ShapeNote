import Foundation

enum SNUsageLimit {

    /// 無料：同じ日（JST）の記録が既に1件以上あればブロック
    static func canAddWeightRecordFree(existingCountForDay: Int) -> Bool {
        existingCountForDay == 0
    }

    /// 無料：月1回（毎月1日にリセット）姿勢撮影
    static func canCapturePostureFree(lastCaptured: Date?, now: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> Bool {
        guard let lastCaptured else { return true }
        return !calendar.isDate(lastCaptured, equalTo: now, toGranularity: .month)
    }

    /// 次回リセット日（翌月1日 00:00）
    static func nextPostureResetDate(now: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> Date? {
        let comps = calendar.dateComponents([.year, .month], from: now)
        guard let year = comps.year, let month = comps.month else { return nil }
        var next = DateComponents()
        next.year = year
        next.month = month + 1
        next.day = 1
        next.hour = 0
        next.minute = 0
        next.second = 0
        return calendar.date(from: next)
    }
}
