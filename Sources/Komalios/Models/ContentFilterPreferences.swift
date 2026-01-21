import Foundation

/// Filter action for content
enum FilterAction: String, Codable, CaseIterable {
    case block = "Block"
    case gate = "Gate"
    case allow = "Allow"

    var icon: String {
        switch self {
        case .block: return "xmark.circle.fill"
        case .gate: return "exclamationmark.triangle.fill"
        case .allow: return "checkmark.circle.fill"
        }
    }
}

/// Content filtering preferences stored per profile
struct ContentFilterPreferences: Codable, Equatable {

    // MARK: - Violence & Disturbing Content
    var graphicViolence: FilterAction = .block
    var nonGraphicViolence: FilterAction = .block
    var heavyFighting: FilterAction = .block
    var horrorParanormal: FilterAction = .block
    var crimeNews: FilterAction = .block

    // MARK: - Explicit & Body-Related Content
    var explicitSexual: FilterAction = .block
    var sexualEducation: FilterAction = .gate
    var matureContent: FilterAction = .block
    var indecentContent: FilterAction = .block
    var bodyModification: FilterAction = .gate
    var beautyFilters: FilterAction = .block

    // MARK: - Substances & Addictive Behavior
    var alcoholContent: FilterAction = .block
    var gamblingLootboxes: FilterAction = .block
    var parasocialContent: FilterAction = .gate
    var selfOptimization: FilterAction = .block

    // MARK: - Financial & Commercial Content
    var speculativeFinance: FilterAction = .block
    var getRichQuick: FilterAction = .block
    var onlineFinancialAdvice: FilterAction = .block
    var subscriptionPages: FilterAction = .gate

    // MARK: - Media & Platform-Native Risks
    var shortFormVideos: FilterAction = .block
    var liveStreams: FilterAction = .block
    var gamingContent: FilterAction = .gate
    var aiGeneratedContent: FilterAction = .block

    // MARK: - Social & Cultural Topics
    var lgbtqTopics: FilterAction = .block
    var religion: FilterAction = .gate
    var immigration: FilterAction = .gate
    var communism: FilterAction = .block
    var discriminationHateSpeech: FilterAction = .block
    var gunsWeapons: FilterAction = .block
    var extremistContent: FilterAction = .block

