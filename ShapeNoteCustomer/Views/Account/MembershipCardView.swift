import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import ShapeCore
import CoreImage.CIFilterBuiltins
import UIKit

struct MembershipCardView: View {
    @EnvironmentObject var imageVM: ProfileImageVM

    @State private var displayId: String = "未設定"
    @State private var visitCount: Int = 0
    @State private var points: Int = 0

    @State private var isFlipped: Bool = false

    private let context = CIContext()
    private let code128Filter = CIFilter.code128BarcodeGenerator()

    var body: some View {
        VStack(spacing: 14) {

            // タイトル
            HStack(spacing: 10) {
                Image(systemName: "person.text.rectangle")
                    .font(.system(size: 28))
                    .foregroundColor(.gray)

                Text("会員カード")
                    .font(.title3.bold())

                Spacer()
            }

            // カード（表/裏）
            ZStack {
                cardFront
                    .opacity(isFlipped ? 0 : 1)
                    .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

                cardBack
                    .opacity(isFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160) // 少し縦長
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                    isFlipped.toggle()
                }
            }

            // 案内文（表/裏で切り替え）
            Text(isFlipped ? "カードをタップで表面に戻る" : "カードをタップで裏面（バーコード）を表示")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .task {
            await loadUserData()
        }
    }

    // MARK: - Front
    private var cardFront: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(rankBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Theme.dark.opacity(0.10), radius: 10, y: 6)

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {

                    Text(displayName)
                        .font(.title3.bold())
                        .foregroundColor(Theme.dark.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 10) {
                        Text("会員ID  \(displayId)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer()
                    }

                    HStack(spacing: 10) {
                        pillChip(title: "RANK", value: rankLabel)
                        pillChip(title: "POINT", value: "\(points)")
                        Spacer()
                    }

                    Spacer()
                }

                Spacer()

                profileIconButton
            }
            .padding(16)
        }
    }

    private func pillChip(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(Theme.dark.opacity(0.70))

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(Theme.dark.opacity(0.88))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.35))
                .overlay(
                    Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var profileIconButton: some View {
        Button { imageVM.isPickerPresented = true } label: {
            ZStack {
                if let url = imageVM.iconURL {
                    let refreshedURL = URL(string: url.absoluteString + "?t=\(Date().timeIntervalSince1970)")!
                    AsyncImage(url: refreshedURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().frame(width: 78, height: 78)
                        case .success(let img):
                            img.resizable()
                                .scaledToFill()
                                .frame(width: 78, height: 78)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "person.crop.circle.badge.exclam")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 78, height: 78)
                                .foregroundColor(.gray.opacity(0.6))
                        @unknown default:
                            EmptyView().frame(width: 78, height: 78)
                        }
                    }
                    .id(refreshedURL.absoluteString)
                } else {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 78, height: 78)
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .overlay(Circle().stroke(Color.black.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Back
    private var cardBack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(rankBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Theme.dark.opacity(0.10), radius: 10, y: 6)

            VStack(spacing: 10) {
                VStack(spacing: 4) {
                    Text("会員ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(displayId)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Theme.dark.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                barcodeView(for: displayId)
                    .frame(height: 74)

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        // 反転は不要（ここでやるとテキストまで左右反転する）
    }

    // MARK: - Barcode (real if possible, else dummy + overlay)
    @ViewBuilder
    private func barcodeView(for text: String) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        ZStack {
            if let img = makeCode128(from: trimmed) {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(barcodePanelBackground)
            } else {
                DummyBarcode(strengthSeed: trimmed.isEmpty ? "DUMMY" : trimmed)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(barcodePanelBackground)
            }

            // 薄い「実装予定」オーバーレイ
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.40))
                    .blur(radius: 0.3)

                Text("実装予定です")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Theme.dark.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 34)
        }
    }

    private var barcodePanelBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.70))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }

    private func makeCode128(from text: String) -> UIImage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "—", trimmed != "未設定" else { return nil }

        code128Filter.message = Data(trimmed.utf8)
        guard let output = code128Filter.outputImage else { return nil }

        let transform = CGAffineTransform(scaleX: 3.0, y: 3.0)
        let scaled = output.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Firestore
    private func loadUserData() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if let data = doc.data() {
                await MainActor.run {
                    displayId = data["displayId"] as? String ?? "未設定"
                    visitCount = data["visitCount"] as? Int ?? 0

                    // points が無ければ visitCount を暫定ポイント扱い
                    let p = data["points"] as? Int
                    points = p ?? visitCount
                }
            }
        } catch {
            print("❌ ユーザーデータの取得に失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers
    private var displayName: String {
        if !imageVM.name.isEmpty { return imageVM.name }
        return Auth.auth().currentUser?.displayName ?? "ゲスト"
    }

    private var rankLabel: String {
        if imageVM.membershipRank.isEmpty { return "ブロンズ" }
        return imageVM.membershipRank
    }

    private var rankBackground: Color {
        switch rankLabel {
        case "プラチナ":
            return Color(hex: "#E9E6F3").opacity(0.95)
        case "ゴールド":
            return Color(hex: "#F3E7C9").opacity(0.95)
        case "シルバー":
            return Color(hex: "#ECEFF3").opacity(0.95)
        case "ブロンズ":
            return Theme.main.opacity(0.92)
        case "レギュラー":
            return Color(.secondarySystemBackground)
        default:
            return Theme.main.opacity(0.92)
        }
    }
}

// MARK: - Dummy Barcode
private struct DummyBarcode: View {
    let strengthSeed: String

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            let pattern = barcodePattern(from: strengthSeed)

            HStack(spacing: 0) {
                ForEach(Array(pattern.enumerated()), id: \.offset) { _, bar in
                    Rectangle()
                        .fill(Color.black.opacity(bar.isDark ? 0.55 : 0.12))
                        .frame(width: max(1, w * bar.widthRatio), height: h)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private struct Bar {
        let isDark: Bool
        let widthRatio: CGFloat
    }

    private func barcodePattern(from seed: String) -> [Bar] {
        var hash = UInt64(1469598103934665603) // FNV-1a
        for b in seed.utf8 {
            hash ^= UInt64(b)
            hash &*= 1099511628211
        }

        func next() -> UInt64 {
            hash ^= (hash >> 12)
            hash ^= (hash << 25)
            hash ^= (hash >> 27)
            return hash &* 2685821657736338717
        }

        var bars: [Bar] = []
        var remaining: CGFloat = 1.0

        while remaining > 0.02 {
            let r = next()
            let dark = (r & 1) == 0
            let widthUnit = CGFloat((r % 3) + 1) // 1..3
            let ratio = min(remaining, widthUnit / 80.0)
            bars.append(Bar(isDark: dark, widthRatio: ratio))
            remaining -= ratio
        }

        if remaining > 0 {
            bars.append(Bar(isDark: true, widthRatio: remaining))
        }

        return bars
    }
}
