import Foundation
import UserNotifications

/// 記録リマインドの設定
struct RecordReminderSettings: Codable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    /// デフォルト値（例：21:00 にリマインド）
    static let `default` = RecordReminderSettings(
        isEnabled: true,
        hour: 21,
        minute: 0
    )
}

/// 記録リマインド設定の管理クラス
final class RecordReminderManager {

    static let shared = RecordReminderManager()
    private init() {}

    private let userDefaultsKey = "RecordReminderSettings"
    private let notificationIdentifier = "record-reminder-daily"

    // MARK: - Settings I/O

    /// 保存されているリマインド設定を読み込む
    func loadSettings() -> RecordReminderSettings {
        let ud = UserDefaults.standard

        if let data = ud.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(RecordReminderSettings.self, from: data) {
            return decoded
        }

        // まだ一度も保存していない場合はデフォルト値
        return .default
    }

    /// 設定を更新して保存する
    ///
    /// - Note:
    ///   - UserDefaults への保存
    ///   - `@AppStorage("recordReminderEnabled")` とも値を同期
    ///   - ローカル通知のスケジュール／キャンセルもここで行う
    func updateSettings(_ settings: RecordReminderSettings) {
        let ud = UserDefaults.standard

        if let data = try? JSONEncoder().encode(settings) {
            ud.set(data, forKey: userDefaultsKey)
        }

        // MyPage 側の @AppStorage とキーを合わせておく
        ud.set(settings.isEnabled, forKey: "recordReminderEnabled")

        ud.synchronize()

        if settings.isEnabled {
            scheduleNotifications(for: settings)
        } else {
            cancelNotifications()
        }
    }

    // MARK: - Local Notifications

    /// 毎日指定時刻に記録リマインドのローカル通知をスケジュールする
    func scheduleNotifications(for settings: RecordReminderSettings) {
        let center = UNUserNotificationCenter.current()

        // まず既存のスケジュールをクリア
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        // 通知権限をリクエスト
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("❌ record reminder auth error: \(error.localizedDescription)")
            }

            guard granted else {
                print("⚠️ record reminder notification not granted")
                return
            }

            var dateComponents = DateComponents()
            dateComponents.hour = settings.hour
            dateComponents.minute = settings.minute

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let content = UNMutableNotificationContent()
            content.title = "今日の記録をつけましょう"
            content.body = "体重や体調を記録して、からだの変化を振り返りやすくしましょう。"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: self.notificationIdentifier,
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    print("❌ record reminder schedule error: \(error.localizedDescription)")
                } else {
                    print("✅ record reminder scheduled at \(settings.hour):\(settings.minute)")
                }
            }
        }
    }

    /// ローカル通知をキャンセルする
    func cancelNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }
}
