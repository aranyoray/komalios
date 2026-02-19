import Foundation

struct RetentionState: Codable {
    var lastActiveDate: Date?
    var currentStreak: Int
    var longestStreak: Int
    var totalDaysActive: Int
    var lastMorningAnchor: String? // "yyyy-MM-dd"
    var lastEveningAnchor: String? // "yyyy-MM-dd"
    var preferredCharacterId: Int?
    var hasSeenReconnectionFlow: Bool
    var reconnectionCount: Int
    var morningAnchorEnabled: Bool
    var eveningAnchorEnabled: Bool
    var promptsShownThisSession: Int

    // Advanced engagement metrics
    var voluntaryReturnCount: Int
    var pushNotificationReturnCount: Int
    var reflectionDepthScores: [Double]
    var childInitiatedSessionCount: Int
    var parentViewCount: Int
    var lastParentViewDate: Date?

    // Computed metrics
    var voluntaryReturnRate: Double {
        let total = voluntaryReturnCount + pushNotificationReturnCount
        guard total > 0 else { return 0 }
        return Double(voluntaryReturnCount) / Double(total)
    }

    var averageReflectionDepth: Double {
        guard !reflectionDepthScores.isEmpty else { return 0 }
        return reflectionDepthScores.reduce(0, +) / Double(reflectionDepthScores.count)
    }

    var parentConversationRate: Double {
        guard childInitiatedSessionCount > 0 else { return 0 }
        return Double(parentViewCount) / Double(childInitiatedSessionCount)
    }

    static let `default` = RetentionState(
        lastActiveDate: nil,
        currentStreak: 0,
        longestStreak: 0,
        totalDaysActive: 0,
        lastMorningAnchor: nil,
        lastEveningAnchor: nil,
        preferredCharacterId: nil,
        hasSeenReconnectionFlow: false,
        reconnectionCount: 0,
        morningAnchorEnabled: true,
        eveningAnchorEnabled: true,
        promptsShownThisSession: 0,
        voluntaryReturnCount: 0,
        pushNotificationReturnCount: 0,
        reflectionDepthScores: [],
        childInitiatedSessionCount: 0,
        parentViewCount: 0,
        lastParentViewDate: nil
    )
}
