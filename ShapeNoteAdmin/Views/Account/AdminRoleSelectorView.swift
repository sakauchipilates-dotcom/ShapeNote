import SwiftUI

struct AdminRoleSelectorView: View {
    @Binding var selectedRole: String
    var isEditable: Bool = false  // ← 開発者のみ true
    private let roles = ["一般", "管理者", "開発者"]

    var body: some View {
        NavigationView {
            VStack {
                if isEditable {
                    Picker("権限レベルを選択", selection: $selectedRole) {
                        ForEach(roles.filter { $0 != "開発者" }, id: \.self) { role in
                            Text(role).tag(role)
                        }
                    }
                    .pickerStyle(.wheel)
                    .padding()

                    Button("保存") {
                        // Firestoreに反映（次フェーズで追加）
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Text("権限レベル：\(selectedRole)")
                            .font(.title3)
                            .padding()

                        Text("⚠️ 権限の変更は「開発者」のみ可能です。")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("権限レベル選択")
        }
    }
}
