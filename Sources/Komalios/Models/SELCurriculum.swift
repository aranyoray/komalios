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
    static let sessions: [SELCurriculumSession] = [
        session1, session2, session3, session4, session5
    ]

    static func session(forNumber n: Int) -> SELCurriculumSession? {
        sessions.first { $0.sessionNumber == n }
    }

    // MARK: - Session 1: Introduction at Avatar's House

    private static let session1 = SELCurriculumSession(
        id: "curriculum-s1",
        sessionNumber: 1,
        theme: "Introduction at Avatar's House",
        socialCircle: .closeFamily,
        emoji: "🏠",
        steps: [
            SELCurriculumStep(
                id: "s1-1",
                avatarDialogue: "Hi there! Welcome to my house! Let me tell you about myself. I love exploring, I'm really curious about everything, and I always try to be a good friend!",
                participationPrompt: "Now it's your turn! Tell me three things about yourself.",
                responseOptions: [
                    SELResponseOption(id: "s1-1a", text: "I like playing games, reading books, and being with my family!", emoji: "🎮", qualityScore: 3),
                    SELResponseOption(id: "s1-1b", text: "I'm nice and I like stuff.", emoji: "🙂", qualityScore: 2),
                    SELResponseOption(id: "s1-1c", text: "I don't know...", emoji: "🤷", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Basic conversation skills"],
                targetDomains: [.socialCommunication, .languageDevelopment],
                expectedKeywords: ["like", "love", "enjoy", "play", "friend", "family", "hobby", "favorite"]
            ),
            SELCurriculumStep(
                id: "s1-2",
                avatarDialogue: "In my free time, I love drawing pictures, playing in the garden, and reading adventure stories! What about you?",
                participationPrompt: "What do you like to do in your free time? Let's see if we have anything in common!",
                responseOptions: [
                    SELResponseOption(id: "s1-2a", text: "I also love drawing! And I like playing outside too!", emoji: "🎨", qualityScore: 3),
                    SELResponseOption(id: "s1-2b", text: "I like watching videos.", emoji: "📱", qualityScore: 2),
                    SELResponseOption(id: "s1-2c", text: "Nothing really.", emoji: "😐", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Positive Peer Interaction", "Finding common interests"],
                targetDomains: [.socialCommunication, .emotionalIntelligence],
                expectedKeywords: ["draw", "play", "read", "game", "outside", "sport", "music", "art", "same", "too", "also"]
            ),
            SELCurriculumStep(
                id: "s1-3",
                avatarDialogue: "Let me tell you about my family! I have a mom, a dad, and a little sister. We love cooking together and going to the park on weekends!",
                participationPrompt: "Do you have siblings? What do you like doing with your family?",
                responseOptions: [
                    SELResponseOption(id: "s1-3a", text: "Yes! I have a brother and we play together. We go to the park with our parents!", emoji: "👨‍👩‍👧‍👦", qualityScore: 3),
                    SELResponseOption(id: "s1-3b", text: "I have a sister.", emoji: "👧", qualityScore: 2),
                    SELResponseOption(id: "s1-3c", text: "I don't want to talk about it.", emoji: "😔", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Building a rapport"],
                targetDomains: [.socialCommunication, .languageDevelopment, .emotionalIntelligence],
                expectedKeywords: ["brother", "sister", "mom", "dad", "family", "pet", "together", "play", "cook", "park", "love"]
            ),
            SELCurriculumStep(
                id: "s1-4",
                avatarDialogue: "That was so fun getting to know you! Let's do something fun together — how about a little dance-off or sing-along?",
                participationPrompt: "Pick an activity! How are you feeling right now?",
                responseOptions: [
                    SELResponseOption(id: "s1-4a", text: "Let's dance! I'm feeling happy and excited!", emoji: "💃", qualityScore: 3),
                    SELResponseOption(id: "s1-4b", text: "I'll sing along! This is fun.", emoji: "🎵", qualityScore: 3),
                    SELResponseOption(id: "s1-4c", text: "I'm feeling okay, this was nice.", emoji: "😊", qualityScore: 2),
                ],
                allowsFreeText: true,
                targetGoals: ["Recognition of emotions", "Building a rapport"],
                targetDomains: [.emotionalIntelligence, .socialCommunication],
                expectedKeywords: ["happy", "excited", "fun", "dance", "sing", "good", "great", "enjoy", "like"]
            ),
        ]
    )

    // MARK: - Session 2: Birthday Party

    private static let session2 = SELCurriculumSession(
        id: "curriculum-s2",
        sessionNumber: 2,
        theme: "Avatar Goes to a Birthday Party",
        socialCircle: .friends,
        emoji: "🎂",
        steps: [
            SELCurriculumStep(
                id: "s2-1",
                avatarDialogue: "Guess what? My friend is having a birthday party today! I'm so excited to see my friends Alex, Bella, and Charlie. We met at school and love playing together!",
                participationPrompt: "Tell me about 2 or 3 of your friends! How did you meet them and what do you like doing together?",
                responseOptions: [
                    SELResponseOption(id: "s2-1a", text: "My best friend is Sam! We met at school and we love building things and playing tag.", emoji: "🤝", qualityScore: 3),
                    SELResponseOption(id: "s2-1b", text: "I have friends at school.", emoji: "🏫", qualityScore: 2),
                    SELResponseOption(id: "s2-1c", text: "I don't have many friends.", emoji: "😕", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Create Baseline for Rules of Interaction with social circle"],
                targetDomains: [.socialCommunication, .languageDevelopment],
                expectedKeywords: ["friend", "met", "school", "play", "together", "like", "fun", "class", "neighbor"]
            ),
            SELCurriculumStep(
                id: "s2-2",
                avatarDialogue: "I need help choosing a birthday present for my friend! She really loves painting and animals. What kind of gift should I get her?",
                participationPrompt: "Think about what your friend likes. What gift would make them really happy?",
                responseOptions: [
                    SELResponseOption(id: "s2-2a", text: "Since she loves painting and animals, maybe an art set with animal stickers!", emoji: "🎁", qualityScore: 3),
                    SELResponseOption(id: "s2-2b", text: "Get her a toy.", emoji: "🧸", qualityScore: 2),
                    SELResponseOption(id: "s2-2c", text: "I don't know what to get.", emoji: "🤷", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Theory of mind"],
                targetDomains: [.cognitiveDevelopment, .emotionalIntelligence],
                expectedKeywords: ["like", "loves", "paint", "animal", "art", "gift", "happy", "interest", "enjoy", "think", "feel"]
            ),
            SELCurriculumStep(
                id: "s2-3",
                avatarDialogue: "Now I want to make a birthday card! I want to write something really nice so my friend knows how much I care. Can you help me?",
                participationPrompt: "How can we express our feelings towards our friends? What would you write on the card?",
                responseOptions: [
                    SELResponseOption(id: "s2-3a", text: "Happy Birthday! You're an amazing friend and I love spending time with you!", emoji: "💌", qualityScore: 3),
                    SELResponseOption(id: "s2-3b", text: "Happy Birthday! Have a good day!", emoji: "🎉", qualityScore: 2),
                    SELResponseOption(id: "s2-3c", text: "Happy Birthday.", emoji: "🎂", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Meaningful Communication", "Emotions"],
                targetDomains: [.emotionalIntelligence, .languageDevelopment],
                expectedKeywords: ["happy", "birthday", "friend", "love", "care", "special", "amazing", "wonderful", "best", "wish"]
            ),
            SELCurriculumStep(
                id: "s2-4",
                avatarDialogue: "We're at the party now! There are so many people. I see some kids I know and some I don't. How should I greet everyone?",
                participationPrompt: "How would you greet people at a party? Show me!",
                responseOptions: [
                    SELResponseOption(id: "s2-4a", text: "Hi everyone! I'd wave, smile, and say hello to each person!", emoji: "👋", qualityScore: 3),
                    SELResponseOption(id: "s2-4b", text: "I'd say hi to the people I know.", emoji: "🙂", qualityScore: 2),
                    SELResponseOption(id: "s2-4c", text: "I'd just find a quiet spot.", emoji: "🪑", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Rules of interaction with social circle"],
                targetDomains: [.socialCommunication, .lifeSkills],
                expectedKeywords: ["hello", "hi", "wave", "smile", "greet", "introduce", "name", "nice", "meet"]
            ),
            SELCurriculumStep(
                id: "s2-5",
                avatarDialogue: "Oh no... I see my friend sitting alone in the corner. She looks really sad because the other kids didn't pick her for the relay race. She was left out.",
                participationPrompt: "How can we console someone who is feeling left out and sad? What would you say to her?",
                responseOptions: [
                    SELResponseOption(id: "s2-5a", text: "I'd go sit with her and say 'I'm sorry that happened. Do you want to play with me instead? You're really important to me.'", emoji: "💛", qualityScore: 3),
                    SELResponseOption(id: "s2-5b", text: "I'd tell her it's okay and she can play next time.", emoji: "🙏", qualityScore: 2),
                    SELResponseOption(id: "s2-5c", text: "I don't know what to say.", emoji: "😶", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Dealing with a negative emotion: sadness", "Meaningful conversation"],
                targetDomains: [.emotionalIntelligence, .socialCommunication],
                expectedKeywords: ["sorry", "sad", "feel", "play", "together", "friend", "okay", "help", "care", "understand", "left out", "console"]
            ),
        ]
    )

    // MARK: - Session 3: Grocery Store

    private static let session3 = SELCurriculumSession(
        id: "curriculum-s3",
        sessionNumber: 3,
        theme: "Avatar Goes to a Grocery Store",
        socialCircle: .acquaintances,
        emoji: "🛒",
        steps: [
            SELCurriculumStep(
                id: "s3-1",
                avatarDialogue: "I have to go to the supermarket today and I'm feeling a bit overwhelmed. It's so big and crowded! My heart is beating fast...",
                participationPrompt: "How can we be better prepared for situations that make us nervous, like going shopping?",
                responseOptions: [
                    SELResponseOption(id: "s3-1a", text: "Take deep breaths first! Then make a list of what you need so you have a plan.", emoji: "📝", qualityScore: 3),
                    SELResponseOption(id: "s3-1b", text: "Just go with someone you trust.", emoji: "🤝", qualityScore: 2),
                    SELResponseOption(id: "s3-1c", text: "I'd be scared too.", emoji: "😰", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Identifying negative feeling", "Dealing with a negative emotion: anxiety"],
                targetDomains: [.emotionalIntelligence, .cognitiveDevelopment],
                expectedKeywords: ["breathe", "calm", "list", "plan", "prepare", "relax", "okay", "deep breath", "help", "ready"]
            ),
            SELCurriculumStep(
                id: "s3-2",
                avatarDialogue: "Good idea! Let me make a shopping list. I need milk, bread, apples, and cheese. Can you help me organize my list?",
                participationPrompt: "Help me organize! What else might we need, and what order should we get things?",
                responseOptions: [
                    SELResponseOption(id: "s3-2a", text: "Let's group them! Dairy section for milk and cheese, bakery for bread, fruits for apples. That way we don't go back and forth!", emoji: "📋", qualityScore: 3),
                    SELResponseOption(id: "s3-2b", text: "Just follow the list in order.", emoji: "✅", qualityScore: 2),
                    SELResponseOption(id: "s3-2c", text: "I don't know how to organize a list.", emoji: "🤔", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Planning - Cognitive Skills"],
                targetDomains: [.cognitiveDevelopment, .lifeSkills],
                expectedKeywords: ["group", "section", "first", "then", "aisle", "order", "organize", "dairy", "fruit", "bread", "plan"]
            ),
            SELCurriculumStep(
                id: "s3-3",
                avatarDialogue: "Before we leave, what do we need to bring? I have my list ready but I feel like I'm forgetting something important...",
                participationPrompt: "What should we bring when going shopping? Think of everything we might need!",
                responseOptions: [
                    SELResponseOption(id: "s3-3a", text: "Shopping bags so we don't waste plastic, the shopping list, money or a card, and maybe a mask!", emoji: "🛍", qualityScore: 3),
                    SELResponseOption(id: "s3-3b", text: "Money and bags.", emoji: "💰", qualityScore: 2),
                    SELResponseOption(id: "s3-3c", text: "Just go!", emoji: "🏃", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Planning - Cognitive Skills"],
                targetDomains: [.cognitiveDevelopment, .lifeSkills],
                expectedKeywords: ["bag", "money", "list", "mask", "card", "wallet", "prepare", "bring", "need"]
            ),
            SELCurriculumStep(
                id: "s3-4",
                avatarDialogue: "I'm at the store but I can't find the cheese anywhere! I've been walking around and I'm getting frustrated. Should I ask someone for help?",
                participationPrompt: "How should we ask the store staff for help? What's a polite way to talk to them?",
                responseOptions: [
                    SELResponseOption(id: "s3-4a", text: "Excuse me, could you please help me find where the cheese is? Thank you so much!", emoji: "🗣", qualityScore: 3),
                    SELResponseOption(id: "s3-4b", text: "Where's the cheese?", emoji: "🧀", qualityScore: 2),
                    SELResponseOption(id: "s3-4c", text: "I'd rather keep looking myself.", emoji: "👀", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Rules of interaction with staff"],
                targetDomains: [.socialCommunication, .lifeSkills],
                expectedKeywords: ["excuse", "please", "help", "find", "thank", "polite", "ask", "sir", "ma'am"]
            ),
            SELCurriculumStep(
                id: "s3-5",
                avatarDialogue: "Time to pay! The total is $12.50 and I have a $20 bill. Also, on the way out, I see our elderly neighbor Mrs. Johnson struggling with her bags.",
                participationPrompt: "How much change should I get back? And should we help Mrs. Johnson?",
                responseOptions: [
                    SELResponseOption(id: "s3-5a", text: "You should get $7.50 back! And yes, let's help Mrs. Johnson carry her bags — it's kind to help our neighbors!", emoji: "💛", qualityScore: 3),
                    SELResponseOption(id: "s3-5b", text: "Some change back. And we could say hi to her.", emoji: "👋", qualityScore: 2),
                    SELResponseOption(id: "s3-5c", text: "I'm not sure about the change.", emoji: "🤷", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Rules of interaction at a grocery store", "Money concepts", "Rules of interaction with social circle"],
                targetDomains: [.cognitiveDevelopment, .lifeSkills, .socialCommunication],
                expectedKeywords: ["change", "7.50", "help", "carry", "bags", "kind", "neighbor", "assist", "offer"]
            ),
        ]
    )

    // MARK: - Session 4: Doctor Visit

    private static let session4 = SELCurriculumSession(
        id: "curriculum-s4",
        sessionNumber: 4,
        theme: "Avatar Goes to the Doctor",
        socialCircle: .publicServices,
        emoji: "🏥",
        steps: [
            SELCurriculumStep(
                id: "s4-1",
                avatarDialogue: "Ohhh... I'm not feeling well at all. My stomach really hurts and I can barely stand up. I feel miserable...",
                participationPrompt: "Your friend isn't feeling well! What questions would you ask to understand what's wrong?",
                responseOptions: [
                    SELResponseOption(id: "s4-1a", text: "Oh no! What happened? Where exactly does it hurt? When did it start hurting? Did you eat something bad?", emoji: "🩺", qualityScore: 3),
                    SELResponseOption(id: "s4-1b", text: "Are you okay? Does your stomach hurt?", emoji: "😟", qualityScore: 2),
                    SELResponseOption(id: "s4-1c", text: "That's not good.", emoji: "😬", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Dealing with a negative emotion: pain", "Meaningful conversation"],
                targetDomains: [.emotionalIntelligence, .socialCommunication, .languageDevelopment],
                expectedKeywords: ["what", "where", "hurt", "when", "how", "feel", "happened", "wrong", "pain", "sick"]
            ),
            SELCurriculumStep(
                id: "s4-2",
                avatarDialogue: "My stomach hurts so much I can't do my homework or even play. I just want to lie down but nothing is helping...",
                participationPrompt: "How can we help someone who is sick? What should we suggest?",
                responseOptions: [
                    SELResponseOption(id: "s4-2a", text: "Get some rest and lie down. Maybe drink some water. If it doesn't get better, we should tell your mom and go to a doctor!", emoji: "💊", qualityScore: 3),
                    SELResponseOption(id: "s4-2b", text: "Maybe take some medicine and rest.", emoji: "🛏", qualityScore: 2),
                    SELResponseOption(id: "s4-2c", text: "Just wait and see.", emoji: "⏳", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Essential Life skills", "Meaningful conversation", "Planning (Cognitive Functioning)"],
                targetDomains: [.lifeSkills, .cognitiveDevelopment, .socialCommunication],
                expectedKeywords: ["rest", "lie down", "water", "medicine", "doctor", "parent", "mom", "dad", "help", "call"]
            ),
            SELCurriculumStep(
                id: "s4-3",
                avatarDialogue: "My mom says we need to see a doctor. But I've never made an appointment before! How do we do this?",
                participationPrompt: "Help me make a doctor's appointment! What steps should we follow?",
                responseOptions: [
                    SELResponseOption(id: "s4-3a", text: "First, find a nearby clinic. Then call them and say it's an emergency. Ask what times are available and pick one we can make!", emoji: "📞", qualityScore: 3),
                    SELResponseOption(id: "s4-3b", text: "Call the doctor and ask to come in.", emoji: "🏥", qualityScore: 2),
                    SELResponseOption(id: "s4-3c", text: "My mom usually does that.", emoji: "👩", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Essential Life skills", "Planning (Cognitive Functioning)"],
                targetDomains: [.lifeSkills, .cognitiveDevelopment],
                expectedKeywords: ["call", "clinic", "appointment", "time", "emergency", "available", "nearby", "phone", "schedule"]
            ),
            SELCurriculumStep(
                id: "s4-4",
                avatarDialogue: "We're at the clinic now! There's a reception desk, a waiting area, and I can see nurses walking around. The doctor wants to examine me. I'm a little nervous...",
                participationPrompt: "What happens at a clinic? How can we be brave at the doctor's?",
                responseOptions: [
                    SELResponseOption(id: "s4-4a", text: "First you check in at reception, then wait your turn. The nurse will check your temperature. The doctor will help you feel better — being brave means telling them exactly how you feel!", emoji: "💪", qualityScore: 3),
                    SELResponseOption(id: "s4-4b", text: "Just listen to what the doctor says.", emoji: "👂", qualityScore: 2),
                    SELResponseOption(id: "s4-4c", text: "I don't like going to the doctor either.", emoji: "😰", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Essential Life skills", "Meaningful conversation", "Planning (Cognitive Functioning)"],
                targetDomains: [.lifeSkills, .cognitiveDevelopment, .emotionalIntelligence],
                expectedKeywords: ["reception", "wait", "nurse", "doctor", "brave", "tell", "check", "temperature", "examine", "help"]
            ),
            SELCurriculumStep(
                id: "s4-5",
                avatarDialogue: "The doctor gave me medicine and said I need to rest. I'm back home now and feeling tired. My brother is eating a delicious burger but the doctor said I should eat light food...",
                participationPrompt: "What can we say to make our friend feel better while they're resting and recovering?",
                responseOptions: [
                    SELResponseOption(id: "s4-5a", text: "Get well soon! I'll stay with you and we can watch something together. You'll be back to playing in no time!", emoji: "🌈", qualityScore: 3),
                    SELResponseOption(id: "s4-5b", text: "Get well soon! Rest up.", emoji: "💐", qualityScore: 2),
                    SELResponseOption(id: "s4-5c", text: "Hope you feel better.", emoji: "🙂", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Dealing with negative emotion", "Meaningful conversation", "Staying healthy"],
                targetDomains: [.emotionalIntelligence, .socialCommunication, .lifeSkills],
                expectedKeywords: ["well", "soon", "better", "rest", "help", "stay", "care", "company", "recover", "healthy"]
            ),
        ]
    )

    // MARK: - Session 5: Lost in a Park

    private static let session5 = SELCurriculumSession(
        id: "curriculum-s5",
        sessionNumber: 5,
        theme: "Avatar Gets Lost in a Park",
        socialCircle: .strangers,
        emoji: "🌳",
        steps: [
            SELCurriculumStep(
                id: "s5-1",
                avatarDialogue: "It's the weekend! I'm trying to decide what to do. It's sunny outside but I also have a new puzzle at home. What should I do?",
                participationPrompt: "What goes into making a good decision? How would you decide what to do on a weekend?",
                responseOptions: [
                    SELResponseOption(id: "s5-1a", text: "Check the weather first! Since it's sunny, going to the park would be great. We can always do the puzzle when it rains!", emoji: "☀️", qualityScore: 3),
                    SELResponseOption(id: "s5-1b", text: "Go outside since it's nice out.", emoji: "🚶", qualityScore: 2),
                    SELResponseOption(id: "s5-1c", text: "I don't know, both are fine.", emoji: "🤷", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Planning: Cognitive Skills"],
                targetDomains: [.cognitiveDevelopment],
                expectedKeywords: ["weather", "sunny", "outside", "decide", "plan", "think", "choose", "option", "because", "reason"]
            ),
            SELCurriculumStep(
                id: "s5-2",
                avatarDialogue: "I'm at the park and I see a boy with a big backpack and a map. He looks a bit confused and keeps looking around. I think he might be a tourist!",
                participationPrompt: "How can the avatar help this tourist find his way? What would you do?",
                responseOptions: [
                    SELResponseOption(id: "s5-2a", text: "I'd walk up and say 'Hi! Are you looking for something? I know this park well — maybe I can help you find your way!'", emoji: "🗺", qualityScore: 3),
                    SELResponseOption(id: "s5-2b", text: "I'd point him to the information board.", emoji: "📌", qualityScore: 2),
                    SELResponseOption(id: "s5-2c", text: "I'd keep walking.", emoji: "🚶", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Create Baseline for Rules of Interaction with social circle"],
                targetDomains: [.socialCommunication, .lifeSkills],
                expectedKeywords: ["help", "ask", "lost", "way", "map", "direction", "show", "kind", "offer", "guide"]
            ),
            SELCurriculumStep(
                id: "s5-3",
                avatarDialogue: "Mmm, I really want ice cream! But one stall has a huge line and the other one doesn't have my favorite flavor. Ugh, this is so frustrating!",
                participationPrompt: "How can the avatar calm down when feeling frustrated? How would you make a decision here?",
                responseOptions: [
                    SELResponseOption(id: "s5-3a", text: "Take a deep breath! It's okay to feel frustrated. Maybe try a new flavor at the short line — you might discover something you love even more!", emoji: "🍦", qualityScore: 3),
                    SELResponseOption(id: "s5-3b", text: "Just wait in the long line.", emoji: "⏰", qualityScore: 2),
                    SELResponseOption(id: "s5-3c", text: "Forget the ice cream.", emoji: "😤", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Planning - Cognitive Skills", "Dealing with a negative emotion: Frustration"],
                targetDomains: [.emotionalIntelligence, .cognitiveDevelopment],
                expectedKeywords: ["breath", "calm", "try", "new", "decide", "wait", "patient", "frustrat", "okay", "choose", "option"]
            ),
            SELCurriculumStep(
                id: "s5-4",
                avatarDialogue: "Oh no... I was walking around and now I can't find my way back! I don't recognize this part of the park at all. I'm starting to panic! A stranger just came up and offered to help me...",
                participationPrompt: "Should the avatar go with the stranger? What should they do instead to stay safe?",
                responseOptions: [
                    SELResponseOption(id: "s5-4a", text: "Don't go with a stranger! Stay calm, stay where you are, and look for a police officer or a park worker in uniform. They are safe people to ask for help!", emoji: "🚔", qualityScore: 3),
                    SELResponseOption(id: "s5-4b", text: "Say no to the stranger and try to find the exit.", emoji: "🚫", qualityScore: 2),
                    SELResponseOption(id: "s5-4c", text: "Maybe the stranger is nice?", emoji: "🤔", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Essential Life skills", "Meaningful conversation", "Rules of interaction with a stranger"],
                targetDomains: [.lifeSkills, .socialCommunication, .emotionalIntelligence],
                expectedKeywords: ["no", "stranger", "police", "safe", "stay", "officer", "uniform", "calm", "parent", "call", "don't go", "danger"]
            ),
            SELCurriculumStep(
                id: "s5-5",
                avatarDialogue: "I found a police officer! She's very kind and wants to help me get home safely. What information should I tell her?",
                participationPrompt: "What important information should we share with the officer to get help? Think about what they need to know!",
                responseOptions: [
                    SELResponseOption(id: "s5-5a", text: "Tell her your name, your parent's name, their phone number, and your home address. She can call your parent to come pick you up!", emoji: "📱", qualityScore: 3),
                    SELResponseOption(id: "s5-5b", text: "Tell her my name and where I live.", emoji: "🏠", qualityScore: 2),
                    SELResponseOption(id: "s5-5c", text: "I don't know what to say.", emoji: "😟", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Essential Life skills", "Meaningful conversation", "Planning (Cognitive Functioning)"],
                targetDomains: [.lifeSkills, .cognitiveDevelopment, .socialCommunication],
                expectedKeywords: ["name", "phone", "number", "address", "parent", "mom", "dad", "call", "home", "contact"]
            ),
            SELCurriculumStep(
                id: "s5-6",
                avatarDialogue: "My mom came and picked me up! I'm safe at home now, relaxing on the couch. What an adventure today was! I learned so much about staying safe and being brave.",
                participationPrompt: "Great job helping the avatar today! What was the most important thing you learned?",
                responseOptions: [
                    SELResponseOption(id: "s5-6a", text: "I learned to stay calm when scared, never go with strangers, and always ask a police officer or someone in uniform for help!", emoji: "⭐", qualityScore: 3),
                    SELResponseOption(id: "s5-6b", text: "Don't go with strangers and ask for help.", emoji: "🌟", qualityScore: 2),
                    SELResponseOption(id: "s5-6c", text: "It was a fun adventure!", emoji: "😊", qualityScore: 1),
                ],
                allowsFreeText: true,
                targetGoals: ["Rapport building", "Reflection"],
                targetDomains: [.emotionalIntelligence, .cognitiveDevelopment, .lifeSkills],
                expectedKeywords: ["learn", "safe", "stranger", "calm", "brave", "help", "police", "officer", "important", "remember"]
            ),
        ]
    )
}
#endif
