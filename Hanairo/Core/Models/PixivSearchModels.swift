import Foundation

enum PixivIDSearchTarget: String, CaseIterable, Identifiable, Hashable, Sendable {
    case illustration
    case user

    var id: String { rawValue }

    var title: String {
        switch self {
        case .illustration: "插画 ID"
        case .user: "画师 ID"
        }
    }

    var systemImage: String {
        switch self {
        case .illustration: "photo"
        case .user: "person.crop.circle"
        }
    }
}

struct PixivIDSearchQuery: Identifiable, Hashable, Sendable {
    let target: PixivIDSearchTarget
    let value: Int

    var id: String { "\(target.rawValue)-\(value)" }
}

enum PixivIDSearchParser {
    private static let illustrationPrefixes: Set<String> = [
        "i", "illust", "illustid", "illust_id", "artwork", "artworks",
        "artworkid",
        "插画", "插画id", "作品", "作品id"
    ]
    private static let userPrefixes: Set<String> = [
        "u", "user", "userid", "user_id", "painter", "painterid",
        "artist", "artistid", "pid", "画师", "画师id", "作者", "作者id"
    ]

    static func parse(_ query: String) -> [PixivIDSearchQuery] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }

        if let explicit = parseExplicit(term) {
            return [explicit]
        }

        guard let id = positiveID(term) else { return [] }
        return [
            PixivIDSearchQuery(target: .illustration, value: id),
            PixivIDSearchQuery(target: .user, value: id)
        ]
    }

    private static func parseExplicit(_ term: String) -> PixivIDSearchQuery? {
        let pieces = term.split { character in
            character == ":"
                || character == "/"
                || character == "#"
                || character == "="
                || character == "-"
                || character.isWhitespace
        }
        guard pieces.count >= 2, let last = pieces.last else { return nil }

        let prefix = pieces.dropLast().map { String($0) }.joined().lowercased()
        guard let id = positiveID(String(last)) else { return nil }
        if illustrationPrefixes.contains(prefix) {
            return PixivIDSearchQuery(target: .illustration, value: id)
        }
        if userPrefixes.contains(prefix) {
            return PixivIDSearchQuery(target: .user, value: id)
        }
        return nil
    }

    private static func positiveID(_ value: String) -> Int? {
        guard let id = Int(value), id > 0 else { return nil }
        return id
    }
}

enum PixivSearchTarget: String, CaseIterable, Identifiable, Codable, Sendable {
    case partialTag = "partial_match_for_tags"
    case exactTag = "exact_match_for_tags"
    case titleAndCaption = "title_and_caption"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .partialTag: "标签部分匹配"
        case .exactTag: "标签完全匹配"
        case .titleAndCaption: "标题与简介"
        }
    }
}

enum PixivSearchSort: String, CaseIterable, Identifiable, Codable, Sendable {
    case newest = "date_desc"
    case oldest = "date_asc"
    case popular = "popular_desc"
    case popularAmongMen = "popular_male_desc"
    case popularAmongWomen = "popular_female_desc"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "最新优先"
        case .oldest: "最早优先"
        case .popular: "热门优先"
        case .popularAmongMen: "男性用户热门"
        case .popularAmongWomen: "女性用户热门"
        }
    }

    var requiresPremium: Bool {
        switch self {
        case .newest, .oldest: false
        case .popular, .popularAmongMen, .popularAmongWomen: true
        }
    }
}

enum PixivSearchMediaFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case all
    case illustrations
    case manga
    case ugoira

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部作品"
        case .illustrations: "仅插画"
        case .manga: "仅漫画"
        case .ugoira: "仅动图"
        }
    }

    func includes(_ illustration: PixivIllustration) -> Bool {
        switch self {
        case .all: true
        case .illustrations: illustration.type == "illust"
        case .manga: illustration.type == "manga"
        case .ugoira: illustration.isUgoira
        }
    }
}

enum PixivSearchAIFilter: Int, CaseIterable, Identifiable, Codable, Sendable {
    case all = 0
    case excludesAI = 1

    var id: Int { rawValue }
    var title: String { self == .all ? "包含 AI 作品" : "排除 AI 作品" }
}

enum PixivBookmarkThreshold: Int, CaseIterable, Identifiable, Codable, Sendable {
    case any = 0
    case oneHundred = 100
    case fiveHundred = 500
    case oneThousand = 1_000
    case fiveThousand = 5_000
    case tenThousand = 10_000

    var id: Int { rawValue }
    var title: String { self == .any ? "不限" : "至少 \(rawValue) 收藏" }
}

struct PixivSearchOptions: Hashable, Codable, Sendable {
    var target: PixivSearchTarget = .partialTag
    var sort: PixivSearchSort = .newest
    var mediaFilter: PixivSearchMediaFilter = .all
    var aiFilter: PixivSearchAIFilter = .all
    var bookmarkThreshold: PixivBookmarkThreshold = .any
    var usesDateRange = false
    var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate = Date()

    var isDefault: Bool {
        target == .partialTag
            && sort == .newest
            && mediaFilter == .all
            && aiFilter == .all
            && bookmarkThreshold == .any
            && !usesDateRange
    }

    func effectiveWord(_ word: String) -> String {
        guard bookmarkThreshold != .any else { return word }
        return "\(word) \(bookmarkThreshold.rawValue)users入り"
    }
}

struct SearchAutocompleteResponse: Decodable, Sendable {
    let tags: [PixivTag]
}
