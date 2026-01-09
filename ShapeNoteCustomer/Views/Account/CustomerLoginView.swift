import SwiftUI
import ShapeCore
import FirebaseAuth

struct CustomerLoginView: View {

    @EnvironmentObject private var appState: CustomerAppState

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?

    // ✅ 登録画面を表示
    @State private var isShowingRegister: Bool = false

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack {
                Spacer(minLength: 0)

                loginCard
                    .frame(maxWidth: 460)
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
        }
    }

    private var loginCard: some View {
        VStack(spacing: 16) {

            Text("会員ログイン")
                .font(.title3.weight(.semibold))
                .foregroundColor(Theme.semanticColor.text.opacity(0.9))
                .padding(.top, 6)

            VStack(spacing: 12) {

                TextField("メールアドレスを入力", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )

                SecureField("パスワードを入力", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(Theme.semanticColor.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }

                Button {
                    Task { await login() }
                } label: {
                    HStack(spacing: 10) {
                        if isProcessing {
                            ProgressView().scaleEffect(0.9)
                        }
                        Text(isProcessing ? "ログイン中..." : "ログイン")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        Theme.sub.opacity(canLogin ? 1.0 : 0.55),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canLogin || isProcessing)

                Button {
                    isShowingRegister = true
                } label: {
                    Text("アカウントをお持ちでない方はこちら")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Theme.sub.opacity(0.95))
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.40), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .sheet(isPresented: $isShowingRegister) {
                    CustomerRegisterView()
                        .environmentObject(appState)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Theme.semanticColor.card)
                .shadow(color: Theme.dark.opacity(0.12), radius: 14, y: 8)
        )
    }

    private var canLogin: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !password.isEmpty
    }

    @MainActor
    private func login() async {
        guard canLogin else { return }
        errorMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("✅ login success: \(result.user.uid)")

            // ✅ 入力クリア（任意）
            email = ""
            password = ""

            appState.setLoggedIn(true)
        } catch {
            errorMessage = "ログインに失敗しました。メールアドレス・パスワードをご確認ください。"
            print("⚠️ login error: \(error.localizedDescription)")
        }
    }
}
