import SwiftUI
import ShapeCore
import FirebaseAuth

struct CustomerLoginView: View {

    @EnvironmentObject private var appState: CustomerAppState

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var isShowingRegister: Bool = false

    // タイトル用グラデーション
    private var titleGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 74/255, green: 74/255, blue: 74/255),   // #4a4a4a
                Color(red: 124/255, green: 161/255, blue: 141/255) // #7ca18d
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 28) {

                header

                Spacer(minLength: 0)

                loginCard
                    .frame(maxWidth: 460)
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)

                footer
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 8) {
            Text("ShapeNote")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(titleGradient)

            Text("からだと姿勢の記録アプリ")
                .font(.callout)
                .foregroundColor(
                    Color(red: 74/255, green: 74/255, blue: 74/255)
                        .opacity(0.7)
                )
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .padding(.top, 64) // ← ここをしっかり下げる
    }

    // MARK: - Footer
    private var footer: some View {
        Text("© 2026 ShapeNote")
            .font(.caption2)
            .foregroundColor(
                Color(red: 74/255, green: 74/255, blue: 74/255)
                    .opacity(0.55)
            )
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    // MARK: - Login Card
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
                    .background(Color.white.opacity(0.75),
                                in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )

                SecureField("パスワードを入力", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.75),
                                in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(Theme.semanticColor.warning)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                }
                .disabled(!canLogin || isProcessing)

                Button {
                    isShowingRegister = true
                } label: {
                    Text("アカウントをお持ちでない方はこちら")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Theme.sub)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.4),
                                    in: RoundedRectangle(cornerRadius: 14))
                }
                .sheet(isPresented: $isShowingRegister) {
                    CustomerRegisterView()
                        .environmentObject(appState)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
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
            let result = try await Auth.auth()
                .signIn(withEmail: email, password: password)

            print("✅ login success: \(result.user.uid)")
            email = ""
            password = ""
            appState.setLoggedIn(true)

        } catch {
            errorMessage = "ログインに失敗しました。メールアドレス・パスワードをご確認ください。"
        }
    }
}
