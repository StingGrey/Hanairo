import SwiftUI

struct ArtworkGrid: View {
    let illustrations: [PixivIllustration]
    var showsRanking = false
    var columnCount: Int? = nil
    var onLoadMore: (() async -> Void)? = nil
    var usesPreferredColumnCount = true
    let onBookmark: (Int) async -> Void

    var body: some View {
        ArtworkMasonryGrid(
            illustrations: illustrations,
            showsRanking: showsRanking,
            columnCount: columnCount,
            onLoadMore: onLoadMore,
            usesPreferredColumnCount: usesPreferredColumnCount,
            onBookmark: onBookmark
        )
    }
}
