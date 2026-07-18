import SwiftUI

private struct ArtworkTransitionNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var artworkTransitionNamespace: Namespace.ID? {
        get { self[ArtworkTransitionNamespaceKey.self] }
        set { self[ArtworkTransitionNamespaceKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func artworkTransitionSource(
        id: Int,
        namespace: Namespace.ID?
    ) -> some View {
        if let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func artworkNavigationTransition(
        id: Int,
        namespace: Namespace.ID?
    ) -> some View {
        if let namespace {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
