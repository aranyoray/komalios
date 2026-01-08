//
//  ContentCategory.swift
//  Komal - Age-Appropriate Content Filtering
//
//  Production-ready implementation with all 6 category groups
//

import Foundation

/// Content categories for filtering
enum ContentCategory: String, CaseIterable, Codable {
    // 1. Violence & Disturbing Content
    case graphicViolence = "graphic_violence"
    case nonGraphicViolence = "non_graphic_violence"
    case heavyFighting = "heavy_fighting"
    case horror = "horror"
    case crimeNews = "crime_news"

    // 2. Explicit & Body-Related Content
    case explicitSexual = "explicit_sexual"
    case sexualEducation = "sexual_education"
    case erotica = "erotica"
    case indecentClothing = "indecent_clothing"
    case bodyModification = "body_modification"
    case beautyFilters = "beauty_filters"

    // 3. Substances & Addictive Behavior
    case alcohol = "alcohol"
    case drugs = "drugs"
    case cigarettes = "cigarettes"
    case gambling = "gambling"
    case lootBoxes = "loot_boxes"

    // 4. Parasocial & Manipulative Content
    case parasocialDependency = "parasocial_dependency"
    case creatorPressure = "creator_pressure"
    case donationFarming = "donation_farming"
    case aiFriends = "ai_friends"

    // 5. Self-Optimization & Body Anxiety
    case looksmaxxing = "looksmaxxing"
    case dietCulture = "diet_culture"
    case steroids = "steroids"
    case glowUpPressure = "glow_up_pressure"

    // 6. Financial & Commercial Content
    case crypto = "crypto"
    case getRichQuick = "get_rich_quick"
    case influencerFinance = "influencer_finance"
    case subscriptionPages = "subscription_pages"

    // 7. Media & Platform-Native Risks
    case shortFormVideos = "short_form_videos"
    case liveStreams = "live_streams"
    case gamingContent = "gaming_content"
    case aiGeneratedContent = "ai_generated_content"

    // 8. Social & Cultural Topics
    case lgbtqContent = "lgbtq_content"
    case religion = "religion"
    case immigration = "immigration"
    case communism = "communism"
    case discriminationHate = "discrimination_hate"
    case gunsWeapons = "guns_weapons"
    case extremistOrgs = "extremist_orgs"

    var displayName: String {
        switch self {
        case .graphicViolence: return "Graphic Violence"
        case .nonGraphicViolence: return "Non-Graphic Violence"
        case .heavyFighting: return "Heavy Fighting"
        case .horror: return "Horror/Paranormal"
        case .crimeNews: return "Crime/News"
        case .explicitSexual: return "Explicit Sexual Content"
        case .sexualEducation: return "Sexual Education"
        case .erotica: return "Erotica"
        case .indecentClothing: return "Indecent Clothing"
        case .bodyModification: return "Body Modification"
        case .beautyFilters: return "Beauty Filters"
        case .alcohol: return "Alcohol"
        case .drugs: return "Drugs"
        case .cigarettes: return "Cigarettes/Vaping"
        case .gambling: return "Gambling/Betting"
        case .lootBoxes: return "Loot Boxes/Gacha"
        case .parasocialDependency: return "Parasocial Content"
        case .creatorPressure: return "Creator Pressure"
        case .donationFarming: return "Donation Farming"
        case .aiFriends: return "AI Friends/Relationships"
        case .looksmaxxing: return "Looksmaxxing"
        case .dietCulture: return "Diet Culture"
        case .steroids: return "Steroids/Supplements"
        case .glowUpPressure: return "Glow-Up Pressure"
        case .crypto: return "Cryptocurrency"
        case .getRichQuick: return "Get-Rich-Quick Schemes"
        case .influencerFinance: return "Influencer Finance"
        case .subscriptionPages: return "Subscription Pages"
        case .shortFormVideos: return "Short-Form Videos"
        case .liveStreams: return "Live Streams"
        case .gamingContent: return "Gaming Content"
        case .aiGeneratedContent: return "AI-Generated Content"
        case .lgbtqContent: return "LGBTQ+ Topics"
        case .religion: return "Religious Content"
        case .immigration: return "Immigration Topics"
        case .communism: return "Communism/Political Ideology"
        case .discriminationHate: return "Discrimination/Hate Speech"
        case .gunsWeapons: return "Guns/Weapons"
        case .extremistOrgs: return "Extremist Organizations"
        }
    }

    var icon: String {
        switch self {
        case .graphicViolence, .nonGraphicViolence, .heavyFighting: return "⚔️"
        case .horror: return "👻"
        case .crimeNews: return "🚨"
        case .explicitSexual, .erotica: return "🔞"
        case .sexualEducation: return "📚"
        case .indecentClothing: return "👕"
        case .bodyModification: return "💉"
        case .beautyFilters: return "✨"
        case .alcohol: return "🍺"
        case .drugs: return "💊"
        case .cigarettes: return "🚬"
        case .gambling, .lootBoxes: return "🎰"
        case .parasocialDependency, .creatorPressure, .donationFarming: return "📺"
        case .aiFriends: return "🤖"
        case .looksmaxxing, .dietCulture, .glowUpPressure: return "💪"
        case .steroids: return "💉"
        case .crypto: return "₿"
        case .getRichQuick, .influencerFinance: return "💰"
        case .subscriptionPages: return "💳"
        case .shortFormVideos: return "📱"
        case .liveStreams: return "🔴"
        case .gamingContent: return "🎮"
        case .aiGeneratedContent: return "🤖"
        case .lgbtqContent: return "🏳️‍🌈"
        case .religion: return "🕊️"
        case .immigration: return "🌍"
        case .communism: return "🚩"
        case .discriminationHate: return "⚠️"
        case .gunsWeapons: return "🔫"
        case .extremistOrgs: return "🚫"
        }
    }
}

enum FilterAction: String, Codable {
    case allow, gate, block
}

enum AgeGroup: Int {
    case under10 = 10, age10to13 = 13, age13to16 = 16, age16plus = 18
    static func from(age: Int) -> AgeGroup {
        if age < 10 { return .under10 }
        else if age < 13 { return .age10to13 }
        else if age < 16 { return .age13to16 }
        else { return .age16plus }
    }
}

struct DetectionResult: Codable {
    let category: ContentCategory
    let confidence: Double
    let isEducational: Bool
    let context: String?
}

struct FilterDecision: Codable {
    let action: FilterAction
    let categories: [ContentCategory]
    let reason: String
    let isEducational: Bool
    let requiresParentApproval: Bool
}

struct BlockedAttempt: Codable, Identifiable {
    let id: UUID
    let url: String
    let timestamp: Date
    let childAge: Int
    let categories: [ContentCategory]
    let action: FilterAction
    let wasApproved: Bool?
}
