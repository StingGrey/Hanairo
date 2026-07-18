import Foundation
import ImageIO
import Observation

@MainActor
@Observable
final class ImageRepository {
    private var cache: [ImageCacheKey: CGImage] = [:]
    private var insertionOrder: [ImageCacheKey] = []
    private let sessionProvider: NetworkSessionProvider
    private let networkSettings: NetworkSettings
    private let diskCache: DiskCacheStore
    private let settings: AppSettings
    private let decoder = ImageDecoder()
    private let capacity = 48

    init(
        settings: AppSettings,
        networkSettings: NetworkSettings,
        sessionProvider: NetworkSessionProvider
    ) {
        self.settings = settings
        self.networkSettings = networkSettings
        self.sessionProvider = sessionProvider
        diskCache = DiskCacheStore(
            directoryName: "ImageCache",
            capacityBytes: settings.imageCacheCapacityBytes
        )
    }

    func image(for url: URL, maxPixelSize: Int? = nil) async throws -> CGImage {
        let normalizedPixelSize = maxPixelSize.map { max($0, 1) }
        let cacheKey = ImageCacheKey(url: url, maxPixelSize: normalizedPixelSize)
        if let cached = cache[cacheKey] {
            return cached
        }
        let data = try await data(for: url)
        let decodedImage = try await decoder.image(
            from: data,
            maxPixelSize: normalizedPixelSize
        )
        let image = decodedImage.value
        if cache.count >= capacity, let oldest = insertionOrder.first {
            cache[oldest] = nil
            insertionOrder.removeFirst()
        }
        cache[cacheKey] = image
        insertionOrder.append(cacheKey)
        return image
    }

    func data(for url: URL, bypassingCache: Bool = false) async throws -> Data {
        if !bypassingCache, let cachedData = await diskCache.data(forKey: url.absoluteString) {
            if await decoder.isValidImageData(cachedData) {
                return cachedData
            }
            await diskCache.removeValue(forKey: url.absoluteString)
        }

        var request = URLRequest(url: networkSettings.resolvedImageURL(url))
        request.setValue("https://www.pixiv.net/", forHTTPHeaderField: "Referer")
        request.setValue(APIConfiguration.userAgent, forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await sessionProvider.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        }
        guard
            let response = response as? HTTPURLResponse,
            200..<300 ~= response.statusCode,
            !data.isEmpty
        else {
            throw NetworkError.invalidImage
        }
        guard await decoder.isValidImageData(data) else {
            throw NetworkError.invalidImage
        }
        await diskCache.store(data, forKey: url.absoluteString)
        return data
    }

    func clear() async {
        cache.removeAll(keepingCapacity: false)
        insertionOrder.removeAll(keepingCapacity: false)
        await diskCache.clear()
    }

    func cacheUsage() async -> CacheUsage {
        await diskCache.usage()
    }

    func updateCacheCapacity() async {
        await diskCache.updateCapacityBytes(settings.imageCacheCapacityBytes)
    }

}

private actor ImageDecoder {
    func isValidImageData(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return false
        }
        return CGImageSourceGetCount(source) > 0
    }

    func image(
        from data: Data,
        maxPixelSize: Int?
    ) throws -> SendableCGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw NetworkError.invalidImage
        }

        let image: CGImage?
        if let maxPixelSize {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCache: true,
                kCGImageSourceShouldCacheImmediately: true
            ]
            image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                options as CFDictionary
            )
        } else {
            let options: [CFString: Any] = [
                kCGImageSourceShouldCache: true,
                kCGImageSourceShouldCacheImmediately: true
            ]
            image = CGImageSourceCreateImageAtIndex(
                source,
                0,
                options as CFDictionary
            )
        }

        guard let image else {
            throw NetworkError.invalidImage
        }
        return SendableCGImage(value: image)
    }
}

private struct SendableCGImage: @unchecked Sendable {
    let value: CGImage
}

private struct ImageCacheKey: Hashable {
    let url: URL
    let maxPixelSize: Int?
}
