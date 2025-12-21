import SwiftUI
import ShapeCore

struct PostureMultiAnalysisView: View {

    let shots: [CapturedShot]
    let onRetakeAll: () -> Void
    let onClose: () -> Void

    @StateObject private var vm: PostureMultiAnalysisVM

    init(
        shots: [CapturedShot],
        onRetakeAll: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.shots = shots
        self.onRetakeAll = onRetakeAll
        self.onClose = onClose
        self._vm = StateObject(wrappedValue: PostureMultiAnalysisVM(shots: shots))
    }

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 14) {

                header

                // 横並び（4枚）
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(vm.items) { item in
                            shotCard(item)
                        }
                    }
                    .padding(.horizontal, 18)
                }

                // 総評
                VStack(alignment: .leading, spacing: 10) {
                    Text("総評（4方向）")
                        .font(.headline)
                        .foregroundColor(Theme.dark.opacity(0.85))

                    Text(vm.summaryText)
                        .font(.subheadline)
                        .foregroundColor(Theme.dark.opacity(0.75))
                        .lineSpacing(3)
                }
                .padding(16)
                .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.dark.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Theme.dark.opacity(0.10), radius: 10, y: 6)
                .padding(.horizontal, 18)

                Spacer()

                GlassButton(
                    title: "全て撮り直す",
                    systemImage: "arrow.counterclockwise.circle.fill",
                    background: Theme.sub
                ) { onRetakeAll() }
                .frame(maxWidth: 320)
                .padding(.bottom, 18)
            }
        }
        .onAppear {
            // 表示されたら自動で統合解析開始（最小構成のUX）
            vm.runAllAnalyses()
        }
        .interactiveDismissDisabled(true)
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack {
            Button { onClose() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Theme.dark.opacity(0.6))
            }

            Spacer()

            Text("統合解析（4方向）")
                .font(.headline)
                .foregroundColor(Theme.dark.opacity(0.85))

            Spacer()

            // 右側は空けてセンター寄せ維持
            Color.clear.frame(width: 30, height: 30)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private func shotCard(_ item: PostureMultiAnalysisVM.Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            ZStack(alignment: .bottomLeading) {

                // 骨格オーバーレイ画像があればそれを優先
                let display = item.skeletonImage ?? item.shot.image

                Image(uiImage: display)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 240, height: 320)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(item.shot.direction.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.35), in: Capsule())
                    .padding(10)
            }

            HStack(spacing: 8) {
                if let score = item.score {
                    Text("スコア \(score)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.dark.opacity(0.85))
                } else {
                    Text(vm.isAnalyzing ? "解析中…" : "未解析")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.dark.opacity(0.6))
                }
            }

            if let msg = item.message {
                Text(msg)
                    .font(.footnote)
                    .foregroundColor(Theme.dark.opacity(0.65))
                    .lineLimit(3)
            }
        }
    }
}
