#if os(iOS)
import Foundation

// MARK: - Curriculum Models

/// A social circle context for a session
enum SELSocialCircle: String, Codable {
    case closeFamily
    case friends
    case acquaintances
    case publicServices
    case strangers
}

/// A single step in a curriculum session: avatar speaks, child participates, goals are assessed
struct SELCurriculumStep: Codable, Identifiable {
    let id: String
    let avatarDialogue: String
    let participationPrompt: String
    let responseOptions: [SELResponseOption] // pre-defined choices
    let allowsFreeText: Bool // whether child can also type/speak
    let targetGoals: [String] // SEL goal descriptions
    let targetDomains: [SELDomain] // domains assessed by this step
    let expectedKeywords: [String] // keywords for ML matching in free-text
}

/// A pre-defined response option the child can tap
struct SELResponseOption: Codable, Identifiable {
    let id: String
    let text: String
    let emoji: String
    let qualityScore: Int // 1=emerging, 2=developing, 3=proficient
}

/// A full curriculum session with theme, social circle, and ordered steps
struct SELCurriculumSession: Codable, Identifiable {
    let id: String
    let sessionNumber: Int
    let theme: String
    let socialCircle: SELSocialCircle
    let emoji: String
    let steps: [SELCurriculumStep]
}

/// Tracks which sessions/steps a child has completed
struct SELCurriculumProgress: Codable {
    var completedSessionIds: [String] = []
    var currentSessionId: String?
    var currentStepIndex: Int = 0
    var stepScores: [String: SELStepScore] = [:] // stepId -> score

    var nextSessionNumber: Int {
        completedSessionIds.count + 1
    }
}

struct SELStepScore: Codable {
    let stepId: String
    let selectedOptionScore: Int // from response option
    let mlSentimentScore: Double // -1 to 1
    let mlRelevanceScore: Double // 0 to 1 (keyword/semantic match)
    let compositeDomainScores: [SELDomain: Int] // derived per-domain 0-100
}

// MARK: - Curriculum Data (from sample_params.csv)

struct SELCurriculumLibrary {
    /// Computed to react to language changes via LanguageManager
    static var sessions: [SELCurriculumSession] {
        [session1, session2, session3, session4, session5]
    }

    static func session(forNumber n: Int) -> SELCurriculumSession? {
        sessions.first { $0.sessionNumber == n }
    }

    private static func l(_ key: String) -> String { LanguageManager.localized(key) }

