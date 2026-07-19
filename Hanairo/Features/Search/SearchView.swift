import SwiftUI

struct SearchView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(PixivRepository.self) private var repository
    @Environment(LocalBlockStore.self) private var localBlocks
    @Environment(AppNavigationCoordinator.self) private var navigation
    @Environment(\.dismissSearch) private var dismissSearch
    @State private var store: SearchStore
    @State private var showsFilters = false

    init(initialQuery: String = "") {
        _store = State(initialValue: SearchStore(initialQuery: initialQuery))
    }

    var body: some View {
        @Bindable var store = store

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                content
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle("搜索")
        .searchable(
            text: $store.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "搜索作品、标签、用户或 ID"
        )
        .searchScopes($store.scope) {
            ForEach(SearchScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .onSubmit(of: .search) {
            submitSearch()
        }
        .searchSuggestions {
            if !store.idQueries.isEmpty {
                Section("ID 直达") {
                    ForEach(store.idQueries) { idQuery in
                        Button {
                            openID(idQuery)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(idQuery.target.title)
                                    Text(String(idQuery.value))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: idQuery.target.systemImage)
                            }
                        }
                    }
                }
            } else if store.scope == .illustrations {
                ForEach(store.suggestions) { suggestion in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.name)
                            if let translation = suggestion.translatedName {
                                Text(translation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "number")
                    }
                    .searchCompletion(suggestion.name)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsFilters = true
                } label: {
                    Image(systemName: store.options.isDefault
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel("搜索筛选")
                .disabled(store.scope == .users || !store.idQueries.isEmpty)
            }
        }
        .sheet(isPresented: $showsFilters) {
            SearchFiltersView(
                options: store.options,
                isPremium: authentication.account?.isPremium == true
            ) { options in
                store.options = options
            }
            .presentationDetents([.large])
        }
        .task(id: authentication.userID ?? 0) {
            await store.loadTrending(using: repository)
        }
        .task(id: requestKey) {
            await store.searchIfNeeded(requestKey: requestKey, using: repository)
        }
        .task(id: store.suggestionRequestKey) {
            await store.loadSuggestions(
                suggestionKey: store.suggestionRequestKey,
                using: repository
            )
        }
        .refreshable {
            await store.refresh(requestKey: requestKey, using: repository)
        }
        .alert("操作失败", isPresented: actionErrorBinding) {
            Button("好", role: .cancel) {
                store.clearDisplayedError()
            }
        } message: {
            Text(store.displayedError ?? "未知错误")
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.normalizedQuery.isEmpty {
            searchLanding
        } else if !store.idQueries.isEmpty {
            idQueryResults
        } else {
            switch store.scope {
            case .illustrations:
                illustrationResults
            case .users:
                userResults
            }
        }
    }

    private var idQueryResults: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("按 ID 直达", systemImage: "number")
                .font(.title2.weight(.bold))

            Text("检测到 Pixiv ID。选择要打开的插画或画师；也可以输入 illust:ID、user:ID 来指定类型。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(store.idQueries) { idQuery in
                Button {
                    openID(idQuery)
                } label: {
                    HStack(spacing: 12) {
                        Label(idQuery.target.title, systemImage: idQuery.target.systemImage)
                        Spacer(minLength: 8)
                        Text(String(idQuery.value))
                            .font(.body.monospacedDigit().weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var illustrationResults: some View {
        if !store.options.isDefault {
            Button {
                showsFilters = true
            } label: {
                Label(activeFilterSummary, systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }

        switch store.illustrationResults.phase {
        case .idle, .loading:
            LoadingArtworkGrid()
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await retry() }
            }
            .frame(minHeight: 360)
        case .loaded:
            if store.illustrationResults.items.isEmpty {
                ContentUnavailableView.search(text: store.normalizedQuery)
                    .frame(minHeight: 360)
            } else {
                Text("作品结果")
                    .font(.title2.weight(.bold))
                ArtworkGrid(
                    illustrations: store.illustrationResults.items,
                    onLoadMore: loadMore
                ) { id in
                    await store.toggleBookmark(id: id, using: repository)
                }
                PaginationStatusView(
                    isLoading: store.illustrationResults.isLoadingMore,
                    errorMessage: store.illustrationResults.loadMoreError,
                    onRetry: loadMore
                )
            }
        }
    }

    @ViewBuilder
    private var userResults: some View {
        switch store.userResults.phase {
        case .idle, .loading:
            ProgressView("正在搜索用户…")
                .frame(maxWidth: .infinity, minHeight: 260)
        case let .failed(message):
            ErrorStateView(message: message) {
                Task { await retry() }
            }
            .frame(minHeight: 360)
        case .loaded:
            if visibleUserResults.isEmpty {
                ContentUnavailableView.search(text: store.normalizedQuery)
                    .frame(minHeight: 360)
            } else {
                Text("用户结果")
                    .font(.title2.weight(.bold))
                ForEach(visibleUserResults) { user in
                    UserRow(preview: user, showsFollowButton: true)
                        .task {
                            guard user.id == visibleUserResults.last?.id else { return }
                            await loadMore()
                        }
                    Divider()
                }
                PaginationStatusView(
                    isLoading: store.userResults.isLoadingMore,
                    errorMessage: store.userResults.loadMoreError,
                    onRetry: loadMore
                )
            }
        }
    }

    @ViewBuilder
    private var searchLanding: some View {
        if !store.history.isEmpty {
            HStack {
                Text("最近搜索")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("清除") {
                    store.clearHistory()
                }
                .font(.subheadline)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(store.history, id: \.self) { term in
                        Button(term) {
                            store.query = term
                        }
                        .buttonStyle(.bordered)
                        .contextMenu {
                            Button("移除", systemImage: "trash", role: .destructive) {
                                store.removeHistory(term)
                            }
                        }
                    }
                }
            }
        }

        Text("热门标签")
            .font(.title2.weight(.bold))
        if store.trendingTags.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        } else {
            TrendingTagsView(tags: store.trendingTags) { tag in
                store.scope = .illustrations
                store.query = tag
            }
        }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { store.displayedError != nil },
            set: { if !$0 { store.clearDisplayedError() } }
        )
    }

    private var requestKey: String {
        "\(store.request.key)|\(authentication.userID ?? 0)"
    }

    private var activeFilterSummary: String {
        var values = [store.options.target.title, store.options.sort.title]
        if store.options.mediaFilter != .all {
            values.append(store.options.mediaFilter.title)
        }
        if store.options.aiFilter != .all {
            values.append(store.options.aiFilter.title)
        }
        if store.options.bookmarkThreshold != .any {
            values.append(store.options.bookmarkThreshold.title)
        }
        if store.options.usesDateRange {
            values.append("限定日期")
        }
        return values.joined(separator: " · ")
    }

    private var visibleUserResults: [PixivUserPreview] {
        store.userResults.items.filter { !localBlocks.isBlocked($0.user) }
    }

    private func retry() async {
        await store.retry(requestKey: requestKey, using: repository)
    }

    private func loadMore() async {
        await store.loadMore(requestKey: requestKey, using: repository)
    }

    private func submitSearch() {
        guard !store.normalizedQuery.isEmpty else { return }
        guard let firstQuery = store.idQueries.first else { return }

        if store.idQueries.count == 1 {
            openID(firstQuery)
            return
        }

        let preferredTarget: PixivIDSearchTarget =
            store.scope == .users ? .user : .illustration
        if let preferredQuery = store.idQueries.first(where: { $0.target == preferredTarget }) {
            openID(preferredQuery)
        } else {
            openID(firstQuery)
        }
    }

    private func openID(_ idQuery: PixivIDSearchQuery) {
        dismissSearch()
        // The search tab owns its NavigationStack; push after dismissing the
        // search field so the destination is visible on both iPhone and iPad.
        switch idQuery.target {
        case .illustration:
            navigation.push(.illustration(id: idQuery.value))
        case .user:
            navigation.push(.user(id: idQuery.value))
        }
    }
}

#Preview("搜索首页") {
    NavigationStack {
        SearchView()
    }
    .withPreviewDependencies()
}
