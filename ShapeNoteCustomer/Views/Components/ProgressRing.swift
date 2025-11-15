import SwiftUI
import ShapeCore

struct ProgressRing: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.main.opacity(0.3), lineWidth: 12)

            Circle()
                .trim(from: 0, to: animate ? 0.75 : 0.05)
                .stroke(
                    Theme.sub,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(animate ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1.2).repeatForever(autoreverses: false),
                    value: animate
                )
        }
        .onAppear { animate = true }
    }
}
