import SwiftUI

struct ArtworkCard: View {
    @Environment(\.artworkTransitionNamespace) private var artworkTransitionNamespace
    @Environment(PixivRepository.self) private var repository
    @Environment(LocalBlockStore.self) private var localBlocks
    @Environment(ArtworkDownloadManager.self) private var downloadManager
    @Environment(AppSettings.self) private var settings
    @Environment(AppNavigationCoordinator.self) private var navigation

    let illustration: PixivIllustration
    var rank: Int?
    var previewAspectRatio: CGFloat = 0.78
    var enablesQuickSaveOnLongPress = false
    let onBookmark: () async -> Void

    @State private var isChangingBookmark = false
    @State private var isQuickSaving = false
    @State private var downloadNotice: String?

    var body: some View {
        Group {
            if enablesQuickSaveOnLongPress {
                cardContent
            } else {
                cardContent
                    .contextMenu { artworkContextMenu }
            }
        }
        .alert("保存作品", isPresented: downloadNoticeBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(downloadNotice ?? "未知状态")
        }
    }

    private var cardContent: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                interactiveArtworkImage
                Text(illustration.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(illustration.user.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if illustration.aiType == 2 {
                        Text("AI")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.secondary.opacity(0.12), in: Capsule())
                            .fixedSize()
                            .accessibilityLabel("AI 生成作品")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                openArtwork()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "打开作品") {
                openArtwork()
            }
            .zIndex(0)

            bookmarkButton
                .padding(2)
                .accessibilityLabel(isBookmarked ? "取消收藏" : "收藏")
                .zIndex(10)
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    @ViewBuilder
    private var interactiveArtworkImage: some View {
        if enablesQuickSaveOnLongPress {
            artworkImage
                .onLongPressGesture(minimumDuration: 0.55) {
                    quickSave()
                }
                .accessibilityAction(named: "下载全部图片并收藏") {
                    quickSave()
                }
        } else {
            artworkImage
        }
    }

    private var artworkImage: some View {
        RemoteImageView(
            url: illustration.previewURL(for: settings.previewImageQuality)
        )
            .aspectRatio(previewAspectRatio, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipped()
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    if let rank {
                        Text("#\(rank)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.62), in: Capsule())
                    }
                    if illustration.isUgoira {
                        Label("动图", systemImage: "play.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.black.opacity(0.62), in: Capsule())
                    }
                }
                .padding(8)
            }
            .overlay {
                if isQuickSaving {
                    ProgressView()
                        .tint(.white)
                        .padding(11)
                        .background(.black.opacity(0.58), in: Circle())
                        .accessibilityLabel("正在快速保存")
                }
            }
            .artworkTransitionSource(
                id: illustration.id,
                namespace: artworkTransitionNamespace
            )
    }

    @ViewBuilder
    private var artworkContextMenu: some View {
        Button(downloadTitle, systemImage: "arrow.down.circle") {
            enqueueDownload()
        }
        Divider()
        Button("屏蔽作品", systemImage: "photo.badge.minus", role: .destructive) {
            localBlocks.block(artwork: illustration)
        }
        Button("屏蔽作者", systemImage: "person.crop.circle.badge.minus", role: .destructive) {
            localBlocks.block(user: illustration.user)
        }
        if !illustration.tags.isEmpty {
            Menu("屏蔽标签", systemImage: "number") {
                ForEach(illustration.tags) { tag in
                    Button("#\(tag.displayName)") {
                        localBlocks.block(tag: tag)
                    }
                }
            }
        }
    }

    private var downloadTitle: String {
        illustration.pageCount > 1 ? "下载全部图片" : "下载图片"
    }

    private var downloadNoticeBinding: Binding<Bool> {
        Binding(
            get: { downloadNotice != nil },
            set: { if !$0 { downloadNotice = nil } }
        )
    }

    private func enqueueDownload() {
        downloadNotice = downloadManager.enqueue(
            illustration: illustration,
            pageIndices: Array(illustration.originalPageURLs.indices)
        ).message
    }

    private func quickSave() {
        guard
            enablesQuickSaveOnLongPress,
            !isQuickSaving,
            !isChangingBookmark
        else {
            return
        }

        isQuickSaving = true
        let downloadMessage = downloadManager.enqueue(
            illustration: illustration,
            pageIndices: Array(illustration.originalPageURLs.indices),
            appliesAutomaticBookmark: false
        ).message
        let needsBookmark = !isBookmarked

        Task {
            defer { isQuickSaving = false }
            var bookmarkMessage = "作品已收藏"
            if needsBookmark {
                do {
                    try await repository.updateBookmark(
                        id: illustration.id,
                        visibility: settings.defaultBookmarkVisibility,
                        tags: []
                    )
                } catch {
                    bookmarkMessage = "收藏失败：\(error.localizedDescription)"
                }
            }
            downloadNotice = "\(downloadMessage)\n\(bookmarkMessage)"
        }
    }

    private var isBookmarked: Bool {
        repository.bookmarkState(for: illustration)
    }

    private func openArtwork() {
        navigation.push(.illustration(id: illustration.id))
    }

    @ViewBuilder
    private var bookmarkButton: some View {
#if os(visionOS)
        bookmarkButtonContent
            .buttonStyle(.plain)
            .background(.regularMaterial, in: Circle())
#else
        bookmarkButtonContent
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
#endif
    }

    private var bookmarkButtonContent: some View {
        Button {
            guard !isChangingBookmark, !isQuickSaving else { return }
            isChangingBookmark = true
            Task {
                await onBookmark()
                isChangingBookmark = false
            }
        } label: {
            Image(systemName: isBookmarked ? "heart.fill" : "heart")
                .font(.body.weight(.semibold))
                .foregroundStyle(
                    isBookmarked
                        ? AnyShapeStyle(.tint)
                        : AnyShapeStyle(.primary)
                )
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
    }
}
