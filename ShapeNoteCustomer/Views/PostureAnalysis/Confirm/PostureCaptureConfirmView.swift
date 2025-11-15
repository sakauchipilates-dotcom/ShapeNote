import SwiftUI
import ShapeCore

struct PostureCaptureConfirmView: View {

    @EnvironmentObject var cameraVM: PostureCameraVM

    let onRetake: () -> Void
    let onConfirm: () -> Void

    var body: some View {

        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 28) {

                // MARK: - タイトル
                Text("この写真でよろしいですか？")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Theme.dark.opacity(0.85))
                    .padding(.top, 36)

                // MARK: - 撮影画像（ブランドカードスタイル）
                if let img = cameraVM.capturedImage {

                    ZStack {
                        // カード背景
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Theme.dark.opacity(0.06), lineWidth: 1)
                            )
                            .shadow(color: Theme.dark.opacity(0.12), radius: 10, y: 6)

                        // 画像
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .padding(14)
                    }
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.88)
                    .padding(.horizontal, 16)
                    .onAppear {
                        print("DEBUG: 🟩 ConfirmView表示 画像サイズ=\(img.size)")
                    }

                } else {
                    VStack(spacing: 12) {
                        Text("画像が読み込めませんでした。")
                            .font(.headline)
                            .foregroundColor(.black)

                        Text("撮影からやり直してください。")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .multilineTextAlignment(.center)
                    .padding()
                    .onAppear {
                        print("DEBUG: ❌ ConfirmViewで画像 nil")
                    }
                }

                Spacer()

                // MARK: - 撮り直すボタン
                GlassButton(
                    title: "撮り直す",
                    systemImage: "arrow.counterclockwise.circle.fill",
                    background: Theme.sub
                ) {
                    onRetake()
                }
                .frame(maxWidth: 300)
                .padding(.horizontal)

                // MARK: - OKボタン
                GlassButton(
                    title: "OK",
                    systemImage: "checkmark.circle.fill",
                    background: Theme.accent
                ) {
                    onConfirm()
                }
                .frame(maxWidth: 300)
                .padding(.horizontal)

                Spacer().frame(height: 32)
            }
        }
        .interactiveDismissDisabled(true)
        .navigationBarBackButtonHidden(true)
    }
}
