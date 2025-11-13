import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import ShapeCore   // ← AuthHandlerを利用するために追加

struct CustomerRegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: CustomerAppState

    // MARK: - 入力項目
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // MARK: - UI状態
    @State private var message = ""
    @State private var isRegistering = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false

    // MARK: - Firebase AuthHandler
    private let authHandler = AuthHandler.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("新規会員登録")
                    .font(.title3.bold())

                // 入力フォーム
                Group {
                    TextField("氏名", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)

                    TextField("メールアドレス", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("パスワード（6文字以上）", text: $password)
                        .textFieldStyle(.roundedBorder)

                    SecureField("パスワード確認", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                // 登録ボタン or ローディング
                if isRegistering {
                    ProgressView("登録中…")
                        .padding(.top, 10)
                } else {
                    Button(action: register) {
                        Text("登録する")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid)
                    .padding(.top, 8)
                }

                // メッセージ表示
                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                // ログインに戻る
                Button("ログイン画面に戻る") {
                    dismiss()
                }
                .foregroundColor(.blue)
                .padding(.top, 16)
            }
            .padding(.vertical, 32)
            .alert("登録完了！", isPresented: $showSuccessAlert) {
                Button("OK") {
                    appState.setLoggedIn(true)
                }
            } message: {
                Text("登録ありがとうございます！\nマイページへ移動します。")
            }
            .alert("登録できませんでした", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(message)
            }
        }
    }

    // MARK: - 入力バリデーション
    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword
    }

    // MARK: - 登録処理
    private func register() {
        guard isFormValid else {
            message = "⚠️ 入力内容を確認してください"
            showErrorAlert = true
            return
        }

        isRegistering = true
        message = ""

        authHandler.signUp(email: email, password: password, name: name) { result in
            DispatchQueue.main.async {
                isRegistering = false
                switch result {
                case .success:
                    message = "✅ 登録完了しました！"
                    showSuccessAlert = true
                case .failure(let error):
                    handleError(error)
                }
            }
        }
    }

    // MARK: - エラーハンドリング
    private func handleError(_ error: Error) {
        if let authError = error as NSError?,
           let code = AuthErrorCode(rawValue: authError.code) {
            switch code {
            case .emailAlreadyInUse:
                message = "このメールアドレスは既に登録されています。"
            case .invalidEmail:
                message = "メールアドレスの形式が正しくありません。"
            case .weakPassword:
                message = "パスワードは6文字以上にしてください。"
            default:
                message = "❌ 登録に失敗しました: \(authError.localizedDescription)"
            }
        } else {
            message = "❌ 不明なエラー: \(error.localizedDescription)"
        }
        showErrorAlert = true
    }
}
