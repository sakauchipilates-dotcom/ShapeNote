import SwiftUI

struct InquiryHubView: View {

    @EnvironmentObject private var appState: CustomerAppState

    @State private var isDeleting = false
    @State private var errorMessage: String? = nil
    @State private var showError = false
    @State private var showDeleteConfirm = false

    var body: some View {
        // あなたの既存レイアウトのまま、削除導線だけ差し替え
        VStack(spacing: 16) {

            // 既存の row(...) などはそのままでOK
            Button {
                showDeleteConfirm = true
            } label: {
                row(
                    icon: "person.crop.circle.badge.xmark",
                    title: "アカウント削除",
                    subtitle: "アプリ内でアカウントを削除します（削除後はログインできません）"
                )
            }
            .disabled(isDeleting)

            Spacer()
        }
        .confirmationDialog(
            "アカウントを削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                Task { await deleteNow() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。")
        }
        .alert("削除できませんでした", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "不明なエラーが発生しました。")
        }
    }

    private func row(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    @MainActor
    private func deleteNow() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            // ✅ 申請ではなく「即時削除」
            try await appState.deleteAccountNow(passwordForReauth: nil)
        } catch {
            // まずは最小差分：エラー表示だけ
            errorMessage = error.localizedDescription
            showError = true
            print("❌ deleteAccountNow error: \(error.localizedDescription)")
        }
    }
}
