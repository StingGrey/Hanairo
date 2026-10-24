import SwiftUI

struct ArtworkToolbarActions: ToolbarContent {
    let isBookmarked: Bool
    let isChangingBookmark: Bool
    let isPreparingExport: Bool
    let pageCount: Int
    let shareURL: URL
    let onBookmark: () -> Void
    let onDownloadAll: () -> Void
    let onExportZIP: () -> Void
    let onExportPDF: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: onBookmark) {
                Label(
                    isBookmarked ? "取消收藏" : "收藏",
                    systemImage: isBookmarked ? "heart.fill" : "heart"
                )
                    .foregroundStyle(
                        isBookmarked
                            ? AnyShapeStyle(.tint)
                            : AnyShapeStyle(.primary)
                    )
            }
            .labelStyle(.iconOnly)
            .disabled(isChangingBookmark)
            .accessibilityLabel(isBookmarked ? "取消收藏" : "收藏")

            ShareLink(item: shareURL) {
                Label("分享作品", systemImage: "square.and.arrow.up")
            }
            .labelStyle(.iconOnly)
            .accessibilityLabel("分享作品")

            downloadControl
        }
    }

    private var downloadControl: some View {
        Menu {
            Button(
                pageCount > 1 ? "下载全部 \(pageCount) 页" : "下载作品",
                systemImage: "square.and.arrow.down"
            ) {
                onDownloadAll()
            }

            Divider()
            Button("保存为 ZIP", systemImage: "doc.zipper") {
                onExportZIP()
            }
            Button("保存为 PDF", systemImage: "doc.richtext") {
                onExportPDF()
            }
        } label: {
            if isPreparingExport {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("下载作品", systemImage: "arrow.down.to.line")
            }
        }
        .labelStyle(.iconOnly)
        .disabled(isPreparingExport)
        .accessibilityLabel(isPreparingExport ? "正在生成导出文件" : "下载作品")
    }
}
