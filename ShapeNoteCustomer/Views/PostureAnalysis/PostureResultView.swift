import SwiftUI

struct PostureResultView: View {
    let capturedImage: UIImage
    let result: PostureResult
    let skeletonImage: UIImage
    let reportImage: UIImage

    // 🔥 pushDestination 用：コールバックは外部に移譲
    let onRetake: () -> Void     // → FlowView → pop()
    let onClose: () -> Void      // → FlowView → popToRoot()

    @State private var isSaving = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {

                // 解析画像
                Image(uiImage: skeletonImage)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: UIScreen.main.bounds.width * 0.9,
                        maxHeight: UIScreen.main.bounds.height * 0.7
                    )
                    .cornerRadius(16)
                    .padding(.top, 32)

                Spacer()

                // スコア
                VStack(spacing: 16) {

                    Text("姿勢スコア")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))

                    Text("\(Int(result.score))")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(.white)

                    Text(result.message)
                        .font(.title3)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .padding(.bottom, 40)

                // ボタン群
                VStack(spacing: 14) {

                    // 保存
                    Button {
                        saveReport()
                    } label: {
                        Label("結果レポートを保存", systemImage: "square.and.arrow.down.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    // 再撮影（FlowView → Camera）
                    Button {
                        onRetake()
                    } label: {
                        Label("再撮影する", systemImage: "arrow.counterclockwise.circle.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    // ホームへ（FlowView → Root へ popToRoot）
                    Button {
                        onClose()
                    } label: {
                        Label("ホームへ戻る", systemImage: "house.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("保存完了", isPresented: $isSaving) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("結果シートを写真アプリに保存しました。")
        }
    }

    // MARK: - 保存
    private func saveReport() {
        Task.detached {
            UIImageWriteToSavedPhotosAlbum(reportImage, nil, nil, nil)
            await MainActor.run {
                isSaving = true
            }
        }
    }
}
