import SwiftUI
import ShapeCore

struct CameraGuideOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                // 肩の水平ライン
                path.move(to: CGPoint(x: 0, y: h * 0.32))
                path.addLine(to: CGPoint(x: w, y: h * 0.32))

                // 腰の水平ライン
                path.move(to: CGPoint(x: 0, y: h * 0.62))
                path.addLine(to: CGPoint(x: w, y: h * 0.62))
            }
            .stroke(Theme.accent.opacity(0.25), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }
}
