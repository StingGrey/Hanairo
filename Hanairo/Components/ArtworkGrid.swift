import SwiftUI

struct ArtworkGrid: View {
    let illustrations: [PixivIllustration]
    var showsRanking = false
    var onLoadMore: (() async -> Void)? = nil
    var usesPreferredColumnCount = true
    let onBookmark: (Int) async -> Void

    var body: some View {
        ArtworkMasonryGrid(
            illustrations: illustrations,
            showsRanking: showsRanking,
            onLoadMore: onLoadMore,
            usesPreferredColumnCount: usesPreferredColumnCount,
            onBookmark: onBookmark
        )
    }
}
