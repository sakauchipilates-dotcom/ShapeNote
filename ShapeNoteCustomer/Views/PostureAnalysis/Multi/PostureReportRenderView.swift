import SwiftUI
import ShapeCore

struct PostureReportRenderView: View {

    // PostureMultiAnalysisView と同じ Item を受け取る（＝ShapeCore依存を増やさない）
    let title: String
    let dateText: String
    let items: [PostureMultiAnalysisVM.Item]

    let summaryScoreText: String
    let summaryHeadline: String
    let summaryMessage: String
    let summaryBullets: [String]

    // 出力画像の「紙面」幅（A4っぽく見える比率にしやすい）
    // 1080 は iPhone でも扱いやすい “SNS投稿/保存” 向けの定番。
    private let canvasWidth: CGFloat = 1080

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {

            // Header
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 44, weight: .bold))
                Spacer()
                Text("撮影日：\(dateText)")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.75))
            }
            .padding(.top, 10)

            // 4 rows (front/back/right/left)
            VStack(spacing: 18) {
                ForEach(items) { item in
                    reportRow(item)
                }
            }

            // Summary
            VStack(alignment: .leading, spacing: 12) {
                Text("総合評価")
                    .font(.system(size: 34, weight: .bold))

                HStack(alignment: .center) {
                    Text(summaryScoreText)
                        .font(.system(size: 30, weight: .bold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.08), in: Capsule())
                    Spacer()
                }

                Text(summaryHeadline)
                    .font(.system(size: 30, weight: .semibold))

                Text(summaryMessage)
                    .font(.system(size: 26))
                    .foregroundStyle(.black.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                if !summaryBullets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(summaryBullets, id: \.self) { b in
                            Text("・\(b)")
                                .font(.system(size: 24))
                                .foregroundStyle(.black.opacity(0.72))
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .padding(48)
        .frame(width: canvasWidth, alignment: .leading)
        .background(Color.white)
    }

    private func reportRow(_ item: PostureMultiAnalysisVM.Item) -> some View {
        HStack(alignment: .top, spacing: 22) {

            // Left: image
            Image(uiImage: item.skeletonImage ?? item.original)
                .resizable()
                .scaledToFill()
                .frame(width: 250, height: 320)
                .clipped()
                .background(Color.black.opacity(0.06))
                .cornerRadius(18)

            // Right: text
            VStack(alignment: .leading, spacing: 10) {

                HStack(spacing: 12) {
                    Text(item.direction.title)
                        .font(.system(size: 26, weight: .bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.08), in: Capsule())

                    if let score = item.score {
                        Text("\(score)")
                            .font(.system(size: 26, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.08), in: Capsule())
                    } else if item.errorText != nil {
                        Text("ERR")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.75), in: Capsule())
                    } else {
                        Text("…")
                            .font(.system(size: 26, weight: .bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.08), in: Capsule())
                    }
                }

                Text("点数")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.65))

                Text("\(item.direction.title)の写真のレビューと考察")
                    .font(.system(size: 28, weight: .bold))

                if let err = item.errorText {
                    Text("解析に失敗しました")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.red.opacity(0.85))
                    Text(err)
                        .font(.system(size: 24))
                        .foregroundStyle(.red.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(item.message ?? "解析結果を作成しています…")
                        .font(.system(size: 24))
                        .foregroundStyle(.black.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(Color.black.opacity(0.03))
        .cornerRadius(22)
    }
}
