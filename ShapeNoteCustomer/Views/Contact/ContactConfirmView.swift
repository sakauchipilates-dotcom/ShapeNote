import SwiftUI
import FirebaseFirestore

struct ContactConfirmView: View {
    var name: String
    var email: String
    var message: String
    var onSendSuccess: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    @State private var isSending = false

    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("以下の内容で送信します。")
                        .font(.headline)
                        .padding(.bottom, 8)

                    HStack {
                        Text("お名前:")
                            .bold()
                        Spacer()
                        Text(name)
                    }

                    HStack {
                        Text("メールアドレス:")
                            .bold()
                        Spacer()
                        Text(email)
                    }

                    Text("お問い合わせ内容:")
                        .bold()
                    ScrollView {
                        Text(message)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }

                Spacer()

                Button(action: sendMessage) {
                    if isSending {
                        ProgressView().frame(maxWidth: .infinity).padding()
                    } else {
                        Text("この内容で送信する")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isSending)
                .alert("送信が完了しました！", isPresented: $showAlert) {
                    Button("OK") {
                        dismiss()
                        onSendSuccess?()
                    }
                }
            }
            .padding()
            .navigationTitle("送信内容の確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("戻る") { dismiss() }
                }
            }
        }
    }

    // MARK: - Firestore書き込み処理
    private func sendMessage() {
        isSending = true
        let newContact: [String: Any] = [
            "name": name,
            "email": email,
            "message": message,
            "timestamp": Timestamp(date: Date()),
            "status": "未読",
            "sourceApp": "customer"
        ]

        db.collection("contacts").addDocument(data: newContact) { error in
            isSending = false
            if let error = error {
                print("❌ Firestore送信エラー: \(error.localizedDescription)")
            } else {
                print("✅ Firestoreに保存完了！")
                showAlert = true
            }
        }
    }
}