    /// Split a comma-separated localized keyword string into an array
    private static func keywords(_ key: String) -> [String] {
        l(key).components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Session 1: Introduction at Avatar's House

    private static var session1: SELCurriculumSession {
        SELCurriculumSession(
            id: "curriculum-s1",
            sessionNumber: 1,
            theme: l("curriculum.s1.theme"),
            socialCircle: .closeFamily,
            emoji: "\u{1F3E0}",
            steps: [
                SELCurriculumStep(
                    id: "s1-1",
                    avatarDialogue: l("curriculum.s1.step1.dialogue"),
                    participationPrompt: l("curriculum.s1.step1.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s1-1a", text: "I like playing games, reading books, and being with my family!", emoji: "\u{1F3AE}", qualityScore: 3),
                        SELResponseOption(id: "s1-1b", text: "I'm nice and I like stuff.", emoji: "\u{1F642}", qualityScore: 2),
                        SELResponseOption(id: "s1-1c", text: "I don't know...", emoji: "\u{1F937}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Basic conversation skills"],
                    targetDomains: [.socialCommunication, .languageDevelopment],
                    expectedKeywords: keywords("curriculum.s1.step1.keywords")
                ),
                SELCurriculumStep(
                    id: "s1-2",
                    avatarDialogue: l("curriculum.s1.step2.dialogue"),
                    participationPrompt: l("curriculum.s1.step2.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s1-2a", text: "I also love drawing! And I like playing outside too!", emoji: "\u{1F3A8}", qualityScore: 3),
                        SELResponseOption(id: "s1-2b", text: "I like watching videos.", emoji: "\u{1F4F1}", qualityScore: 2),
                        SELResponseOption(id: "s1-2c", text: "Nothing really.", emoji: "\u{1F610}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Positive Peer Interaction", "Finding common interests"],
                    targetDomains: [.socialCommunication, .emotionalIntelligence],
                    expectedKeywords: keywords("curriculum.s1.step2.keywords")
                ),
                SELCurriculumStep(
                    id: "s1-3",
                    avatarDialogue: l("curriculum.s1.step3.dialogue"),
                    participationPrompt: l("curriculum.s1.step3.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s1-3a", text: "Yes! I have a brother and we play together. We go to the park with our parents!", emoji: "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}", qualityScore: 3),
                        SELResponseOption(id: "s1-3b", text: "I have a sister.", emoji: "\u{1F467}", qualityScore: 2),
                        SELResponseOption(id: "s1-3c", text: "I don't want to talk about it.", emoji: "\u{1F614}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Building a rapport"],
                    targetDomains: [.socialCommunication, .languageDevelopment, .emotionalIntelligence],
                    expectedKeywords: keywords("curriculum.s1.step3.keywords")
                ),
                SELCurriculumStep(
                    id: "s1-4",
                    avatarDialogue: l("curriculum.s1.step4.dialogue"),
                    participationPrompt: l("curriculum.s1.step4.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s1-4a", text: "Let's dance! I'm feeling happy and excited!", emoji: "\u{1F483}", qualityScore: 3),
                        SELResponseOption(id: "s1-4b", text: "I'll sing along! This is fun.", emoji: "\u{1F3B5}", qualityScore: 3),
                        SELResponseOption(id: "s1-4c", text: "I'm feeling okay, this was nice.", emoji: "\u{1F60A}", qualityScore: 2),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Recognition of emotions", "Building a rapport"],
                    targetDomains: [.emotionalIntelligence, .socialCommunication],
                    expectedKeywords: keywords("curriculum.s1.step4.keywords")
                ),
            ]
        )
    }

    // MARK: - Session 2: Birthday Party

    private static var session2: SELCurriculumSession {
        SELCurriculumSession(
            id: "curriculum-s2",
            sessionNumber: 2,
            theme: l("curriculum.s2.theme"),
            socialCircle: .friends,
            emoji: "\u{1F382}",
            steps: [
                SELCurriculumStep(
                    id: "s2-1",
                    avatarDialogue: l("curriculum.s2.step1.dialogue"),
                    participationPrompt: l("curriculum.s2.step1.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s2-1a", text: "My best friend is Sam! We met at school and we love building things and playing tag.", emoji: "\u{1F91D}", qualityScore: 3),
                        SELResponseOption(id: "s2-1b", text: "I have friends at school.", emoji: "\u{1F3EB}", qualityScore: 2),
                        SELResponseOption(id: "s2-1c", text: "I don't have many friends.", emoji: "\u{1F615}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Create Baseline for Rules of Interaction with social circle"],
                    targetDomains: [.socialCommunication, .languageDevelopment],
                    expectedKeywords: keywords("curriculum.s2.step1.keywords")
                ),
                SELCurriculumStep(
                    id: "s2-2",
                    avatarDialogue: l("curriculum.s2.step2.dialogue"),
                    participationPrompt: l("curriculum.s2.step2.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s2-2a", text: "Since she loves painting and animals, maybe an art set with animal stickers!", emoji: "\u{1F381}", qualityScore: 3),
                        SELResponseOption(id: "s2-2b", text: "Get her a toy.", emoji: "\u{1F9F8}", qualityScore: 2),
                        SELResponseOption(id: "s2-2c", text: "I don't know what to get.", emoji: "\u{1F937}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Theory of mind"],
                    targetDomains: [.cognitiveDevelopment, .emotionalIntelligence],
                    expectedKeywords: keywords("curriculum.s2.step2.keywords")
                ),
                SELCurriculumStep(
                    id: "s2-3",
                    avatarDialogue: l("curriculum.s2.step3.dialogue"),
                    participationPrompt: l("curriculum.s2.step3.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s2-3a", text: "Happy Birthday! You're an amazing friend and I love spending time with you!", emoji: "\u{1F48C}", qualityScore: 3),
                        SELResponseOption(id: "s2-3b", text: "Happy Birthday! Have a good day!", emoji: "\u{1F389}", qualityScore: 2),
                        SELResponseOption(id: "s2-3c", text: "Happy Birthday.", emoji: "\u{1F382}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Meaningful Communication", "Emotions"],
                    targetDomains: [.emotionalIntelligence, .languageDevelopment],
                    expectedKeywords: keywords("curriculum.s2.step3.keywords")
                ),
                SELCurriculumStep(
                    id: "s2-4",
                    avatarDialogue: l("curriculum.s2.step4.dialogue"),
                    participationPrompt: l("curriculum.s2.step4.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s2-4a", text: "Hi everyone! I'd wave, smile, and say hello to each person!", emoji: "\u{1F44B}", qualityScore: 3),
                        SELResponseOption(id: "s2-4b", text: "I'd say hi to the people I know.", emoji: "\u{1F642}", qualityScore: 2),
                        SELResponseOption(id: "s2-4c", text: "I'd just find a quiet spot.", emoji: "\u{1FA91}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Rules of interaction with social circle"],
                    targetDomains: [.socialCommunication, .lifeSkills],
                    expectedKeywords: keywords("curriculum.s2.step4.keywords")
                ),
                SELCurriculumStep(
                    id: "s2-5",
                    avatarDialogue: l("curriculum.s2.step5.dialogue"),
                    participationPrompt: l("curriculum.s2.step5.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s2-5a", text: "I'd go sit with her and say 'I'm sorry that happened. Do you want to play with me instead? You're really important to me.'", emoji: "\u{1F49B}", qualityScore: 3),
                        SELResponseOption(id: "s2-5b", text: "I'd tell her it's okay and she can play next time.", emoji: "\u{1F64F}", qualityScore: 2),
                        SELResponseOption(id: "s2-5c", text: "I don't know what to say.", emoji: "\u{1F636}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Dealing with a negative emotion: sadness", "Meaningful conversation"],
                    targetDomains: [.emotionalIntelligence, .socialCommunication],
                    expectedKeywords: keywords("curriculum.s2.step5.keywords")
                ),
            ]
        )
    }

    // MARK: - Session 3: Grocery Store

    private static var session3: SELCurriculumSession {
        SELCurriculumSession(
            id: "curriculum-s3",
            sessionNumber: 3,
            theme: l("curriculum.s3.theme"),
            socialCircle: .acquaintances,
            emoji: "\u{1F6D2}",
            steps: [
                SELCurriculumStep(
                    id: "s3-1",
                    avatarDialogue: l("curriculum.s3.step1.dialogue"),
                    participationPrompt: l("curriculum.s3.step1.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s3-1a", text: "Take deep breaths first! Then make a list of what you need so you have a plan.", emoji: "\u{1F4DD}", qualityScore: 3),
                        SELResponseOption(id: "s3-1b", text: "Just go with someone you trust.", emoji: "\u{1F91D}", qualityScore: 2),
                        SELResponseOption(id: "s3-1c", text: "I'd be scared too.", emoji: "\u{1F630}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Identifying negative feeling", "Dealing with a negative emotion: anxiety"],
                    targetDomains: [.emotionalIntelligence, .cognitiveDevelopment],
                    expectedKeywords: keywords("curriculum.s3.step1.keywords")
                ),
                SELCurriculumStep(
                    id: "s3-2",
                    avatarDialogue: l("curriculum.s3.step2.dialogue"),
                    participationPrompt: l("curriculum.s3.step2.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s3-2a", text: "Let's group them! Dairy section for milk and cheese, bakery for bread, fruits for apples. That way we don't go back and forth!", emoji: "\u{1F4CB}", qualityScore: 3),
                        SELResponseOption(id: "s3-2b", text: "Just follow the list in order.", emoji: "\u{2705}", qualityScore: 2),
                        SELResponseOption(id: "s3-2c", text: "I don't know how to organize a list.", emoji: "\u{1F914}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Planning - Cognitive Skills"],
                    targetDomains: [.cognitiveDevelopment, .lifeSkills],
                    expectedKeywords: keywords("curriculum.s3.step2.keywords")
                ),
                SELCurriculumStep(
                    id: "s3-3",
                    avatarDialogue: l("curriculum.s3.step3.dialogue"),
                    participationPrompt: l("curriculum.s3.step3.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s3-3a", text: "Shopping bags so we don't waste plastic, the shopping list, money or a card, and maybe a mask!", emoji: "\u{1F6CD}", qualityScore: 3),
                        SELResponseOption(id: "s3-3b", text: "Money and bags.", emoji: "\u{1F4B0}", qualityScore: 2),
                        SELResponseOption(id: "s3-3c", text: "Just go!", emoji: "\u{1F3C3}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Planning - Cognitive Skills"],
                    targetDomains: [.cognitiveDevelopment, .lifeSkills],
                    expectedKeywords: keywords("curriculum.s3.step3.keywords")
                ),
                SELCurriculumStep(
                    id: "s3-4",
                    avatarDialogue: l("curriculum.s3.step4.dialogue"),
                    participationPrompt: l("curriculum.s3.step4.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s3-4a", text: "Excuse me, could you please help me find where the cheese is? Thank you so much!", emoji: "\u{1F5E3}", qualityScore: 3),
                        SELResponseOption(id: "s3-4b", text: "Where's the cheese?", emoji: "\u{1F9C0}", qualityScore: 2),
                        SELResponseOption(id: "s3-4c", text: "I'd rather keep looking myself.", emoji: "\u{1F440}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Rules of interaction with staff"],
                    targetDomains: [.socialCommunication, .lifeSkills],
                    expectedKeywords: keywords("curriculum.s3.step4.keywords")
                ),
                SELCurriculumStep(
                    id: "s3-5",
                    avatarDialogue: l("curriculum.s3.step5.dialogue"),
                    participationPrompt: l("curriculum.s3.step5.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s3-5a", text: "You should get $7.50 back! And yes, let's help Mrs. Johnson carry her bags \u{2014} it's kind to help our neighbors!", emoji: "\u{1F49B}", qualityScore: 3),
                        SELResponseOption(id: "s3-5b", text: "Some change back. And we could say hi to her.", emoji: "\u{1F44B}", qualityScore: 2),
                        SELResponseOption(id: "s3-5c", text: "I'm not sure about the change.", emoji: "\u{1F937}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Rules of interaction at a grocery store", "Money concepts", "Rules of interaction with social circle"],
                    targetDomains: [.cognitiveDevelopment, .lifeSkills, .socialCommunication],
                    expectedKeywords: keywords("curriculum.s3.step5.keywords")
                ),
            ]
        )
    }

    // MARK: - Session 4: Doctor Visit

    private static var session4: SELCurriculumSession {
        SELCurriculumSession(
            id: "curriculum-s4",
            sessionNumber: 4,
            theme: l("curriculum.s4.theme"),
            socialCircle: .publicServices,
            emoji: "\u{1F3E5}",
            steps: [
                SELCurriculumStep(
                    id: "s4-1",
                    avatarDialogue: l("curriculum.s4.step1.dialogue"),
                    participationPrompt: l("curriculum.s4.step1.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s4-1a", text: "Oh no! What happened? Where exactly does it hurt? When did it start hurting? Did you eat something bad?", emoji: "\u{1FA7A}", qualityScore: 3),
                        SELResponseOption(id: "s4-1b", text: "Are you okay? Does your stomach hurt?", emoji: "\u{1F61F}", qualityScore: 2),
                        SELResponseOption(id: "s4-1c", text: "That's not good.", emoji: "\u{1F62C}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Dealing with a negative emotion: pain", "Meaningful conversation"],
                    targetDomains: [.emotionalIntelligence, .socialCommunication, .languageDevelopment],
                    expectedKeywords: keywords("curriculum.s4.step1.keywords")
                ),
                SELCurriculumStep(
                    id: "s4-2",
                    avatarDialogue: l("curriculum.s4.step2.dialogue"),
                    participationPrompt: l("curriculum.s4.step2.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s4-2a", text: "Get some rest and lie down. Maybe drink some water. If it doesn't get better, we should tell your mom and go to a doctor!", emoji: "\u{1F48A}", qualityScore: 3),
                        SELResponseOption(id: "s4-2b", text: "Maybe take some medicine and rest.", emoji: "\u{1F6CF}", qualityScore: 2),
                        SELResponseOption(id: "s4-2c", text: "Just wait and see.", emoji: "\u{23F3}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Essential Life skills", "Meaningful conversation", "Planning (Cognitive Functioning)"],
                    targetDomains: [.lifeSkills, .cognitiveDevelopment, .socialCommunication],
                    expectedKeywords: keywords("curriculum.s4.step2.keywords")
                ),
                SELCurriculumStep(
                    id: "s4-3",
                    avatarDialogue: l("curriculum.s4.step3.dialogue"),
                    participationPrompt: l("curriculum.s4.step3.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s4-3a", text: "First, find a nearby clinic. Then call them and say it's an emergency. Ask what times are available and pick one we can make!", emoji: "\u{1F4DE}", qualityScore: 3),
                        SELResponseOption(id: "s4-3b", text: "Call the doctor and ask to come in.", emoji: "\u{1F3E5}", qualityScore: 2),
                        SELResponseOption(id: "s4-3c", text: "My mom usually does that.", emoji: "\u{1F469}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Essential Life skills", "Planning (Cognitive Functioning)"],
                    targetDomains: [.lifeSkills, .cognitiveDevelopment],
                    expectedKeywords: keywords("curriculum.s4.step3.keywords")
                ),
                SELCurriculumStep(
                    id: "s4-4",
                    avatarDialogue: l("curriculum.s4.step4.dialogue"),
                    participationPrompt: l("curriculum.s4.step4.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s4-4a", text: "First you check in at reception, then wait your turn. The nurse will check your temperature. The doctor will help you feel better \u{2014} being brave means telling them exactly how you feel!", emoji: "\u{1F4AA}", qualityScore: 3),
                        SELResponseOption(id: "s4-4b", text: "Just listen to what the doctor says.", emoji: "\u{1F442}", qualityScore: 2),
                        SELResponseOption(id: "s4-4c", text: "I don't like going to the doctor either.", emoji: "\u{1F630}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Essential Life skills", "Meaningful conversation", "Planning (Cognitive Functioning)"],
                    targetDomains: [.lifeSkills, .cognitiveDevelopment, .emotionalIntelligence],
                    expectedKeywords: keywords("curriculum.s4.step4.keywords")
                ),
                SELCurriculumStep(
                    id: "s4-5",
                    avatarDialogue: l("curriculum.s4.step5.dialogue"),
                    participationPrompt: l("curriculum.s4.step5.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s4-5a", text: "Get well soon! I'll stay with you and we can watch something together. You'll be back to playing in no time!", emoji: "\u{1F308}", qualityScore: 3),
                        SELResponseOption(id: "s4-5b", text: "Get well soon! Rest up.", emoji: "\u{1F490}", qualityScore: 2),
                        SELResponseOption(id: "s4-5c", text: "Hope you feel better.", emoji: "\u{1F642}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Dealing with negative emotion", "Meaningful conversation", "Staying healthy"],
                    targetDomains: [.emotionalIntelligence, .socialCommunication, .lifeSkills],
                    expectedKeywords: keywords("curriculum.s4.step5.keywords")
                ),
            ]
        )
    }

    // MARK: - Session 5: Lost in a Park

    private static var session5: SELCurriculumSession {
        SELCurriculumSession(
            id: "curriculum-s5",
            sessionNumber: 5,
            theme: l("curriculum.s5.theme"),
            socialCircle: .strangers,
            emoji: "\u{1F333}",
            steps: [
                SELCurriculumStep(
                    id: "s5-1",
                    avatarDialogue: l("curriculum.s5.step1.dialogue"),
                    participationPrompt: l("curriculum.s5.step1.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s5-1a", text: "Check the weather first! Since it's sunny, going to the park would be great. We can always do the puzzle when it rains!", emoji: "\u{2600}\u{FE0F}", qualityScore: 3),
                        SELResponseOption(id: "s5-1b", text: "Go outside since it's nice out.", emoji: "\u{1F6B6}", qualityScore: 2),
                        SELResponseOption(id: "s5-1c", text: "I don't know, both are fine.", emoji: "\u{1F937}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Planning: Cognitive Skills"],
                    targetDomains: [.cognitiveDevelopment],
                    expectedKeywords: keywords("curriculum.s5.step1.keywords")
                ),
                SELCurriculumStep(
                    id: "s5-2",
                    avatarDialogue: l("curriculum.s5.step2.dialogue"),
                    participationPrompt: l("curriculum.s5.step2.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s5-2a", text: "I'd walk up and say 'Hi! Are you looking for something? I know this park well \u{2014} maybe I can help you find your way!'", emoji: "\u{1F5FA}", qualityScore: 3),
                        SELResponseOption(id: "s5-2b", text: "I'd point him to the information board.", emoji: "\u{1F4CC}", qualityScore: 2),
                        SELResponseOption(id: "s5-2c", text: "I'd keep walking.", emoji: "\u{1F6B6}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Create Baseline for Rules of Interaction with social circle"],
                    targetDomains: [.socialCommunication, .lifeSkills],
                    expectedKeywords: keywords("curriculum.s5.step2.keywords")
                ),
                SELCurriculumStep(
                    id: "s5-3",
                    avatarDialogue: l("curriculum.s5.step3.dialogue"),
                    participationPrompt: l("curriculum.s5.step3.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s5-3a", text: "Take a deep breath! It's okay to feel frustrated. Maybe try a new flavor at the short line \u{2014} you might discover something you love even more!", emoji: "\u{1F366}", qualityScore: 3),
                        SELResponseOption(id: "s5-3b", text: "Just wait in the long line.", emoji: "\u{23F0}", qualityScore: 2),
                        SELResponseOption(id: "s5-3c", text: "Forget the ice cream.", emoji: "\u{1F624}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Planning - Cognitive Skills", "Dealing with a negative emotion: Frustration"],
                    targetDomains: [.emotionalIntelligence, .cognitiveDevelopment],
                    expectedKeywords: keywords("curriculum.s5.step3.keywords")
                ),
                SELCurriculumStep(
                    id: "s5-4",
                    avatarDialogue: l("curriculum.s5.step4.dialogue"),
                    participationPrompt: l("curriculum.s5.step4.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s5-4a", text: "Don't go with a stranger! Stay calm, stay where you are, and look for a police officer or a park worker in uniform. They are safe people to ask for help!", emoji: "\u{1F694}", qualityScore: 3),
                        SELResponseOption(id: "s5-4b", text: "Say no to the stranger and try to find the exit.", emoji: "\u{1F6AB}", qualityScore: 2),
                        SELResponseOption(id: "s5-4c", text: "Maybe the stranger is nice?", emoji: "\u{1F914}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Essential Life skills", "Meaningful conversation", "Rules of interaction with a stranger"],
                    targetDomains: [.lifeSkills, .socialCommunication, .emotionalIntelligence],
                    expectedKeywords: keywords("curriculum.s5.step4.keywords")
                ),
                SELCurriculumStep(
                    id: "s5-5",
                    avatarDialogue: l("curriculum.s5.step5.dialogue"),
                    participationPrompt: l("curriculum.s5.step5.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s5-5a", text: "Tell her your name, your parent's name, their phone number, and your home address. She can call your parent to come pick you up!", emoji: "\u{1F4F1}", qualityScore: 3),
                        SELResponseOption(id: "s5-5b", text: "Tell her my name and where I live.", emoji: "\u{1F3E0}", qualityScore: 2),
                        SELResponseOption(id: "s5-5c", text: "I don't know what to say.", emoji: "\u{1F61F}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Essential Life skills", "Meaningful conversation", "Planning (Cognitive Functioning)"],
                    targetDomains: [.lifeSkills, .cognitiveDevelopment, .socialCommunication],
                    expectedKeywords: keywords("curriculum.s5.step5.keywords")
                ),
                SELCurriculumStep(
                    id: "s5-6",
                    avatarDialogue: l("curriculum.s5.step6.dialogue"),
                    participationPrompt: l("curriculum.s5.step6.prompt"),
                    responseOptions: [
                        SELResponseOption(id: "s5-6a", text: "I learned to stay calm when scared, never go with strangers, and always ask a police officer or someone in uniform for help!", emoji: "\u{2B50}", qualityScore: 3),
                        SELResponseOption(id: "s5-6b", text: "Don't go with strangers and ask for help.", emoji: "\u{1F31F}", qualityScore: 2),
                        SELResponseOption(id: "s5-6c", text: "It was a fun adventure!", emoji: "\u{1F60A}", qualityScore: 1),
                    ],
                    allowsFreeText: true,
                    targetGoals: ["Rapport building", "Reflection"],
                    targetDomains: [.emotionalIntelligence, .cognitiveDevelopment, .lifeSkills],
                    expectedKeywords: keywords("curriculum.s5.step6.keywords")
                ),
            ]
        )
    }
}
#endif
