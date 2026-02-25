#if os(iOS)
import Foundation

// MARK: - Subscription Plan

enum SubscriptionPlan: String, Codable, CaseIterable, Identifiable {
    case essentials
    case grow
    case thrive

    var id: String { rawValue }

    var productID: String? {
        switch self {
        case .essentials: return nil
        case .grow: return "grow_month_999"
        case .thrive: return "thrive_monthly_1449"
        }
    }

    var displayName: String {
        switch self {
        case .essentials: return "Essentials"
        case .grow: return "Grow"
        case .thrive: return "Thrive"
        }
    }

    var tagline: String {
        switch self {
        case .essentials: return "Perfect for getting started"
        case .grow: return "Built for growing families"
        case .thrive: return "Premium individual plan"
        }
    }

    var features: [String] {
        switch self {
        case .essentials:
            return [
                "Core learning & SEL foundations",
                "On-device content adaptation",
                "Weekly snapshot",
                "Privacy-first design"
            ]
        case .grow:
            return [
                "Everything in Essentials, plus:",
                "Personalized content recommendations",
                "Progress insights & analytics",
                "Shareable reports for caregivers",
                "Priority support"
            ]
        case .thrive:
            return [
                "Everything in Grow, plus:",
                "Parent insights dashboard",
                "SEL reporting & milestones",
                "Engagement trend analysis",
                "Early support indicators",
                "Multi-device & family sharing"
            ]
        }
    }

    var maxChildProfiles: Int? {
        switch self {
        case .essentials: return 2
        case .grow: return nil
        case .thrive: return nil
        }
    }

    var accentColor: String {
        switch self {
        case .essentials: return "pearlAqua"
        case .grow: return "lavenderPurple"
        case .thrive: return "bubblegumPink"
        }
    }
}

// MARK: - Subscription State

struct SubscriptionState: Codable {
    var currentPlan: SubscriptionPlan = .essentials
    var purchasedProductID: String?
    var expirationDate: Date?

    var isSubscriptionActive: Bool {
        guard currentPlan != .essentials else { return true }
        guard let expiration = expirationDate else { return false }
        return expiration > Date()
    }
}
#endif
