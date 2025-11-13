import SwiftUI
import ShapeCore

struct AdminHomeView: View {
    @StateObject private var vm = StorageUsageVM()
    @State private var showContacts = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.main.ignoresSafeArea() // 背景を統一
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        storageSection
                        statsSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("ダッシュボード")
            .navigationBarTitleDisplayMode(.large) // ← 高さを統一
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await vm.load() }
                    } label: {
                        if vm.isLoading {
                            ProgressView()
                        } else {
                            Label("更新", systemImage: "arrow.clockwise")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    TopRightIcons(
                        onLogout: { print("🚪 ログアウト（AdminHomeView）") },
                        onNotification: { showContacts = true }
                    )
                }
            }
            .task { await vm.load() }
        }
    }

    // MARK: - Storage表示
    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Storage 使用状況")
                    .font(.title3.bold())
                Spacer()
                Text(String(format: "%.0f%%", vm.usagePercent))
                    .font(.headline)
                    .foregroundColor(.blue)
            }

            GeometryReader { geo in
                let width = geo.size.width
                let ratio = vm.totalGB > 0 ? 1 / vm.totalGB : 0

                HStack(spacing: 0) {
                    Rectangle().fill(Color.blue).frame(width: width * vm.imagesGB * ratio)
                    Rectangle().fill(Color.purple).frame(width: width * vm.videosGB * ratio)
                    Rectangle().fill(Color.orange).frame(width: width * vm.docsGB * ratio)
                    Rectangle().fill(Color.green).frame(width: width * vm.otherGB * ratio)
                }
                .frame(height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .frame(height: 22)

            HStack(spacing: 16) {
                legend(color: .blue, title: "画像", value: vm.imagesGB)
                legend(color: .purple, title: "動画", value: vm.videosGB)
                legend(color: .orange, title: "ドキュメント", value: vm.docsGB)
                legend(color: .green, title: "その他", value: vm.otherGB)
            }

            Text(String(format: "使用量: %.2f GB / %.2f GB", vm.usedTotalGB, vm.totalGB))
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }

    private func legend(color: Color, title: String, value: Double) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text("\(title) \(String(format: "%.1fGB", value))")
                .font(.footnote)
        }
    }

    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                statCard(title: "登録ユーザー", value: "\(vm.memberCount)", color: .green)
                statCard(title: "未読メッセージ", value: "\(vm.unreadCount)", color: .orange)
            }
            HStack(spacing: 12) {
                statCard(title: "保存シート数", value: "\(vm.sheetCount)", color: .blue)
                statCard(title: "使用容量(%)", value: String(format: "%.0f%%", vm.usagePercent), color: .purple)
            }
        }
    }

    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}
