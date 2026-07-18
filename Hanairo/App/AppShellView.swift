import SwiftUI

struct AppShellView: View {
    @Environment(AppNavigationCoordinator.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation

        TabView(selection: $navigation.selectedTab) {
            ForEach(AppTab.primaryTabs) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    AppTabRootView(tab: tab)
                }
            }

            Tab(value: AppTab.search, role: .search) {
                AppTabRootView(tab: .search)
            }
        }
        .toolbarBackground(.bar, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
