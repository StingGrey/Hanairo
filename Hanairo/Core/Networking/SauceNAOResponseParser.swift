import Foundation

enum SauceNAOResponseParser {
    nonisolated private static let maximumResultCount = 12

    nonisolated static func pixivArtworkIDs(in html: String) -> [Int] {
        let pattern = #"(?i)(?:https?:)?(?:\\?/){2}(?:www\.)?pixiv\.net(?:\\?/)(?:(?:[a-z]{2}(?:\\?/))?(?:artworks|i)(?:\\?/)([1-9][0-9]*)|[^\"'<>\s]*?illust_id(?:=|%3d)([1-9][0-9]*))"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(html.startIndex..., in: html)
        var seen = Set<Int>()
        var results: [Int] = []
        for match in expression.matches(in: html, range: range) {
            let captureRanges = [match.range(at: 1), match.range(at: 2)]
            guard
                let capture = captureRanges.first(where: { $0.location != NSNotFound }),
                let stringRange = Range(capture, in: html),
                let id = Int(html[stringRange]),
                seen.insert(id).inserted
            else {
                continue
            }
            results.append(id)
            if results.count == maximumResultCount {
                break
            }
        }
        return results
    }
}
