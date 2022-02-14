import SwiftUI

/// A `Stack` element that changes orientation from to  `VStack` to `HStack` accordinly to a device rotation.
///
/// The natural alignment for a `portrait` is `VStack`, for a `landscape` it is a `HStack`.
/// One can specify that the alignment should not be natural then it is the opposite.
struct AdaptiveStack<Content: View>: View {
    let orientation: UIDeviceOrientation
    let content: () -> Content
    let naturalAlignment: Bool

    init(orientation: UIDeviceOrientation, naturalAlignment: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.orientation = orientation
        self.naturalAlignment = naturalAlignment
        self.content = content
    }

    var body: some View {
        Group {
            if orientation.isLandscape {
                if naturalAlignment {
                    HStack(content: content)
                } else {
                    VStack(content: content)
                }
            } else {
                if naturalAlignment {
                    VStack(content: content)
                } else {
                    HStack(content: content)
                }
            }
        }
    }
}
