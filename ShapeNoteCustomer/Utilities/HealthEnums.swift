import SwiftUI
import ShapeCore
// 体調（カレンダーのドット色にも使う）
enum HealthCondition: String, CaseIterable, Identifiable {
    case good
    case normal
    case bad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .good: return "良い"
        case .normal: return "普通"
        case .bad: return "悪い"
        }
    }

    var icon: String {
        switch self {
        case .good: return "face.smiling"
        case .normal: return "face.neutral"
        case .bad: return "face.dashed"
        }
    }

    var color: Color {
        switch self {
        case .good: return Theme.sub
        case .normal: return Theme.accent
        case .bad: return Theme.semanticColor.warning   // ← 赤系（警告）
        }
    }
}

// 測定時間（ピル選択用）
enum MeasurementTime: String, CaseIterable, Identifiable {
    case wake
    case afterBreakfast
    case noon
    case evening
    case beforeBed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wake: return "起床後"
        case .afterBreakfast: return "朝食後"
        case .noon: return "昼"
        case .evening: return "夕"
        case .beforeBed: return "就寝前"
        }
    }

    var icon: String {
        switch self {
        case .wake: return "sunrise"
        case .afterBreakfast: return "sun.max"
        case .noon: return "sun.max.fill"
        case .evening: return "sunset"
        case .beforeBed: return "moon.stars"
        }
    }
}
