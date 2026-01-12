import Foundation

struct BlocklistEntry: Decodable {
    struct MatchRule: Decodable {
        var hostContains: [String]?
        var pathContains: [String]?
        var queryContains: [String]?
    }

    var category: String
    var reason: String
    var match: MatchRule
}

struct BlocklistPayload: Decodable {
    var version: String
    var entries: [BlocklistEntry]
}

struct BlocklistMatch {
    let category: String
    let reason: String
}

final class BlocklistService {
    static let shared = BlocklistService()

    private(set) var payload: BlocklistPayload

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "Blocklists", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(BlocklistPayload.self, from: data) {
            self.payload = decoded
        } else {
            self.payload = BlocklistPayload(version: "local", entries: [])
        }
    }

    func match(url: URL) -> BlocklistMatch? {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        let query = url.query?.lowercased() ?? ""

        for entry in payload.entries {
            let hostMatch = entry.match.hostContains?.contains(where: { host.contains($0.lowercased()) }) ?? false
            let pathMatch = entry.match.pathContains?.contains(where: { path.contains($0.lowercased()) }) ?? false
            let queryMatch = entry.match.queryContains?.contains(where: { query.contains($0.lowercased()) }) ?? false

            if hostMatch || pathMatch || queryMatch {
                return BlocklistMatch(category: entry.category, reason: entry.reason)
            }
        }

        return nil
    }
}
