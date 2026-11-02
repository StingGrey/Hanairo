import SwiftUI

struct UgoiraPlayerView: View {
    @Environment(ArtworkMediaState.self) private var mediaState

    let illustration: PixivIllustration

    private var player: UgoiraPlayer {
        mediaState.player
    }

    var body: some View {
        playerContent
            .frame(maxWidth: .infinity)
            .aspectRatio(clampedAspectRatio, contentMode: .fit)
            .background(.black)
            .clipped()
    }

    @ViewBuilder
    private var playerContent: some View {
        ZStack {
            switch player.phase {
            case .ready:
                UgoiraFrameView(image: player.currentImage)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        presentViewer()
                    }
            case .idle, .loading, .failed:
                RemoteImageView(url: illustration.previewURL, contentMode: .fit)
            }

            switch player.phase {
            case .idle:
                playButton
            case let .loading(stage):
                loadingOverlay(stage)
            case let .failed(message):
                failureOverlay(message)
            case .ready:
                EmptyView()
            }
        }
        .overlay(alignment: .bottom) {
            if player.isReady {
                UgoiraPlaybackControls(player: player, onFullscreen: presentViewer)
                    .padding(10)
            }
        }
        .overlay(alignment: .topLeading) {
            Label("动图", systemImage: "play.rectangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(.black.opacity(0.58), in: Capsule())
                .padding(10)
        }
    }

    private var playButton: some View {
        Button("播放动图", systemImage: "play.fill") {
            mediaState.loadRequestID = UUID()
        }
        .labelStyle(.iconOnly)
        .font(.title2.weight(.semibold))
        .foregroundStyle(.white)
        .frame(width: 58, height: 58)
        .background(.black.opacity(0.58), in: Circle())
        .buttonStyle(.plain)
        .accessibilityHint("下载并播放 Ugoira")
    }

    private func loadingOverlay(_ stage: UgoiraLoadingStage) -> some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(.white)
            Text(stage.title)
                .font(.caption)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.62), in: Capsule())
    }

    private func failureOverlay(_ message: String) -> some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            Button("重新加载", systemImage: "arrow.clockwise") {
                mediaState.loadRequestID = UUID()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(14)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding()
    }

    private func presentViewer() {
        guard let animation = player.animation else { return }
        player.setSuspended(true, reason: .covered)
        mediaState.presentation = .ugoira(
            animation: animation,
            initialFrame: player.currentFrameIndex
        )
    }

    private var clampedAspectRatio: CGFloat {
        min(max(illustration.aspectRatio, 0.42), 1.6)
    }
}
