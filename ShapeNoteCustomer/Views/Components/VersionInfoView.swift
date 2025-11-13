import SwiftUI

struct VersionInfoView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("ShapeNote")
                .font(.title2.bold())
            Text("バージョン 1.0.0")
                .foregroundColor(.gray)
        }
        .padding()
        .navigationTitle("バージョン情報")
    }
}
