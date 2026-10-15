import Foundation

enum ExpenseTags {
    static func normalize(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.split(separator: ",").map {
            $0.precomposedStringWithCanonicalMapping.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ").lowercased()
        }.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    static func isValid(_ tags: [String]) -> Bool {
        tags.count <= 10 && tags.allSatisfy { $0.unicodeScalars.count <= 30 && !$0.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) } }
    }
}
