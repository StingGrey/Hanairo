import CoreGraphics
import Foundation
import ImageIO
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class ReverseImageSearchService {
    private let client: NetworkClient

    private static let endpoint = URL(string: "https://saucenao.com/search.php")!
    nonisolated private static let maximumImageDimension = 720

    init(sessionProvider: NetworkSessionProvider) {
        client = NetworkClient(sessionProvider: sessionProvider)
    }

    func prepareJPEG(from data: Data) async throws -> Data {
        guard !data.isEmpty else { throw ReverseImageSearchError.invalidImage }
        return try await Task.detached(priority: .userInitiated) {
            try Self.makeJPEG(from: data)
        }.value
    }

    func searchPixivArtworkIDs(jpegData: Data) async throws -> [Int] {
        guard !jpegData.isEmpty else { throw ReverseImageSearchError.invalidImage }

        let boundary = "HanairoBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("Hanairo Reverse Image Search", forHTTPHeaderField: "User-Agent")
        request.httpBody = Self.multipartBody(jpegData: jpegData, boundary: boundary)

        let responseData = try await client.data(for: request)
        guard
            let html = String(data: responseData, encoding: .utf8)
                ?? String(data: responseData, encoding: .isoLatin1)
        else {
            throw NetworkError.invalidResponse
        }

        let normalizedHTML = html.lowercased()
        if
            normalizedHTML.contains("daily search limit exceeded")
                || normalizedHTML.contains("search rate too high")
        {
            throw ReverseImageSearchError.rateLimited
        }
        return SauceNAOResponseParser.pixivArtworkIDs(in: html)
    }

    nonisolated private static func makeJPEG(from data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ReverseImageSearchError.invalidImage
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        let sourceMaximumDimension = max(width, height)
        guard sourceMaximumDimension > 0 else { throw ReverseImageSearchError.invalidImage }

        let targetDimension = min(sourceMaximumDimension, maximumImageDimension)
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard
            let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                thumbnailOptions as CFDictionary
            )
        else {
            throw ReverseImageSearchError.invalidImage
        }

        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            throw ReverseImageSearchError.encodingFailed
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw ReverseImageSearchError.encodingFailed
        }
        return output as Data
    }

    nonisolated private static func multipartBody(jpegData: Data, boundary: String) -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"db\"\r\n\r\n".utf8))
        body.append(Data("999\r\n".utf8))
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(
            Data(
                "Content-Disposition: form-data; name=\"file\"; filename=\"hanairo-search.jpg\"\r\n".utf8
            )
        )
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpegData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }
}

enum ReverseImageSearchError: LocalizedError {
    case invalidImage
    case encodingFailed
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "无法读取所选图片，请尝试其他图片"
        case .encodingFailed:
            "图片处理失败，请尝试其他图片"
        case .rateLimited:
            "SauceNAO 搜索次数已达当前限制，请稍后再试"
        }
    }
}
