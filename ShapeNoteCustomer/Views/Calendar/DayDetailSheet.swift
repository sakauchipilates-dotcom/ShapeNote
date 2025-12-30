import SwiftUI
import ShapeCore

struct DayDetailSheet: View {
    let date: Date
    let calendar: Calendar
    let weightManager: WeightManager

    @Binding var isPresented: Bool

    /// ＋（新規追加）
    private let onTapAdd: () -> Void

    /// レコード編集（一覧の行から）
    private let onTapEditRecord: (WeightRecord) -> Void

    // 互換init（古い呼び出しが残っていても動かす）
    init(
        date: Date,
        calendar: Calendar,
        weightManager: WeightManager,
        isPresented: Binding<Bool>,
        onTapAddOrEdit: @escaping () -> Void
    ) {
        self.date = date
        self.calendar = calendar
        self.weightManager = weightManager
        self._isPresented = isPresented
        self.onTapAdd = onTapAddOrEdit
        self.onTapEditRecord = { _ in onTapAddOrEdit() }
    }

    // 新仕様init
    init(
        date: Date,
        calendar: Calendar,
        weightManager: WeightManager,
        isPresented: Binding<Bool>,
        onTapAdd: @escaping () -> Void,
        onTapEditRecord: @escaping (WeightRecord) -> Void
    ) {
        self.date = date
        self.calendar = calendar
        self.weightManager = weightManager
        self._isPresented = isPresented
        self.onTapAdd = onTapAdd
        self.onTapEditRecord = onTapEditRecord
    }

    // MARK: - Health decoding
    private struct HealthPayload: Codable {
        let level: String
        let markers: [String]
    }

    private func decodeHealthPayload(from raw: String) -> HealthPayload? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(HealthPayload.self, from: data)
    }

    private func labelForHealthLevel(_ level: String) -> String? {
        switch level {
        case "veryBad": return "とても悪い"
        case "bad": return "悪い"
        case "normal": return "ふつう"
        case "good": return "良い"
        case "great": return "とても良い"
        default: return nil
        }
    }

    private func healthColor(_ level: String) -> Color {
        switch level {
        case "veryBad": return Theme.warning.opacity(0.35)
        case "bad": return Theme.warning.opacity(0.22)
        case "normal": return Theme.accent.opacity(0.18)
        case "good": return Theme.sub.opacity(0.20)
        case "great": return Theme.sub.opacity(0.28)
        default: return Theme.dark.opacity(0.08)
        }
    }

    private func healthLevelRaw(for record: WeightRecord) -> String? {
        guard let raw = record.health else { return nil }
        if let payload = decodeHealthPayload(from: raw) { return payload.level }
        return raw
    }

    private func healthLabel(for record: WeightRecord) -> String? {
        guard let raw = record.health else { return nil }
        if let payload = decodeHealthPayload(from: raw) {
            return labelForHealthLevel(payload.level)
        }
        return labelForHealthLevel(raw)
    }

    // MARK: - UI state
    @State private var confirmDelete: WeightRecord? = nil

    // ★トースト
    @State private var toastText: String = ""
    @State private var showToast: Bool = false
    @State private var toastTask: Task<Void, Never>? = nil

    private func presentToast(_ text: String) {
        toastTask?.cancel()
        toastText = text

        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showToast = true
        }

        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            withAnimation(.easeOut(duration: 0.25)) {
                showToast = false
            }
        }
    }

    private var records: [WeightRecord] {
        weightManager.records(on: date)
    }

    private var dateTitle: String {
        date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP")))
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ScrollView {
                        VStack(spacing: 14) {
                            headerRow
                            emptyStateCard
                            Spacer(minLength: 10)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                } else {
                    // swipeActions は List が最も安定
                    List {
                        Section {
                            headerRow
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }

                        Section {
                            HStack {
                                Text("この日の記録")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Theme.dark.opacity(0.80))
                                Spacer()
                                Text("\(records.count)件")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 0, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                            ForEach(records) { record in
                                recordCard(record)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            confirmDelete = record
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { isPresented = false }
                        .font(.body.bold())
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresented = false
                        DispatchQueue.main.async { onTapAdd() }
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.bold())
                    }
                    .accessibilityLabel("新規追加")
                }
            }
            // 削除確認（安全性）
            .alert("この記録を削除しますか？", isPresented: Binding(
                get: { confirmDelete != nil },
                set: { if !$0 { confirmDelete = nil } }
            ), presenting: confirmDelete) { record in
                Button("削除", role: .destructive) {
                    Task {
                        await weightManager.deleteRecord(recordId: record.id)
                        await MainActor.run {
                            presentToast("削除しました")
                            confirmDelete = nil
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {
                    confirmDelete = nil
                }
            } message: { _ in
                Text("削除すると元に戻せません。")
            }
            // ★トースト表示
            .overlay(alignment: .bottom) {
                if showToast {
                    toastView(text: toastText)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(999)
                }
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.secondary)
            Text(dateTitle)
                .font(.headline)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Subviews

    private var emptyStateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.secondary)
            Text("この日の記録はまだありません。")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("右上の＋から追加できます。")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.85))
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func recordCard(_ record: WeightRecord) -> some View {
        let level = healthLevelRaw(for: record)
        let label = healthLabel(for: record)

        return VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("記録時刻")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text((record.recordedAt ?? record.date).formatted(date: .omitted, time: .shortened))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.dark.opacity(0.75))
            }

            conditionBlock(record, level: level, label: label)

            Button {
                isPresented = false
                DispatchQueue.main.async { onTapEditRecord(record) }
            } label: {
                Text("この記録を編集する")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.sub.opacity(0.16))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.sub.opacity(0.35), lineWidth: 1)
                    )
                    .foregroundColor(Theme.dark.opacity(0.90))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func conditionBlock(_ record: WeightRecord, level: String?, label: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("コンディション")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.dark.opacity(0.80))

            VStack(spacing: 0) {
                compactRow(title: "体重", systemImage: "scalemass") {
                    Text(String(format: "%.1f kg", record.weight))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.dark.opacity(0.85))
                }

                dividerLine

                compactRow(title: "測定条件", systemImage: "clock") {
                    Text(record.condition ?? "—")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor((record.condition == nil) ? Theme.dark.opacity(0.35) : Theme.dark.opacity(0.85))
                }

                dividerLine

                compactRow(title: "体調", systemImage: "face.smiling") {
                    if let level, let label {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(healthColor(level))
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 1))

                            Text(label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Theme.dark.opacity(0.85))
                        }
                    } else {
                        Text("—")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.dark.opacity(0.35))
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
            .padding(.leading, 44)
    }

    private func compactRow<Trailing: View>(
        title: String,
        systemImage: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundColor(.secondary)
                .frame(width: 22)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.dark.opacity(0.80))

            Spacer()

            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    // MARK: - Toast View
    private func toastView(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.82))
        )
        .foregroundColor(.white)
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 6)
        .padding(.horizontal, 16)
    }
}
