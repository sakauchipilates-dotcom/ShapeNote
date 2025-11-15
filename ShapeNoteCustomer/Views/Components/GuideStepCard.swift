import SwiftUI
import ShapeCore

struct GuideStepCard: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 18) {

            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(Theme.sub)

            Text(title)
                .font(.title3.bold())
                .foregroundColor(Theme.dark)

            Text(description)
                .font(.body)
                .foregroundColor(Theme.dark.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
    }
}
