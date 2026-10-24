import SwiftUI

struct ArtworkPagesView: View {
    @Environment(ArtworkMediaState.self) private var mediaState

    let illustration: PixivIllustration
    let displayURLs: [URL?]

    var body: some View {
        if illustration.isUgoira {
            UgoiraPlayerView(illustration: illustration)
        } else {
            pages
        }
    }

    private var pages: some View {
        LazyVStack(spacing: 2) {
            ForEach(displayURLs.indices, id: \.self) { index in
                Button {
                    mediaState.presentation = .artwork(page: index)
                } label: {
                    RemoteImageView(url: displayURLs[index], contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(clampedAspectRatio, contentMode: .fit)
                        .clipped()
                        .overlay(alignment: .topTrailing) {
                            if displayURLs.count > 1 {
                                pageBadge(index: index)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看第 \(index + 1) 页大图")
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var clampedAspectRatio: CGFloat {
        min(max(illustration.aspectRatio, 0.42), 1.6)
    }

    private func pageBadge(index: Int) -> some View {
        Text("\(index + 1) / \(displayURLs.count)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(10)
    }
}
