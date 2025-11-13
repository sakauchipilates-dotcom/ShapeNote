import Foundation

struct ExerciseItemViewData: Identifiable {
    let id = UUID()
    let title: String
    let action: () -> Void
}
