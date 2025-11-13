//
//  ShapeCore.swift
//  Shared Core Module
//
//  Created for ShapeNote Project
//

import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

/// ShapeCore共通ユーティリティのエントリーポイント
/// - Firebaseの初期化や共通設定を管理
public struct ShapeCore {

    /// 共通モジュール初期化
    /// - 呼び出し場所: 各アプリの App 初期化時（例: ShapeNoteCustomerApp / ShapeNoteAdminApp）
    public static func initialize() {
        // Firebase初期化（必要時のみ実行）
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("✅ FirebaseApp configured via ShapeCore")
        }

        // その他共通初期処理があればここに追加
        print("✅ ShapeCore Initialized")
    }

    /// 簡易ログ出力
    /// - Parameters:
    ///   - message: 出力メッセージ
    ///   - file: 呼び出し元ファイル名
    ///   - line: 呼び出し元行数
    public static func log(_ message: String, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        print("📘 [ShapeCore] \(filename):\(line) - \(message)")
    }
}
