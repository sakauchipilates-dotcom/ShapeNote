import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct VisitHistoryView: View {
    @State private var visitHistory: [VisitHistoryItem] = []
    @State private var totalInvestment: Int = 0
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 累計金額ヘッダー
            if !isLoading {
                VStack(spacing: 6) {
                    Text("健康投資累計金額")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(totalInvestment)")
                        .font(.title.bold())
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }

            // MARK: - コンテンツ
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
                                    Text("¥\(price)")
                                        .font(.footnote.bold())
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle("来店履歴")
        .navigationBarTitleDisplayMode(.inline)
        .task { await fetchVisitHistory() }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Firestoreから履歴を取得
    private func fetchVisitHistory() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if let rawHistory = doc.data()?["visitHistory"] as? [[String: Any]] {
                let items = rawHistory.compactMap { VisitHistoryItem.from(dict: $0) }
                let sorted = items.sorted { $0.date > $1.date }
                let total = sorted.compactMap { $0.price }.reduce(0, +)

                await MainActor.run {
                    self.visitHistory = sorted
                    self.totalInvestment = total
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack { VisitHistoryView() }
}
