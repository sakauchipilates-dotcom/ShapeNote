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
                        .cornerRadius(16)
                        .shadow(color: Theme.shadow, radius: 8, y: 4)
                        .padding(.horizontal, 20)
                        .onAppear {
                            print("DEBUG: 🟩 ConfirmView表示 画像サイズ=\(img.size)")
                        }

                } else {
                    VStack(spacing: 8) {
                        Text("画像が読み込めませんでした。")
                            .font(.headline)
                            .foregroundColor(.black)

                        Text("撮影からやり直してください。")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .onAppear {
                        print("DEBUG: ❌ ConfirmViewで画像 nil")
                    }
                }

                Spacer()

                // MARK: - 撮り直す
                GlassButton(
                    title: "撮り直す",
                    systemImage: "arrow.counterclockwise.circle.fill",
                    background: Theme.sub
                ) {
                    print("DEBUG: 🔄 撮り直す tapped")
                    onRetake()
                }
                .padding(.horizontal, 40)

                // MARK: - OK（分析へ）
                GlassButton(
                    title: "OK",
                    systemImage: "checkmark.circle.fill",
                    background: Theme.accent
                ) {
                    print("DEBUG: ▶︎ OK tapped")
                    onConfirm()
                }
                .padding(.horizontal, 40)

                Spacer().frame(height: 24)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}
