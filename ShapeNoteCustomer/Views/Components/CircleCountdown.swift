import SwiftUI
import ShapeCore

struct CircleCountdown: View {
    let count: Int
    let total: Int

    var progress: CGFloat {
        CGFloat(count) / CGFloat(total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 10)
                .foregroundColor(.white.opacity(0.2))

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Theme.sub,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(count)")
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 180, height: 180)
    }
}