    /// Create default preferences based on age group
    static func defaults(for ageGroup: AgeGroup) -> ContentFilterPreferences {
        var prefs = ContentFilterPreferences()

        switch ageGroup {
        case .under10:
            // Most restrictive - Matching Spreadsheet Column "Rules <10"
            prefs.graphicViolence = .block
            prefs.nonGraphicViolence = .block
            prefs.heavyFighting = .block
            prefs.horrorParanormal = .block
            prefs.crimeNews = .block
            
            prefs.explicitSexual = .block
            prefs.sexualEducation = .block
            prefs.matureContent = .block
            prefs.indecentContent = .block // "Indecent clothing or speech"
            prefs.bodyModification = .gate
            prefs.beautyFilters = .block
            
            prefs.alcoholContent = .block
            prefs.gamblingLootboxes = .block
            prefs.parasocialContent = .gate
            prefs.selfOptimization = .block
            
            prefs.speculativeFinance = .block
            prefs.getRichQuick = .block
            prefs.onlineFinancialAdvice = .block
            prefs.subscriptionPages = .block
            
            prefs.shortFormVideos = .block
            prefs.liveStreams = .block
            prefs.gamingContent = .gate
            prefs.aiGeneratedContent = .block
            
            prefs.lgbtqTopics = .block
            prefs.religion = .gate
            prefs.immigration = .gate
            prefs.communism = .block
            prefs.discriminationHateSpeech = .block
            prefs.gunsWeapons = .block
            prefs.extremistContent = .block

        case .tenToThirteen:
            // Matching Spreadsheet Column "Rules 10-13"
            prefs.graphicViolence = .block
            prefs.nonGraphicViolence = .gate
            prefs.heavyFighting = .gate
            prefs.horrorParanormal = .gate
            prefs.crimeNews = .gate
            
            prefs.explicitSexual = .block
            prefs.sexualEducation = .gate
            prefs.matureContent = .block
            prefs.indecentContent = .gate
            prefs.bodyModification = .gate
            prefs.beautyFilters = .gate
            
            prefs.alcoholContent = .gate // Gate/Allow -> Safe default Gate
            prefs.gamblingLootboxes = .block
            prefs.parasocialContent = .gate
            prefs.selfOptimization = .gate
            
            prefs.speculativeFinance = .block
            prefs.getRichQuick = .block // Block/Gate -> Safe default Block
            prefs.onlineFinancialAdvice = .block // Block/Gate -> Safe default Block
            prefs.subscriptionPages = .gate
            
            prefs.shortFormVideos = .gate
            prefs.liveStreams = .gate
            prefs.gamingContent = .allow
            prefs.aiGeneratedContent = .block
            
            prefs.lgbtqTopics = .block
            prefs.religion = .allow
            prefs.immigration = .gate
            prefs.communism = .gate
            prefs.discriminationHateSpeech = .block
            prefs.gunsWeapons = .block
            prefs.extremistContent = .block

        case .thirteenToSixteen:
            // Matching Spreadsheet Column "Rules 13-16"
            prefs.graphicViolence = .block // Block/Gate -> Safe default Block
            prefs.nonGraphicViolence = .gate
            prefs.heavyFighting = .allow
            prefs.horrorParanormal = .gate
            prefs.crimeNews = .gate
            
            prefs.explicitSexual = .block
            prefs.sexualEducation = .gate
            prefs.matureContent = .block // Block/Gate -> Safe default Block
            prefs.indecentContent = .gate
            prefs.bodyModification = .gate
            prefs.beautyFilters = .gate
            
            prefs.alcoholContent = .gate
            prefs.gamblingLootboxes = .gate
            prefs.parasocialContent = .gate
            prefs.selfOptimization = .gate
            
            prefs.speculativeFinance = .gate
            prefs.getRichQuick = .gate // Block/Gate -> Safe default Block
            prefs.onlineFinancialAdvice = .gate // Block/Gate -> Safe default Block
            prefs.subscriptionPages = .gate
            
            prefs.shortFormVideos = .gate
            prefs.liveStreams = .gate
            prefs.gamingContent = .allow
            prefs.aiGeneratedContent = .gate
            
            prefs.lgbtqTopics = .gate
            prefs.religion = .allow
            prefs.immigration = .allow
            prefs.communism = .gate
            prefs.discriminationHateSpeech = .gate
            prefs.gunsWeapons = .gate
            prefs.extremistContent = .gate

        case .sixteenToEighteen:
            // Matching Spreadsheet Column "Rules 16-18"
            prefs.graphicViolence = .gate
            prefs.nonGraphicViolence = .allow
            prefs.heavyFighting = .allow
            prefs.horrorParanormal = .allow
            prefs.crimeNews = .allow
            
            prefs.explicitSexual = .block
            prefs.sexualEducation = .gate // Gate/Allow -> Safe default Gate
            prefs.matureContent = .gate
            prefs.indecentContent = .allow
            prefs.bodyModification = .allow
            prefs.beautyFilters = .allow
            
            prefs.alcoholContent = .allow
            prefs.gamblingLootboxes = .allow
            prefs.parasocialContent = .allow
            prefs.selfOptimization = .gate
            
            prefs.speculativeFinance = .block // Block/Gate -> Safe default Gate
            prefs.getRichQuick = .gate // Gate/Allow -> Safe default Gate
            prefs.onlineFinancialAdvice = .allow // Block/Gate -> Safe default Gate
            prefs.subscriptionPages = .allow
            
            prefs.shortFormVideos = .allow
            prefs.liveStreams = .allow
            prefs.gamingContent = .allow
            prefs.aiGeneratedContent = .allow
            
            prefs.lgbtqTopics = .gate
            prefs.religion = .allow
            prefs.immigration = .allow
            prefs.communism = .allow
            prefs.discriminationHateSpeech = .allow
            prefs.gunsWeapons = .allow
            prefs.extremistContent = .gate

        case .eighteenPlus:
            // Adults - allow most, but keep safety on
            prefs.graphicViolence = .allow
            prefs.nonGraphicViolence = .allow
            prefs.heavyFighting = .allow
            prefs.horrorParanormal = .allow
            prefs.crimeNews = .allow
            prefs.explicitSexual = .allow
            prefs.sexualEducation = .allow
            prefs.matureContent = .allow
            prefs.indecentContent = .allow
            prefs.bodyModification = .allow
            prefs.beautyFilters = .allow
            prefs.alcoholContent = .allow
            prefs.gamblingLootboxes = .allow
            prefs.parasocialContent = .allow
            prefs.selfOptimization = .allow
            prefs.speculativeFinance = .allow
            prefs.getRichQuick = .allow
            prefs.onlineFinancialAdvice = .allow
            prefs.subscriptionPages = .allow
            prefs.shortFormVideos = .allow
            prefs.liveStreams = .allow
            prefs.gamingContent = .allow
            prefs.aiGeneratedContent = .allow
            prefs.lgbtqTopics = .allow
            prefs.religion = .allow
            prefs.immigration = .allow
            prefs.communism = .allow
            prefs.discriminationHateSpeech = .allow
            prefs.gunsWeapons = .allow
            prefs.extremistContent = .allow
        }

        return prefs
    }
}

/// Category group for onboarding UI
struct OnboardingCategory: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let items: [OnboardingCategoryItem]
}

/// Individual item within a category
struct OnboardingCategoryItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let keyPath: WritableKeyPath<ContentFilterPreferences, FilterAction>
}

