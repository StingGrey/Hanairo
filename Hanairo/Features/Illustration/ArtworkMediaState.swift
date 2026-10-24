import Observation
import SwiftUI

@MainActor
@Observable
final class ArtworkMediaState {
    let player: UgoiraPlayer
    var loadRequestID: UUID?
    var presentation: ArtworkMediaPresentation?

    init(illustrationID: Int) {
        player = UgoiraPlayer(illustrationID: illustrationID)
    }
}

enum ArtworkMediaPresentation: Identifiable {
    case artwork(page: Int)
    case ugoira(animation: UgoiraAnimation, initialFrame: Int)

    var id: String {
        switch self {
        case let .artwork(page): "artwork-\(page)"
        case .ugoira: "ugoira"
        }
    }
}

struct ArtworkMediaSession: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(UgoiraRepository.self) private var repository
    @Environment(ArtworkDownloadManager.self) private var downloadManager

    @Bindable var state: ArtworkMediaState
    let illustration: PixivIllustration
    let fullSizeURLs: [URL?]

    func body(content: Content) -> some View {
        presentationHost(content)
            .environment(state)
            .task(id: state.loadRequestID) {
                guard state.loadRequestID != nil else { return }
                await state.player.load(using: repository)
            }
            .task(id: state.player.playbackTaskKey) {
                await state.player.runPlayback()
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                state.player.setSuspended(phase != .active, reason: .inactiveScene)
            }
    }

    @ViewBuilder
    private func presentationHost(_ content: Content) -> some View {
#if os(iOS)
        content.fullScreenCover(item: $state.presentation, onDismiss: viewerDidDismiss) {
            viewer(for: $0)
        }
#else
        content.sheet(item: $state.presentation, onDismiss: viewerDidDismiss) {
            viewer(for: $0)
        }
#endif
    }

    @ViewBuilder
    private func viewer(for presentation: ArtworkMediaPresentation) -> some View {
        switch presentation {
        case let .artwork(page):
            ArtworkViewerView(
                title: illustration.title,
                urls: fullSizeURLs,
                initialPage: page,
                onDownload: { page in
                    downloadManager.enqueue(
                        illustration: illustration,
                        pageIndices: [page]
                    ).message
                }
            )
        case let .ugoira(animation, initialFrame):
            UgoiraViewerView(
                animation: animation,
                initialFrame: initialFrame,
                title: illustration.title
            )
        }
    }

    private func viewerDidDismiss() {
        state.player.setSuspended(false, reason: .covered)
    }
}
