import SwiftUI
import ShapeCore

struct GlassButton: View {
    let title: String
    let systemImage: String?
    var background: Color = Theme.sub
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = systemImage {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(background.opacity(0.9))
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
            )
            .foregroundColor(.white)
        }
        .padding(.horizontal, 32)
    }
}
