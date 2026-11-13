import SwiftUI

extension View {
    /// Caps a full-width column at a readable width and centres it. On iPhone
    /// the cap never binds (the screen is narrower), so phones are unchanged.
    func readableWidth(_ maxWidth: CGFloat = 560) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
