import Foundation

/// Unicode payloads for short single-line replacements. Control keys are never typed.
public enum TypingPlan {
    public static func chunks(for text: String) -> [[UInt16]]? {
        guard !text.isEmpty, text.utf16.count <= 2000,
              !text.unicodeScalars.contains(where: { $0.value < 0x20 || (0x7F...0x9F).contains($0.value) || CharacterSet.newlines.contains($0) }) else { return nil }
        var chunks: [[UInt16]] = []
        var current: [UInt16] = []
        // Keep complete grapheme clusters (including emoji and combining marks).
        for character in text {
            let units = Array(String(character).utf16)
            guard units.count <= 20 else { return nil }
            if current.count + units.count > 20 { chunks.append(current); current = [] }
            current.append(contentsOf: units)
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
