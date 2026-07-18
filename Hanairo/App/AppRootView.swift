import SwiftUI

struct AppRootView: View {
    @Environment(AuthenticationStore.self) private var authentication
    @Environment(AppNavigationCoordinator.self) private var navigation
    @Environment(AppSettings.self) private var settings
    @Environment(AppUpdateChecker.self) private var updateChecker
    @Environment(AppTheme.self) private var theme
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var automaticUpdate: AppRelease?

    var body: some View {
        Group {
            switch rootState {
            case .restoring:
                LaunchView()
            case .authenticated:
                AppShellView()
            case .requiresAuthentication:
                NavigationStack {
                    LoginView()
                }
            }
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.25), value: rootState)
        .tint(theme.accentColor)
        .task(id: accountThemeImageURL) {
            await theme.updateAccountAccent(imageURL: accountThemeImageURL)
        }
        .task(id: rootState) {
            guard rootState != .restoring else { return }
            await checkForAutomaticUpdateIfNeeded()
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            Task { await checkForAutomaticUpdateIfNeeded() }
        }
        .onChange(of: settings.updateRemindersEnabled) {
            guard settings.updateRemindersEnabled else { return }
            Task { await checkForAutomaticUpdateIfNeeded(force: true) }
        }
        .onOpenURL { url in
            navigation.open(url)
        }
        .alert(
            "发现新版本",
            isPresented: automaticUpdateBinding,
            presenting: automaticUpdate
        ) { update in
            Button("查看发布页") {
                openURL(update.releaseURL)
            }
            Button("稍后", role: .cancel) {}
        } message: { update in
            Text("Hanairo \(update.version) 已发布。\n\(update.title)")
        }
    }

    private var accountThemeImageURL: URL? {
        authentication.account?.profileImageURLs.large
            ?? authentication.account?.profileImageURLs.medium
            ?? authentication.account?.profileImageURLs.small
    }

    private var rootState: RootState {
        if authentication.isRestoring {
            return .restoring
        }
        return authentication.isAuthenticated ? .authenticated : .requiresAuthentication
    }

    private var automaticUpdateBinding: Binding<Bool> {
        Binding(
            get: { automaticUpdate != nil },
            set: { if !$0 { automaticUpdate = nil } }
        )
    }

    private func checkForAutomaticUpdateIfNeeded(force: Bool = false) async {
        guard settings.updateRemindersEnabled else { return }
        guard force || settings.shouldAutomaticallyCheckForUpdates() else { return }

        do {
            let status = try await updateChecker.checkForUpdate()
            settings.recordAutomaticUpdateCheck()
            guard case let .available(release) = status else { return }
            guard settings.lastNotifiedUpdateTag != release.tag else { return }
            settings.recordNotifiedUpdate(tag: release.tag)
            automaticUpdate = release
        } catch is CancellationError {
            return
        } catch AppUpdateCheckError.checkAlreadyInProgress {
            return
        } catch {
            settings.recordAutomaticUpdateCheck()
        }
    }
}

private enum RootState: Hashable {
    case restoring
    case authenticated
    case requiresAuthentication
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.pink.gradient)
                    .symbolEffect(.pulse)
                Text("Hanairo")
                    .font(.title2.weight(.semibold))
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

#Preview {
    let authentication = AuthenticationStore()
    let settings = AppSettings()
    let networkSettings = NetworkSettings()
    let sessionProvider = NetworkSessionProvider(settings: networkSettings)
    let localBlocks = LocalBlockStore()
    let browsingHistory = BrowsingHistoryStore(
        settings: settings,
        fileURL: FileManager.default.temporaryDirectory
            .appending(path: "Hanairo-AppRoot-Preview-History.json")
    )
    let repository = PixivRepository(
        authentication: authentication,
        settings: settings,
        localBlocks: localBlocks,
        networkSettings: networkSettings,
        sessionProvider: sessionProvider
    )
    let imageRepository = ImageRepository(
        settings: settings,
        networkSettings: networkSettings,
        sessionProvider: sessionProvider
    )
    AppRootView()
        .environment(AppNavigationCoordinator())
        .environment(authentication)
        .environment(settings)
        .environment(networkSettings)
        .environment(localBlocks)
        .environment(browsingHistory)
        .environment(repository)
        .environment(imageRepository)
        .environment(AppTheme(imageRepository: imageRepository))
        .environment(
            AppUpdateChecker(client: NetworkClient(sessionProvider: sessionProvider))
        )
        .environment(
            UgoiraRepository(
                pixivRepository: repository,
                settings: settings,
                networkSettings: networkSettings,
                sessionProvider: sessionProvider
            )
        )
        .environment(
            ArtworkDownloadManager(
                imageRepository: imageRepository,
                repository: repository,
                settings: settings
            )
        )
}
