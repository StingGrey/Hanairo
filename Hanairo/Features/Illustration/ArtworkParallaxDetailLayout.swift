import SwiftUI

struct ArtworkParallaxDetailLayout<Foreground: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let illustration: PixivIllustration
    let displayURLs: [URL?]
    let fullSizeURLs: [URL?]
    let isParallaxEnabled: Bool
    @ViewBuilder let foreground: Foreground

    @State private var scrollOffset: CGFloat = 0

    init(
        illustration: PixivIllustration,
        displayURLs: [URL?],
        fullSizeURLs: [URL?],
        isParallaxEnabled: Bool,
        @ViewBuilder foreground: () -> Foreground
    ) {
        self.illustration = illustration
        self.displayURLs = displayURLs
        self.fullSizeURLs = fullSizeURLs
        self.isParallaxEnabled = isParallaxEnabled
        self.foreground = foreground()
    }

    @ViewBuilder
    var body: some View {
        if isParallaxEnabled && horizontalSizeClass == .compact {
            detailLayout
#if os(iOS)
                .ignoresSafeArea(edges: .top)
#endif
        } else {
            detailLayout
        }
    }

    private var detailLayout: some View {
        GeometryReader { proxy in
            if usesSplitLayout(availableWidth: proxy.size.width) {
                splitLayout(in: proxy)
            } else {
                stackedLayout(in: proxy)
            }
        }
        .background {
            ArtworkDetailSurface()
                .ignoresSafeArea()
        }
        .scrollIndicators(.hidden)
    }

    private func stackedLayout(in proxy: GeometryProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ArtworkDetailPagesLayout(
                    illustration: illustration,
                    displayURLs: displayURLs,
                    fullSizeURLs: fullSizeURLs,
                    availableWidth: proxy.size.width,
                    viewportHeight: proxy.size.height,
                    scrollOffset: scrollOffset,
                    isParallaxEnabled: isParallaxEnabled
                )
                .zIndex(0)

                foreground
                    .padding(.top, isParallaxEnabled ? -32 : 20)
                    .zIndex(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, newOffset in
            scrollOffset = newOffset
        }
        .scrollEdgeEffectHidden(true, for: .top)
    }

    private func splitLayout(in proxy: GeometryProxy) -> some View {
        let dividerWidth: CGFloat = 1
        let sidebarWidth = splitSidebarWidth(availableWidth: proxy.size.width)
        let mediaWidth = max(proxy.size.width - sidebarWidth - dividerWidth, 1)

        return HStack(spacing: 0) {
            ScrollView {
                ArtworkDetailPagesLayout(
                    illustration: illustration,
                    displayURLs: displayURLs,
                    fullSizeURLs: fullSizeURLs,
                    availableWidth: mediaWidth,
                    viewportHeight: proxy.size.height,
                    scrollOffset: 0,
                    isParallaxEnabled: false
                )
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .frame(width: mediaWidth)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectHidden(true, for: .top)

            Divider()
                .frame(width: dividerWidth)

            ScrollView {
                foreground
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
            .frame(width: sidebarWidth)
            .environment(\.horizontalSizeClass, .compact)
            .scrollEdgeEffectHidden(true, for: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func usesSplitLayout(availableWidth: CGFloat) -> Bool {
        availableWidth >= 900
            && horizontalSizeClass != .compact
            && !dynamicTypeSize.isAccessibilitySize
            && prefersSplitLayoutForArtwork
    }

    private var prefersSplitLayoutForArtwork: Bool {
        illustration.aspectRatio > 0 && illustration.aspectRatio <= 1.1
    }

    private func splitSidebarWidth(availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth * 0.34, 340), 460)
    }
}

private struct ArtworkDetailPagesLayout: View {
    let illustration: PixivIllustration
    let displayURLs: [URL?]
    let fullSizeURLs: [URL?]
    let availableWidth: CGFloat
    let viewportHeight: CGFloat
    let scrollOffset: CGFloat
    let isParallaxEnabled: Bool

    @ViewBuilder
    var body: some View {
        if isParallaxEnabled {
            parallaxPages
        } else {
            pages
        }
    }

    private var parallaxPages: some View {
        ZStack(alignment: .top) {
            pages
                .overlay(alignment: .bottom) {
                    ArtworkImageTransition()
                        .frame(height: transitionHeight)
                        .opacity(transitionProgress)
                        .allowsHitTesting(false)
                }
                .offset(y: parallaxOffset)
        }
        .frame(height: mediaHeight, alignment: .top)
    }

    private var pages: some View {
        ArtworkPagesView(
            illustration: illustration,
            displayURLs: displayURLs,
            fullSizeURLs: fullSizeURLs
        )
        .frame(width: availableWidth, height: mediaHeight, alignment: .top)
    }

    private var mediaHeight: CGFloat {
        let pageCount = max(displayURLs.count, 1)
        let pageHeight = availableWidth / clampedAspectRatio
        return pageHeight * CGFloat(pageCount) + CGFloat(max(pageCount - 1, 0)) * 2
    }

    private var parallaxOffset: CGFloat {
        min(activeScrollOffset * 0.55, max(viewportHeight, 1) * 0.55)
    }

    private var parallaxStartOffset: CGFloat {
        max(mediaHeight - max(viewportHeight, 1) - 32, 0)
    }

    private var transitionHeight: CGFloat {
        let viewportTransition = min(max(viewportHeight * 0.28, 180), 280)
        return min(viewportTransition, max(mediaHeight * 0.3, 100))
    }

    private var activeScrollOffset: CGFloat {
        max(scrollOffset - parallaxStartOffset, 0)
    }

    private var transitionProgress: CGFloat {
        min(activeScrollOffset / max(transitionHeight * 0.7, 1), 1)
    }

    private var clampedAspectRatio: CGFloat {
        min(max(illustration.aspectRatio, 0.42), 1.6)
    }
}

private struct ArtworkImageTransition: View {
    var body: some View {
        ArtworkDetailSurface()
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.12), location: 0.2),
                        .init(color: .black.opacity(0.55), location: 0.65),
                        .init(color: .black, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }
}

private struct ArtworkDetailSurface: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
            Color.secondary.opacity(0.04)
            Color.accentColor.opacity(0.08)
        }
    }
}
