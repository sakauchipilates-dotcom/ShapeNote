import SwiftUI

struct PostureGuideView: View {

    // 🔥 CustomerRootView から渡される
    let onPush: (PostureRoute) -> Void
    let onPop: () -> Void

    @State private var step = 0

    private let steps: [GuideStep] = [
        GuideStep(
            title: "撮影手順の説明",
            description: "これから撮影手順を説明しますので、必ず全ての説明を読んでからスマホを所定位置に置いて離れてください。",
            systemImage: "book.closed.fill"
        ),
        GuideStep(
            title: "STEP 1：スマホの設置と立ち位置",
            description: "スマホを腰の高さで全身が映る位置にセットします。（内側のカメラを使用します。）\nこの時、カメラが縦向きになるようにしてください。\n背後に明るい光が入らないように注意してください。",
            systemImage: "camera.fill"
        ),
        GuideStep(
            title: "STEP 2：ポーズ",
            description: "最初はカメラに向かって正面を向いて立ち、両手は体の横に伸ばしておきましょう。\n足幅は自分の握り拳が一つ入るくらい空けておき、つま先は正面に向かって真っ直ぐ向けます。\n衣類を着こんで体型や姿勢がわかりづらい場合は衣類を調整してください。",
            systemImage: "figure.stand"
        ),
        GuideStep(
            title: "STEP 3：撮影開始",
            description: "撮影ボタンを押すと、15秒のカウントダウン後に自動で撮影されます。\n姿勢を正して、静止してください。",
            systemImage: "timer"
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            // アイコン
            Image(systemName: steps[step].systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .foregroundColor(.blue)
                .padding(.bottom, 10)

            Text(steps[step].title)
                .font(.title3.bold())
                .padding(.bottom, 8)

            Text(steps[step].description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)

            Spacer()

            // 進む／撮影へ
            if step < steps.count - 1 {
                Button {
                    withAnimation(.easeInOut) {
                        step += 1
                    }
                } label: {
                    Text("次へ進む")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
            } else {
                Button {
                    /// 🔥 Camera 画面へ push
                    onPush(.camera)
                } label: {
                    Label("撮影へ進む", systemImage: "camera.viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
            }

            // 🔥 pop（キャンセル→戻る）
            Button("キャンセル") {
                onPop()
            }
            .foregroundColor(.gray)
            .padding(.top, 10)

            Spacer(minLength: 40)
        }
        .navigationBarBackButtonHidden(true) // push最適化
    }
}

// MARK: - データ構造
struct GuideStep {
    let title: String
    let description: String
    let systemImage: String
}
