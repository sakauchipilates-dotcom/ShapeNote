import SwiftUI

struct AdminExerciseSheetView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ====== 投稿・管理カード（ヘッダー重複削除済み） ======
                    VStack(spacing: 20) {

                        // ✅ セルフケアシート
                        AnimatedNavCard(
                            destination: AdminSelfCareUploadView(),
                            icon: "doc.text.fill",
                            title: "セルフケアシートの追加・管理",
                            description: "セルフケア資料を登録・削除できます",
                            gradient: Gradient(colors: [
                                Color(red: 0.40, green: 0.55, blue: 0.45),
                                Color(red: 0.35, green: 0.50, blue: 0.40)
                            ]),
                            symbolColor: .white,
                            textColor: .white
                        )

                        // ✅ おすすめ動画
                        AnimatedNavCard(
                            destination: AdminYouTubeUploadView(),
                            icon: "play.rectangle.fill",
                            title: "おすすめ動画の投稿・管理",
                            description: "YouTubeリンクを登録・削除できます",
                            gradient: Gradient(colors: [
                                Color(red: 0.90, green: 0.15, blue: 0.15),
                                Color(red: 0.70, green: 0.00, blue: 0.05)
                            ]),
                            symbolColor: .white,
                            textColor: .white
                        )

                        // ✅ エクササイズ解説シート（新規追加）
                        AnimatedNavCard(
                            destination: AdminExerciseExplainUploadView(),
                            icon: "figure.mind.and.body",
                            title: "エクササイズ解説シートの追加・管理",
                            description: "画像とテキストでエクササイズを登録できます",
                            gradient: Gradient(colors: [
                                Color(red: 0.25, green: 0.50, blue: 0.70),
                                Color(red: 0.15, green: 0.40, blue: 0.60)
                            ]),
                            symbolColor: .white,
                            textColor: .white
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("エクササイズ管理")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// ====== 押下アニメーション付きカード ======
struct AnimatedNavCard<Destination: View>: View {
    let destination: Destination
    let icon: String
    let title: String
    let description: String
    let gradient: Gradient
    let symbolColor: Color
    let textColor: Color

    @State private var isPressed = false

    var body: some View {
        NavigationLink(destination: destination) {
            AdminFeatureCard(
                icon: icon,
                title: title,
                description: description,
                gradient: gradient,
                symbolColor: symbolColor,
                textColor: textColor
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.3)) { isPressed = true } }
                .onEnded   { _ in withAnimation(.spring(response: 0.4)) { isPressed = false } }
        )
    }
}

// ====== カードUIコンポーネント ======
struct AdminFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let gradient: Gradient
    let symbolColor: Color
    let textColor: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(symbolColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(symbolColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(textColor)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(textColor.opacity(0.9))
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(textColor.opacity(0.6))
        }
        .padding()
        .background(
            LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

#Preview {
    AdminExerciseSheetView()
}
