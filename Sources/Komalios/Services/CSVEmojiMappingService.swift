#if os(iOS)
import Foundation

final class CSVEmojiMappingService {
    static let shared = CSVEmojiMappingService()

    struct CategoryMapping {
        let category: String
        let subcategory: String
        let emojis: [String]
        let keywords: [String]
    }

    private var mappings: [CategoryMapping] = []
    private let defaultEmojis = ["😊", "🤔", "😟", "😢", "👍"]

    private init() {
        loadCSV()
    }

    private func loadCSV() {
        guard let url = Bundle.main.url(forResource: "Komal_Models_Masterlist", withExtension: "csv"),
              let data = try? String(contentsOf: url, encoding: .utf8) else { return }

        let lines = data.components(separatedBy: "\n")
        guard lines.count > 1 else { return }

        // Skip header row
        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let fields = parseCSVLine(line)
            // We need at least 8 columns: Category, Subcategory, Emojis, ..., Tokenized_subcategory_keywords_context (col 7)
            guard fields.count >= 8 else { continue }

            let category = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let subcategory = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let emojisRaw = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let keywordsRaw = fields[7].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !subcategory.isEmpty, !emojisRaw.isEmpty else { continue }

            let emojis = emojisRaw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            let keywords = keywordsRaw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }

            mappings.append(CategoryMapping(
                category: category,
                subcategory: subcategory,
                emojis: emojis,
                keywords: keywords
            ))
        }
    }

    /// Parse a CSV line handling quoted fields (commas inside quotes)
    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }

    /// Lookup emojis for a subcategory with cascading fallback:
    /// exact subcategory match -> substring match -> keyword match -> category match -> default
    func emojisForSubcategory(_ sub: String) -> [String] {
        let lowered = sub.lowercased()
        guard !lowered.isEmpty else { return defaultEmojis }

        // 1. Exact subcategory match (case-insensitive)
        if let match = mappings.first(where: { $0.subcategory.lowercased() == lowered }) {
            return match.emojis.isEmpty ? defaultEmojis : match.emojis
        }

        // 2. Substring match on subcategory
        if let match = mappings.first(where: { $0.subcategory.lowercased().contains(lowered) || lowered.contains($0.subcategory.lowercased()) }) {
            return match.emojis.isEmpty ? defaultEmojis : match.emojis
        }

        // 3. Keyword match
        if let match = mappings.first(where: { mapping in
            mapping.keywords.contains(where: { lowered.contains($0) || $0.contains(lowered) })
        }) {
            return match.emojis.isEmpty ? defaultEmojis : match.emojis
        }

        // 4. Category match
        if let match = mappings.first(where: { lowered.contains($0.category.lowercased()) || $0.category.lowercased().contains(lowered) }) {
            return match.emojis.isEmpty ? defaultEmojis : match.emojis
        }

        return defaultEmojis
    }
}
#endif
