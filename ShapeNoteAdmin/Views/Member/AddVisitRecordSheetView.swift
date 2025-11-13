import SwiftUI
import FirebaseFirestore
import ShapeCore

struct AddVisitRecordSheetView: View {
    var user: UserItem
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var note = ""
    @State private var productName = ""
    @State private var price: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("日付")) {
                    DatePicker("来店日", selection: $date, displayedComponents: .date)
                }

                Section(header: Text("内容")) {
                    TextField("メモ（例：パーソナルレッスン）", text: $note)
                    TextField("商品名（例：60分レッスン）", text: $productName)
                    TextField("金額（数字のみ）", text: $price)
                        .keyboardType(.numberPad)
                }

                if let error = errorMessage {
                    Text("⚠️ \(error)")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("新規来店登録")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { Task { await saveRecord() } }
                        .disabled(isSaving)
                }
            }
        }
    }

    // MARK: - Firestore 書き込み
    private func saveRecord() async {
        guard !note.isEmpty else {
            errorMessage = "メモを入力してください。"
            return
        }

        isSaving = true
        let db = Firestore.firestore()
        let newRecord: [String: Any] = [
            "date": dateFormatter.string(from: date),
            "note": note,
            "productName": productName,
            "price": Int(price) ?? 0
        ]

        do {
            try await db.collection("users").document(user.id)
                .updateData(["visitHistory": FieldValue.arrayUnion([newRecord])])
            await MainActor.run {
                isSaving = false
                onSave()
                dismiss()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}
