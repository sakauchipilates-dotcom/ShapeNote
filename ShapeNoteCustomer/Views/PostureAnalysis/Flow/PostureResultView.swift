import SwiftUI
import ShapeCore

struct PostureResultView: View {

    let capturedImage: UIImage
    let result: PostureResult
    let skeletonImage: UIImage
    let reportImage: UIImage   // 診断書画像（1枚）

    let onRetake: () -> Void   // 再撮影（Flow → Camera）
    let onClose: () -> Void    // ホームへ戻る（Root に委譲）

    @State private var isSaving = false

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {

                    // タイトル
                    Text("AI姿勢分析レポート")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.dark)
                        .padding(.top, 16)

                    // 骨格画像カード
                    VStack {
                        Image(uiImage: skeletonImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.9)
                            .cornerRadius(16)
                            .shadow(color: Theme.shadow, radius: 8, y: 4)
                    }
                    .padding(.horizontal, 20)

                    // スコアカード
                    VStack(spacing: 20) {

                        Text("総合スコア")
                            .font(.title3.weight(.bold))
                            .foregroundColor(Theme.dark)

                        ZStack {
                            Circle()
                                .stroke(Theme.sub.opacity(0.2), lineWidth: 18)
                                .frame(width: 180, height: 180)

                            Circle()
                                .trim(from: 0, to: CGFloat(result.score / 100))
                                .stroke(
                                    Theme.sub,
                                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))

                            Text("\(Int(result.score))")
                                .font(.system(size: 52, weight: .bold))
                                .foregroundColor(Theme.dark)
                        }
                        .padding(.top, 10)

                        Text(result.message)
                            .font(.body)
                            .foregroundColor(Theme.dark)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 26)

                    }
                    .padding(24)
                    .background(Theme.gradientCard)
                    .cornerRadius(Theme.cardRadius)
                    .shadow(color: Theme.shadow, radius: 8, y: 4)
                    .padding(.horizontal, 20)

                    // ボタン群
                    VStack(spacing: 18) {

                        // 診断書レポートを保存
                        GlassButton(
                            title: "診断書レポートを保存",
                            systemImage: "square.and.arrow.down.fill",
                            background: Theme.sub
                        ) {
                            saveReport()
                        }

                        // 再撮影
                        GlassButton(
                            title: "再撮影する",
                            systemImage: "arrow.counterclockwise.circle.fill",
                            background: Theme.dark
                        ) {
                            onRetake()
                        }

                        // ホームへ
                        GlassButton(
                            title: "ホームに戻る",
                            systemImage: "house.fill",
                            background: Theme.dark.opacity(0.7)
                        ) {
                            onClose()
                        }

                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("保存完了", isPresented: $isSaving) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("診断書レポートを写真アプリに保存しました。")
        }
    }

    // MARK: - 診断書レポートを写真アプリへ保存
    private func saveReport() {
        Task.detached {
            UIImageWriteToSavedPhotosAlbum(reportImage, nil, nil, nil)
            await MainActor.run { isSaving = true }
        }
    }
}
