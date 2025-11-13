import SwiftUI
import ShapeCore

struct CollapsibleSectionView: View {
    let title: String
    let description: String
    let items: [ExerciseItemViewData]
    let icon: String
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // MARK: - ヘッダー
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.headline)
                        .foregroundColor(Theme.dark)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(Theme.sub)
                        .imageScale(.large)
                }
            }

            // MARK: - 説明文
            if isExpanded {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .slide))
            }

            // MARK: - コンテンツリスト
            if isExpanded {
                if items.isEmpty {
                    Text("データがまだありません")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .transition(.opacity)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(items) { item in
                            Button(action: item.action) {
                                HStack {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .foregroundColor(Theme.sub)
                                    Text(item.title)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(Theme.cardRadius)
                                .shadow(color: Theme.shadow, radius: 2, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Theme.main)
        .cornerRadius(Theme.cardRadius)
        .shadow(color: Theme.shadow, radius: 3, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }
}
