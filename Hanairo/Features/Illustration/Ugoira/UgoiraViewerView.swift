import SwiftUI

struct UgoiraViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let animation: UgoiraAnimation
    let initialFrame: Int
    let title: String

    @State private var player: UgoiraPlayer
    @State private var preparationID = UUID()

    init(animation: UgoiraAnimation, initialFrame: Int, title: String) {
        self.animation = animation
        self.initialFrame = initialFrame
        self.title = title
        _player = State(initialValue: UgoiraPlayer(illustrationID: animation.illustrationID))
    }

    var body: some View {
        NavigationStack {
            MediaViewerLayout {
                viewerContent
            } controls: {
                VStack {
                    Spacer()
                    if player.isReady {
                        UgoiraPlaybackControls(player: player)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(title.isEmpty ? "查看动图" : title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", systemImage: "xmark") {
                        dismiss()
                    }
                    .accessibilityLabel("关闭动图")
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .background(Color.black)
        .presentationBackground(.black)
        .environment(\.colorScheme, .dark)
        .task(id: preparationID) {
            await player.prepare(animation: animation, initialFrame: initialFrame)
        }
        .task(id: player.playbackTaskKey) {
            await player.runPlayback()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            player.setSuspended(phase != .active, reason: .inactiveScene)
        }
    }

    @ViewBuilder
    private var viewerContent: some View {
        switch player.phase {
        case .idle, .loading:
            ProgressView("正在准备动图…")
                .tint(.white)
                .foregroundStyle(.white)
        case let .failed(message):
            VStack(spacing: 14) {
                ContentUnavailableView(
                    "动图无法播放",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
                Button("重试", systemImage: "arrow.clockwise") {
                    preparationID = UUID()
                }
                .buttonStyle(.borderedProminent)
            }
            .foregroundStyle(.white)
        case .ready:
            ZoomableMediaView {
                UgoiraFrameView(image: player.currentImage)
            }
        }
    }

}
