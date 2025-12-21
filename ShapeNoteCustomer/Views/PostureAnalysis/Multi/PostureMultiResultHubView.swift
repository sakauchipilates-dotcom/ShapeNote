import SwiftUI
import ShapeCore

struct PostureMultiResultHubView: View {

    let shots: [CapturedShot]
    let onRetakeAll: () -> Void
    let onClose: () -> Void

    @State private var selectedShot: CapturedShot? = nil

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            Theme.gradientMain.ignoresSafeArea()

            VStack(spacing: 14) {

                header

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(shots) { shot in
                        Button {
                            selectedShot = shot
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                Image(uiImage: shot.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                                Text(shot.direction.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.35), in: Capsule())
                                    .padding(10)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)

                Text("各画像をタップすると、その向きの姿勢分析を開始します。")
                    .font(.footnote)
                    .foregroundColor(Theme.dark.opacity(0.6))
                    .padding(.top, 2)

                Spacer()

                GlassButton(
                    title: "全て撮り直す",
                    systemImage: "arrow.counterclockwise.circle.fill",
                    background: Theme.sub
                ) {
                    onRetakeAll()
                }
                .frame(maxWidth: 320)
                .padding(.bottom, 18)
            }
        }
        .fullScreenCover(item: $selectedShot) { shot in
            PostureAnalysisFlowView(
                capturedImage: shot.image,
                onPop: { selectedShot = nil },
                onPopToRoot: {
                    selectedShot = nil
                    onClose()
                }
            )
        }
        .interactiveDismissDisabled(true)
        .navigationBarBackButtonHidden(true)
    }

    private var header: some View {
        HStack {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Theme.dark.opacity(0.6))
            }

            Spacer()

            Text("撮影結果（4方向）")
                .font(.headline)
                .foregroundColor(Theme.dark.opacity(0.85))

            Spacer()

            Button {
                onRetakeAll()
            } label: {
                Text("撮り直す")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.sub)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }
}
