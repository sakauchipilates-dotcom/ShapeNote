import SwiftUI
import FirebaseAuth
import ShapeCore

struct CustomerLoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var message = ""
    @State private var isLoggingIn = false
    @State private var isShowingRegister = false
    
    @EnvironmentObject var appState: CustomerAppState
    private let auth = AuthHandler.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("会員ログイン")
                    .font(.title3.bold())

                TextField("メールアドレスを入力", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal)

                HStack {
                    if isPasswordVisible {
                        TextField("パスワードを入力", text: $password)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("パスワードを入力", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)

                if isLoggingIn {
                    ProgressView("ログイン中…")
                } else {
                    Button("ログイン") {
                        login()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if !message.isEmpty {
                    Text(message)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Divider().padding(.top, 16)

                // 🔹 新規登録ボタンを追加
                Button("アカウントをお持ちでない方はこちら") {
                    isShowingRegister = true
                }
                .foregroundColor(.blue)
                .sheet(isPresented: $isShowingRegister) {
                    CustomerRegisterView()
                        .environmentObject(appState)
                }
            }
            .padding()
        }
    }

    private func login() {
        isLoggingIn = true
        auth.signIn(email: email, password: password) { result in
            isLoggingIn = false
            switch result {
            case .success:
                message = "✅ ログイン成功！"
                appState.setLoggedIn(true)
            case .failure(let error):
                message = "❌ ログイン失敗: \(error.localizedDescription)"
            }
        }
    }
}
