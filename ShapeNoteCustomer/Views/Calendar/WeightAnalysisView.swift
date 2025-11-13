import SwiftUI

struct WeightAnalysisView: View {
    @Binding var chartMode: WeightChartView.ChartMode
    @Binding var selectedMonthDate: Date
    let weightManager: WeightManager

    var body: some View {
        VStack(spacing: 16) {
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

            WeightChartView(
                weights: weightManager.weights,
                goal: weightManager.goalWeight,
                mode: chartMode,
                displayDate: selectedMonthDate
            )
        }
    }
}
