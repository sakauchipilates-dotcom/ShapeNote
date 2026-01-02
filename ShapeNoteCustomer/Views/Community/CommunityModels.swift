import Foundation

enum SNCommunityCategory: String, CaseIterable, Identifiable {
    case share = "記録の共有"
    case event = "イベント告知"
    case recommend = "おすすめ投稿"
    case announcement = "スタジオからのお知らせ"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .share: return "chart.line.uptrend.xyaxis"
        case .event: return "calendar.badge.clock"
        case .recommend: return "sparkles"
        case .announcement: return "megaphone.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .share: return "継続のコツや変化をシェア"
        case .event: return "グループ/キャンペーンの案内"
        case .recommend: return "運動・食事・セルフケア"
        case .announcement: return "休講/更新情報など"
        }
    }
}

struct SNCommunityFeedItem: Identifiable, Equatable {
    let id: String
    let category: SNCommunityCategory
    let title: String
    let body: String
    let date: Date

    init(
        id: String = UUID().uuidString,
        category: SNCommunityCategory,
        title: String,
        body: String,
        date: Date
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.body = body
        self.date = date
    }
}

enum SNCommunityDateFormat {
    static let jpDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy年M月d日"
        return f
    }()

    static func jpDate(_ date: Date) -> String {
        jpDateFormatter.string(from: date)
    }

    static func compact(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy/M/d"
        return f.string(from: date)
    }
}
