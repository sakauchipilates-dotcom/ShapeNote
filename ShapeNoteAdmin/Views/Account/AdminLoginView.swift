import SwiftUI
import FirebaseAuth
import ShapeCore

struct AdminLoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var message = ""
    @State private var isPasswordVisible = false
    @State private var isLoggingIn = false

    @EnvironmentObject var appState: AdminAppState
    private let auth = AuthHandler.shared

    var body: some View {
        VStack(spacing: 24) {
            Text("管理者ログイン")
                .font(.title3.bold())

            TextField("メールアドレスを入力", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .padding(.horizontal)

            if isPasswordVisible {
                TextField("パスワードを入力", text: $password)
                    .textFieldStyle(.roundedBorder)
            } else {
                SecureField("パスワードを入力", text: $password)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button(isPasswordVisible ? "非表示" : "表示") {
                    isPasswordVisible.toggle()
                }
                .font(.caption)
                .padding(.trailing)
            }

            Button("ログイン") {
                isLoggingIn = true
                auth.signIn(email: email, password: password) { result in
                    isLoggingIn = false
                    switch result {
                    case .success:
                        appState.setLoggedIn(true)
                    case .failure(let error):
                        message = "❌ \(error.localizedDescription)"
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoggingIn)

            if !message.isEmpty {
                Text(message)
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }
}

#Preview {
    AdminLoginView()
}
