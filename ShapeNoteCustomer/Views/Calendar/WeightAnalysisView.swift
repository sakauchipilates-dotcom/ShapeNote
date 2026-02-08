import SwiftUI
import UIKit

struct WeightAnalysisView: View {
    @Binding var chartMode: WeightChartView.ChartMode
    @Binding var selectedMonthDate: Date
    let weightManager: WeightManager

    // 共有シート表示用
    @State private var isShowingShareSheet = false
    @State private var shareImage: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            header

            WeightChartView(
                weights: weightManager.weights,
                goal: weightManager.goalWeight,
                mode: chartMode,
                displayDate: selectedMonthDate
            )
            .padding(.top, 4)

            exportSection
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("データ分析")
                .font(.title3.bold())

            Spacer()

            Picker("", selection: $chartMode) {
                ForEach(WeightChartView.ChartMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue)
                        .font(.subheadline)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Export (Premium予定)

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                // DEBUG（機能フラグON）のみ実際にレポート生成＆共有を有効化
                guard FeatureFlags.isRecordExportEnabled else { return }

                let context = makeRecordReportContext()
                let image = ReportGenerator.generateRecordSummary(from: context)
                shareImage = image
                isShowingShareSheet = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: FeatureFlags.isRecordExportEnabled ? "square.and.arrow.up" : "lock.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(
                            FeatureFlags.isRecordExportEnabled
                            ? Color.accentColor
                            : .secondary
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("記録をレポートとして保存 / 共有")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)

                        Text(exportDescriptionText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            .disabled(!FeatureFlags.isRecordExportEnabled)

            if !FeatureFlags.isRecordExportEnabled {
                Text("※ 日々の記録入力とグラフの閲覧は、すべて無料でご利用いただけます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var exportDescriptionText: String {
        if FeatureFlags.isRecordExportEnabled {
            return "グラフと記録をレポートにまとめて、画像やPDFとして保存・共有できるようにする機能です。"
        } else {
            return "プレミアム会員向け機能として提供予定です。初期リリースではご利用いただけません。"
        }
    }

    // MARK: - RecordReportContext 生成

    private func makeRecordReportContext() -> RecordReportContext {

        // chartMode.rawValue が「月別 / 年別」などのラベルを持っている前提で、
        // ラベルから月間 / 年間モードを判定
        let mode: RecordReportContext.Mode
        if chartMode.rawValue.contains("年") {
            mode = .yearly
        } else {
            mode = .monthly
        }

        // WeightRecord -> RecordReportPoint に変換
        let points: [RecordReportPoint] = weightManager.weights.map {
            RecordReportPoint(date: $0.date, weight: $0.weight)
        }

        let goal: Double? = (weightManager.goalWeight > 0) ? weightManager.goalWeight : nil
        let height: Double? = (weightManager.height > 0) ? weightManager.height : nil

        return RecordReportContext(
            mode: mode,
            baseDate: selectedMonthDate,
            points: points,
            goalWeight: goal,
            height: height
        )
    }
}
