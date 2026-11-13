#if DEBUG
import SwiftUI

extension View {
    /// Capture only: `gh-sim` has no rotate option, so `-ForceLandscape` turns
    /// the iPad sideways a few seconds after launch.
    func forceLandscapeIfRequested() -> some View {
        task {
            guard ProcessInfo.processInfo.arguments.contains("-ForceLandscape") else { return }
            for _ in 0..<3 {
                try? await Task.sleep(for: .seconds(2))
                guard let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene }).first else { continue }
                scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { _ in }
            }
        }
    }
}
#endif
