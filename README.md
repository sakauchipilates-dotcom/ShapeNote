# ShapeNote

## 🧩 概要
ShapeNote は、ピラティスやフィットネスの記録・管理を目的とした2つのアプリと共通モジュールで構成されています。

---

## 📱 構成
- **ShapeNoteCustomer**  
　ユーザー（会員）向けアプリ  
　来店履歴・クーポン・会員証を表示。

- **ShapeNoteAdmin**  
　管理者向けアプリ  
　顧客情報・レッスン記録・メッセージ機能を管理。

- **ShapeCore**  
　共通ロジックをSwift Packageとして管理（Firebase Auth / Firestore連携）。

---

## 🧰 技術スタック
- **SwiftUI**
- **Firebase (Auth, Firestore, Storage)**
- **Swift Package Manager**
- **Xcode Workspace 構成**

---

## 🗂 ディレクトリ構成

---

## 💾 バージョン管理
GitHub上でワークスペース全体を管理。  
`main` ブランチには安定版のみを保持し、  
新機能は `feature/` ブランチとして開発・統合しています。

🧪 この行は feature/test-readme ブランチのテストです。