import SwiftUI

struct AquaStartupErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("\(AppBrand.displayName) Couldn’t Start", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Your hydration data could not be opened. Restart the app and try again.")
        }
        .accessibilityHint(error.localizedDescription)
    }
}
