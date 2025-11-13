import SwiftUI
import FirebaseFirestore

// 🔔 一覧更新通知キー
extension Notification.Name {
    static let contactDidUpdate = Notification.Name("contactDidUpdate")
}

struct ContactDetailView: View {
    let contact: ContactItem
    @Environment(\.dismiss) private var dismiss
    @State private var replyText = ""
    @State private var isSending = false
    @State private var showSaveAlert = false
    @State private var saveMessage = ""
    
    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // MARK: - ユーザー情報
                    VStack(alignment: .leading, spacing: 8) {
                        Text("送信者：\(contact.name)")
                            .font(.headline)
                        Text("送信日時：\(contact.timestampString)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    // MARK: - メッセージ本文
                    Text(contact.message)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    
                    Divider()
                    
                    // MARK: - 管理者メモ／返信
                    VStack(alignment: .leading, spacing: 8) {
                        Text("返信メモ")
                            .font(.headline)
                        
                        TextEditor(text: $replyText)
                            .frame(height: 120)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3))
                            )
                        
                        Button {
                            saveReply()
                        } label: {
                            HStack {
                                if isSending {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text("保存する")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isSending || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
            }
            .navigationTitle("お問い合わせ詳細")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert(isPresented: $showSaveAlert) {
                Alert(title: Text("保存結果"), message: Text(saveMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // MARK: - Firestore 返信保存処理
    private func saveReply() {
        isSending = true
        let docRef = db.collection("contacts").document(contact.id)
        docRef.updateData([
            "reply": replyText,
            "status": "対応済",
            "repliedAt": Timestamp()
        ]) { error in
            isSending = false
            if let error = error {
                saveMessage = "❌ 保存に失敗しました: \(error.localizedDescription)"
            } else {
                saveMessage = "✅ 返信メモを保存しました。"
                
                // ✅ 一覧へ更新通知を送る
                NotificationCenter.default.post(name: .contactDidUpdate, object: nil)
            }
            showSaveAlert = true
        }
    }
}
