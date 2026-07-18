import Foundation
import Observation

struct AppRelease: Identifiable, Sendable {
    let tag: String
    let version: String
    let title: String
    let releaseURL: URL

    var id: String { tag }
}

enum AppUpdateCheckStatus: Sendable {
    case available(AppRelease)
    case upToDate(currentVersion: String, latestVersion: String)
}

enum AppUpdateCheckError: LocalizedError {
    case checkAlreadyInProgress
    case invalidVersion(current: String, latest: String)

    var errorDescription: String? {
        switch self {
        case .checkAlreadyInProgress:
            "正在检查更新，请稍候。"
        case let .invalidVersion(current, latest):
            "无法比较版本号（当前 \(current)，最新 \(latest)）。"
        }
    }
}

@MainActor
@Observable
final class AppUpdateChecker {
    private(set) var isChecking = false

    private let client: NetworkClient
    private let decoder = JSONDecoder()

    init(client: NetworkClient) {
        self.client = client
    }

    func checkForUpdate() async throws -> AppUpdateCheckStatus {
        guard !isChecking else {
            throw AppUpdateCheckError.checkAlreadyInProgress
        }

        isChecking = true
        defer { isChecking = false }

        var request = URLRequest(
            url: URL(string: "https://api.github.com/repos/StingGrey/Hanairo/releases/latest")!
        )
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Hanairo/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

        let data = try await client.data(for: request)
        let response = try decoder.decode(GitHubReleaseResponse.self, from: data)
        let currentVersion = Self.currentVersion

        guard
            let current = NumericVersion(currentVersion),
            let latest = NumericVersion(response.tagName)
        else {
            throw AppUpdateCheckError.invalidVersion(
                current: currentVersion,
                latest: response.tagName
            )
        }

        let latestDisplayVersion = Self.displayVersion(response.tagName)
        guard latest > current else {
            return .upToDate(
                currentVersion: currentVersion,
                latestVersion: latest == current ? currentVersion : latestDisplayVersion
            )
        }

        return .available(
            AppRelease(
                tag: response.tagName,
                version: latestDisplayVersion,
                title: response.name?.nonEmpty ?? response.tagName,
                releaseURL: response.htmlURL
            )
        )
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }

    private static func displayVersion(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, first == "v" || first == "V" else {
            return trimmed
        }
        return String(trimmed.dropFirst())
    }
}

private struct GitHubReleaseResponse: Decodable {
    let tagName: String
    let name: String?
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
    }
}

private struct NumericVersion: Comparable {
    let components: [Int]

    init?(_ rawValue: String) {
        guard let start = rawValue.firstIndex(where: { $0.isNumber }) else { return nil }
        let numericPart = rawValue[start...].prefix { character in
            character.isNumber || character == "."
        }
        let parts = numericPart.split(separator: ".", omittingEmptySubsequences: false)
        guard
            !parts.isEmpty,
            parts.allSatisfy({ !$0.isEmpty && Int($0) != nil })
        else {
            return nil
        }
        components = parts.compactMap { Int($0) }
    }

    static func == (lhs: NumericVersion, rhs: NumericVersion) -> Bool {
        compare(lhs, rhs) == 0
    }

    static func < (lhs: NumericVersion, rhs: NumericVersion) -> Bool {
        compare(lhs, rhs) < 0
    }

    private static func compare(_ lhs: NumericVersion, _ rhs: NumericVersion) -> Int {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right ? -1 : 1
            }
        }
        return 0
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
