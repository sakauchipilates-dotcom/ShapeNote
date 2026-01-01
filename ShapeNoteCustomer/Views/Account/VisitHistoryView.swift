import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import ShapeCore

struct VisitHistoryView: View {
    @State private var visitHistory: [VisitHistoryItem] = []
    @State private var totalInvestment: Int = 0
    @State private var visitCount: Int = 0

    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header（来店回数 + 累計金額）
            if !isLoading {
                header
            }

            // MARK: - Content
            if isLoading {
                ProgressView("読み込み中…")
                    .tint(.gray)
                    .padding(.top, 60)

            } else if let error = errorMessage {
                Text("⚠️ \(error)")
                    .foregroundColor(.red)
                    .padding(.top, 60)

            } else if visitHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("来店履歴がまだありません。")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)

            } else {
                List(visitHistory) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.date)
                            .font(.headline)

                        Text(record.note)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let product = record.productName, !product.isEmpty {
                            HStack {
                                Text(product)
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                                Spacer()
                                if let price = record.price {
                                    Text(formatYen(price))
                                        .font(.footnote.bold())
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("来店履歴")
        .navigationBarTitleDisplayMode(.inline)
        .task { await fetchVisitHistory() }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Header View
    private var header: some View {
        HStack(spacing: 12) {

            // Left: Visit count
            VStack(spacing: 6) {
                Text("来店回数")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(visitCount) 回")
                    .font(.title3.bold())
                    .foregroundColor(Theme.dark.opacity(0.92))
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 34)
                .opacity(0.25)

            // Right: Total investment
            VStack(spacing: 6) {
                Text("健康投資累計金額")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatYen(totalInvestment))
                    .font(.title3.bold())
                    .foregroundColor(Theme.sub)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    // MARK: - Firestoreから履歴を取得
    private func fetchVisitHistory() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            let doc = try await Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument()

            let data = doc.data() ?? [:]

            // visitHistory（配列）から生成
            let rawHistory = data["visitHistory"] as? [[String: Any]] ?? []
            let items = rawHistory.compactMap { VisitHistoryItem.from(dict: $0) }
            let sorted = items.sorted { $0.date > $1.date }

            // 合計金額（price 合計）
            let total = sorted.compactMap { $0.price }.reduce(0, +)

            // 来店回数：Firestoreの visitCount を優先（無ければ履歴数）
            let vc = (data["visitCount"] as? Int) ?? sorted.count

            await MainActor.run {
                self.visitHistory = sorted
                self.totalInvestment = total
                self.visitCount = vc
                self.isLoading = false
            }

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func formatYen(_ value: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencySymbol = "¥"
        nf.maximumFractionDigits = 0
        nf.locale = Locale(identifier: "ja_JP")
        return nf.string(from: NSNumber(value: value)) ?? "¥\(value)"
    }
}

#Preview {
    NavigationStack { VisitHistoryView() }
}
