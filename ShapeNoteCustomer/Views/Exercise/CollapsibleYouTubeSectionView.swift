import SwiftUI

struct CollapsibleYouTubeSectionView: View {
    let title: String
    let description: String
    let videos: [YouTubeVideo]
    let icon: String
    @Binding var isExpanded: Bool
    let onTap: (YouTubeVideo) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // MARK: - ヘッダー
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Label("おすすめ動画", systemImage: icon)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(.white)
                        .imageScale(.large)
                }
            }
            .padding(.horizontal, 4)
            
            // MARK: - 内容
            if isExpanded {
                Text("あなたにおすすめのエクササイズ動画")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.95))
                    .padding(.bottom, 4)
                
                // ✅ 横スクロール式カルーセル
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(videos) { video in
                            Button(action: { onTap(video) }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    
                                    // ✅ サムネイル＋再生ボタン
                                    ZStack {
                                        AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 200, height: 110)
                                                .clipped()
                                                .cornerRadius(12)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.white.opacity(0.2))
                                                .frame(width: 200, height: 110)
                                                .cornerRadius(12)
                                                .overlay(
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                )
                                        }
                                        
                                        // ▶️ 再生ボタン（半透明黒背景＋白アイコン）
                                        Circle()
                                            .fill(Color.black.opacity(0.55))
                                            .frame(width: 46, height: 46)
                                            .overlay(
                                                Image(systemName: "play.fill")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 22))
                                                    .padding(.leading, 3)
                                            )
                                    }
                                    
                                    // タイトル・チャンネル名
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(video.title)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)
                                            .lineLimit(2)
                                        Text(video.channel)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(10)
                                .frame(width: 220)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        // ✅ 柔らかく上品な赤グラデーション背景
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.35, blue: 0.35),   // 明るめの赤
                    Color(red: 0.85, green: 0.0, blue: 0.1)    // 深い赤
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: .red.opacity(0.25), radius: 6, x: 0, y: 3)
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }
}
