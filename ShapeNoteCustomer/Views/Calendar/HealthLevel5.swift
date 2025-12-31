// HealthLevel5.swift

import SwiftUI
import ShapeCore

// Firestore health payload
// 新形式: {"level":"normal","markers":["jogging","menstruation"]}
// 旧形式: "normal"（level 文字列のみ）
struct HealthStoragePayload: Codable, Hashable {
    let level: String
    let markers: [String]
}

// 体調5段階（Firestoreの保存値は rawValue で扱う）
enum HealthLevel5: String, CaseIterable, Codable, Hashable {
    case veryBad
    case bad
    case normal
    case good
    case great

    var label: String {
        switch self {
        case .veryBad: return "とても悪い"
        case .bad:     return "悪い"
        case .normal:  return "ふつう"
        case .good:    return "良い"
        case .great:   return "とても良い"
        }
    }

    /// カレンダー背景などに使う薄い色（Theme を使用）
    var color: Color {
        switch self {
        case .veryBad: return Theme.warning.opacity(0.35)
        case .bad:     return Theme.warning.opacity(0.22)
        case .normal:  return Theme.accent.opacity(0.18)
        case .good:    return Theme.sub.opacity(0.20)
        case .great:   return Theme.sub.opacity(0.28)
        }
    }
}