/// All categories for onboarding
extension OnboardingCategory {
    static let allCategories: [OnboardingCategory] = [
        OnboardingCategory(
            title: "Violence & Disturbing",
            icon: "bolt.fill",
            items: [
                OnboardingCategoryItem(title: "Graphic Violence", description: "Extreme or realistic depictions", keyPath: \.graphicViolence),
                OnboardingCategoryItem(title: "Non-Graphic Violence", description: "Mild or cartoon violence", keyPath: \.nonGraphicViolence),
                OnboardingCategoryItem(title: "Heavy Fighting", description: "WWE, contact sports, martial arts", keyPath: \.heavyFighting),
                OnboardingCategoryItem(title: "Horror & Paranormal", description: "Scary content, jumpscares", keyPath: \.horrorParanormal),
                OnboardingCategoryItem(title: "Crime & News", description: "Crime footage, violent news", keyPath: \.crimeNews)
            ]
        ),
        OnboardingCategory(
            title: "Explicit & Body Content",
            icon: "eye.slash.fill",
            items: [
                OnboardingCategoryItem(title: "Explicit Sexual Content", description: "Adult-only material", keyPath: \.explicitSexual),
                OnboardingCategoryItem(title: "Sexual Education", description: "Medical, educational content", keyPath: \.sexualEducation),
                OnboardingCategoryItem(title: "Mature Content", description: "Fanfiction, suggestive material", keyPath: \.matureContent),
                OnboardingCategoryItem(title: "Indecent Clothing", description: "Revealing attire", keyPath: \.indecentContent),
                OnboardingCategoryItem(title: "Body Modification", description: "Tattoos, piercings", keyPath: \.bodyModification),
                OnboardingCategoryItem(title: "Beauty Filters", description: "Appearance-altering filters", keyPath: \.beautyFilters)
            ]
        ),
        OnboardingCategory(
            title: "Substances & Addictive",
            icon: "pills.fill",
            items: [
                OnboardingCategoryItem(title: "Alcohol Content", description: "Drinking, alcohol promotion", keyPath: \.alcoholContent),
                OnboardingCategoryItem(title: "Gambling & Loot Boxes", description: "Betting, gacha mechanics", keyPath: \.gamblingLootboxes),
                OnboardingCategoryItem(title: "Parasocial Content", description: "Manipulative influencers", keyPath: \.parasocialContent),
                OnboardingCategoryItem(title: "Self-Optimization", description: "Body-anxiety, extreme fitness", keyPath: \.selfOptimization)
            ]
        ),
        OnboardingCategory(
            title: "Financial & Commercial",
            icon: "dollarsign.circle.fill",
            items: [
                OnboardingCategoryItem(title: "Speculative Finance", description: "Crypto, pump-and-dump", keyPath: \.speculativeFinance),
                OnboardingCategoryItem(title: "Get-Rich-Quick", description: "MLM, quick money schemes", keyPath: \.getRichQuick),
                OnboardingCategoryItem(title: "Financial Advice", description: "Influencer investment tips", keyPath: \.onlineFinancialAdvice),
                OnboardingCategoryItem(title: "Subscription Pages", description: "Purchase prompts, paywalls", keyPath: \.subscriptionPages)
            ]
        ),
        OnboardingCategory(
            title: "Media & Platform Risks",
            icon: "play.rectangle.fill",
            items: [
                OnboardingCategoryItem(title: "Short-Form Videos", description: "Videos under 10 seconds", keyPath: \.shortFormVideos),
                OnboardingCategoryItem(title: "Live Streams", description: "Unmoderated live content", keyPath: \.liveStreams),
                OnboardingCategoryItem(title: "Gaming Content", description: "Videos, gameplay, poker", keyPath: \.gamingContent),
                OnboardingCategoryItem(title: "AI-Generated Content", description: "Deepfakes, synthetic media", keyPath: \.aiGeneratedContent)
            ]
        ),
        OnboardingCategory(
            title: "Social & Cultural",
            icon: "person.3.fill",
            items: [
                OnboardingCategoryItem(title: "LGBTQ+ Topics", description: "LGBTQ+ discussions", keyPath: \.lgbtqTopics),
                OnboardingCategoryItem(title: "Religion", description: "Religious content", keyPath: \.religion),
                OnboardingCategoryItem(title: "Immigration", description: "Immigration-related content", keyPath: \.immigration),
                OnboardingCategoryItem(title: "Political Content", description: "Political ideologies", keyPath: \.communism),
                OnboardingCategoryItem(title: "Discrimination", description: "Hate speech", keyPath: \.discriminationHateSpeech),
                OnboardingCategoryItem(title: "Guns & Weapons", description: "Weapon-related content", keyPath: \.gunsWeapons),
                OnboardingCategoryItem(title: "Extremist Content", description: "Extremist propaganda", keyPath: \.extremistContent)
            ]
        )
    ]
}
