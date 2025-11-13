import SwiftUI

struct InfoContactView: View {
    @State private var name = "坂内 徳明"
    @State private var email = "nori.vb.414.s@gmail.com"
    @State private var message = ""
    @State private var showConfirm = false
    @State private var showHistory = false

    var body: some View {
        Form {
            Section(header: Text("お問い合わせ内容を入力してください")) {
                TextField("お名前", text: $name)
                TextField("メールアドレス", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                TextEditor(text: $message)
                    .frame(height: 150)
            }

            // ✅ 問い合わせ送信ボタン
            Section {
                Button {
                    showConfirm = true
                } label: {
                    HStack {
                        Spacer()
                        Text("送信内容を確認する")
                            .bold()
                        Spacer()
                    }
                }
                .disabled(name.isEmpty || email.isEmpty || message.isEmpty)
            }

            // ✅ 履歴確認ボタン
            Section {
                Button {
                    showHistory = true
                } label: {
                    HStack {
                        Spacer()
                        Label("送信履歴を確認する", systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("お問い合わせ")
        .navigationBarTitleDisplayMode(.inline)
        // ✅ 送信確認シート（送信完了時のクリア処理をクロージャで受け取る）
        .sheet(isPresented: $showConfirm) {
            ContactConfirmView(
                name: name,
                email: email,
                message: message,
                onSendSuccess: {
                    // フォームリセットして戻る
                    name = "坂内 徳明"
                    email = "nori.vb.414.s@gmail.com"
                    message = ""
                    showConfirm = false
                }
            )
        }
        // ✅ 履歴シート
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                ContactHistoryView()
            }
        }
    }
}
