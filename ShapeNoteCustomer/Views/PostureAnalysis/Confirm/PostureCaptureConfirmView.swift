import SwiftUI
import ShapeCore

struct PostureCaptureConfirmView: View {

    @EnvironmentObject var cameraVM: PostureCameraVM

    let onRetake: () -> Void
    let onConfirm: () -> Void

    var body: some View {

        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 24) {

                // MARK: - タイトル
                Text("この写真でよろしいですか？")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(Theme.dark)
                    .padding(.top, 20)

                // MARK: - 撮影画像
                if let img = cameraVM.capturedImage {

                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
                        .cornerRadius(18)
                        .shadow(color: Theme.dark.opacity(0.12), radius: 10, y: 6)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)   // 少し下げて中央寄りに見せる
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
                    print("DEBUG: 🔄 撮り直す tapped")
                    onRetake()
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 8)

                // MARK: - OKボタン（分析へ）
                GlassButton(
                    title: "OK",
                    systemImage: "checkmark.circle.fill",
                    background: Theme.accent
                ) {
                    print("DEBUG: ▶︎ OK tapped")
                    onConfirm()
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 32)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
