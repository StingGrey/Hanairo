import SwiftUI

struct RemoteImageView: View {
    @Environment(ImageRepository.self) private var imageRepository
    @Environment(AppSettings.self) private var settings
    @Environment(\.displayScale) private var displayScale

    let url: URL?
    var contentMode: ContentMode = .fill

    @State private var image: CGImage?
    @State private var loadedRequest: RemoteImageRequest?
    @State private var didFail = false

    var body: some View {
        GeometryReader { proxy in
            let request = imageRequest(for: proxy.size)

            ZStack {
                Color.clear

                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .transition(.opacity)
                } else if didFail {
                    Color.gray.opacity(0.28)
                        .accessibilityLabel("图片加载失败")
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("正在加载图片")
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .task(id: request) {
                await load(request)
            }
        }
        .clipped()
    }

    private func load(_ request: RemoteImageRequest) async {
        if loadedRequest == request, image != nil {
            return
        }
        image = nil
        loadedRequest = nil
        didFail = false
        guard let url = request.url else {
            didFail = true
            return
        }
        do {
            let loadedImage = try await imageRepository.image(
                for: url,
                maxPixelSize: request.maxPixelSize
            )
            guard !Task.isCancelled, self.url == url else { return }
            image = loadedImage
            loadedRequest = request
        } catch is CancellationError {
            return
        } catch {
            guard self.url == url else { return }
            didFail = true
        }
    }

    private func imageRequest(for size: CGSize) -> RemoteImageRequest {
        guard settings.highPerformanceImageDecodingEnabled else {
            return RemoteImageRequest(url: url, maxPixelSize: nil)
        }
        guard case .fill = contentMode else {
            return RemoteImageRequest(url: url, maxPixelSize: nil)
        }

        let maximumPointSize = max(size.width, size.height)
        guard maximumPointSize.isFinite, maximumPointSize > 0 else {
            return RemoteImageRequest(url: url, maxPixelSize: nil)
        }
        let requiredPixels = max(Int(ceil(maximumPointSize * displayScale)), 1)
        let bucketSize = 64
        let bucketedPixels = ((requiredPixels + bucketSize - 1) / bucketSize) * bucketSize
        return RemoteImageRequest(url: url, maxPixelSize: bucketedPixels)
    }
}

private struct RemoteImageRequest: Hashable {
    let url: URL?
    let maxPixelSize: Int?
}
