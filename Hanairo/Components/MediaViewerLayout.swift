import SwiftUI

struct MediaViewerLayout<Media: View, Controls: View>: View {
    @ViewBuilder let media: Media
    @ViewBuilder let controls: Controls

    var body: some View {
#if os(iOS)
        if #available(iOS 27.1, *) {
            ArrangementView {
                controls
            } secondary: {
                media
            }
            .arrangementViewStyle(.overlay)
        } else {
            overlay
        }
#else
        overlay
#endif
    }

    private var overlay: some View {
        ZStack {
            media
            controls
        }
    }
}
