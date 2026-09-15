import Foundation

public struct CleaningOptions {
    public var removeTracking = true
    public var removeInvisible = false
    public var normalizeQuotes = false
    public var removeReferences = false
    public var normalizeNewlines = false
    public init() {}
}

public enum TextCleaner {
    public static func clean(_ text: String, options: CleaningOptions) -> String {
        var result = text
        if options.removeTracking {
            // Work backwards so Unicode ranges remain valid as URLs change length.
            let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            let matches = detector?.matches(in: result, range: NSRange(result.startIndex..., in: result)) ?? []
            for match in matches.reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                result.replaceSubrange(range, with: cleanURL(String(result[range])))
            }
        }
        if options.removeInvisible {
            // Keep ZWJ/ZWNJ: removing them damages emoji and many written languages.
            result = result.replacingOccurrences(of: "[\u{200B}\u{FEFF}\u{2060}\u{00AD}]", with: "", options: .regularExpression)
        }
        if options.normalizeQuotes {
            for (source, replacement) in [("“", "\""), ("”", "\""), ("‘", "'"), ("’", "'")] {
                result = result.replacingOccurrences(of: source, with: replacement)
            }
        }
        if options.removeReferences {
            result = result.replacingOccurrences(of: "\\[(?:[0-9]+(?:[,–-][0-9]+)*|[a-z])\\]", with: "", options: .regularExpression)
        }
        if options.normalizeNewlines {
            result = result.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        }
        return result
    }

    public static func cleanURL(_ value: String) -> String {
        guard let components = URLComponents(string: value),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              let query = components.percentEncodedQuery else { return value }
        let tracking: Set<String> = ["fbclid", "gclid", "dclid", "msclkid", "igshid", "mc_cid", "mc_eid", "_hsenc", "_hsmi", "vero_id", "oly_anon_id", "oly_enc_id", "twclid", "ttclid", "li_fat_id", "srsltid"]
        // Preserve raw query bytes and ordering; decode names only for matching.
        let parts = query.components(separatedBy: "&")
        let kept = parts.filter {
            let rawName = String($0.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)[0])
            let name = (rawName.removingPercentEncoding ?? rawName).lowercased()
            return !name.hasPrefix("utm_") && !tracking.contains(name)
        }
        guard kept.count != parts.count else { return value }
        guard let question = value.firstIndex(of: "?") else { return value }
        let fragment = value[question...].firstIndex(of: "#").map { String(value[$0...]) } ?? ""
        return String(value[..<question]) + (kept.isEmpty ? "" : "?" + kept.joined(separator: "&")) + fragment
    }
}
