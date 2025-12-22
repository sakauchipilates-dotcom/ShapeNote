import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {

    let items: [Any]
    let activities: [UIActivity]? = nil
    let excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: activities)
        vc.excludedActivityTypes = excludedActivityTypes
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
