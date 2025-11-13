//
//  FirestoreHelper.swift
//  ShapeCore
//
//  共通 Firestore 操作用ユーティリティ
//

import Foundation
import FirebaseFirestore

public struct FirestoreHelper {
    public let db = Firestore.firestore()

    public init() {}

    // MARK: - 基本的な書き込み
    public func write(
        to collection: String,
        data: [String: Any],
        completion: ((Error?) -> Void)? = nil
    ) {
        db.collection(collection).addDocument(data: data) { error in
            if let error = error {
                print("❌ Firestore書き込み失敗 [\(collection)]: \(error.localizedDescription)")
            } else {
                print("✅ Firestore書き込み成功 [\(collection)]")
            }
            completion?(error)
        }
    }

    // MARK: - ドキュメントの更新
    public func update(
        collection: String,
        documentID: String,
        data: [String: Any],
        completion: ((Error?) -> Void)? = nil
    ) {
        db.collection(collection).document(documentID).updateData(data) { error in
            if let error = error {
                print("⚠️ Firestore更新失敗 [\(documentID)]: \(error.localizedDescription)")
            } else {
                print("🔁 Firestore更新成功 [\(documentID)]")
            }
            completion?(error)
        }
    }

    // MARK: - ドキュメントの削除
    public func delete(
        collection: String,
        documentID: String,
        completion: ((Error?) -> Void)? = nil
    ) {
        db.collection(collection).document(documentID).delete { error in
            if let error = error {
                print("🗑️ Firestore削除失敗 [\(documentID)]: \(error.localizedDescription)")
            } else {
                print("🧹 Firestore削除成功 [\(documentID)]")
            }
            completion?(error)
        }
    }

    // MARK: - 単一ドキュメントの取得
    public func fetchDocument(
        collection: String,
        documentID: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        db.collection(collection).document(documentID).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = snapshot?.data() else {
                completion(.failure(NSError(domain: "FirestoreHelper", code: 404, userInfo: [NSLocalizedDescriptionKey: "Document not found."])))
                return
            }
            completion(.success(data))
        }
    }
}
