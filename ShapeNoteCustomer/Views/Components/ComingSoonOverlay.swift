import SwiftUI
import ShapeCore

struct ComingSoonOverlay: View {

    let title: String
    let message: String

    var body: some View {
        ZStack {
            // 背景は「うっすら」：UIの存在は見せる
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(Theme.dark.opacity(0.88))

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Theme.dark.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.85))
                    .shadow(color: Theme.dark.opacity(0.12), radius: 14, y: 8)
            )
            .padding(.horizontal, 24)
        }
        // タップは全部吸って「開けない」ようにする
        .allowsHitTesting(true)
    }
}
