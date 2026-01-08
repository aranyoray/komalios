//
//  ParentOnboardingSurvey.swift
//  Komal - Parent/Guardian Onboarding Survey
//
//  30-question onboarding survey (Otsimo-style)
//  Priority: Safety, Privacy & Access Boundaries
//

import Foundation

// MARK: - Survey Models

struct OnboardingSurvey: Codable {
    var responses: [String: Any] = [:]
    var completedSections: Set<SurveySection> = []
    var timestamp: Date = Date()
    var version: String = "1.0"
}

enum SurveySection: String, Codable, CaseIterable {
    case safetyPrivacy = "Safety, Privacy & Access Boundaries"
    case childProfile = "Child Profile"
    case communication = "Communication & Learning Style"
    case sensoryRegulation = "Sensory & Regulation Snapshot"
    case supportGoals = "Support & Goals"
}

// MARK: - A. Safety, Privacy & Access Boundaries (Priority)

struct SafetyPrivacyQuestions {
    static let questions: [SurveyQuestion] = [
        // Q1
        SurveyQuestion(
            id: "setup_role",
            section: .safetyPrivacy,
            number: 1,
            text: "Who is setting up this account?",
            type: .singleChoice,
            options: ["Parent", "Legal Guardian", "Caregiver", "Other"],
            required: true,
            info: "This helps us understand your relationship with the child"
        ),

        // Q2
        SurveyQuestion(
            id: "adult_presence",
            section: .safetyPrivacy,
            number: 2,
            text: "Will an adult usually be present or nearby during your child's sessions?",
            type: .singleChoice,
            options: ["Always present", "Nearby (same room)", "Nearby (different room)", "Not usually present"],
            required: true
        ),

        // Q3
        SurveyQuestion(
            id: "usage_location",
            section: .safetyPrivacy,
            number: 3,
            text: "Where will your child most often use Komal?",
            type: .multiChoice,
            options: ["Common area (living room, kitchen)", "Child's bedroom", "School", "Clinic/therapy center", "Other"],
            required: true
        ),

        // Q4
        SurveyQuestion(
            id: "daily_time_limit",
            section: .safetyPrivacy,
            number: 4,
            text: "Do you want to set a daily time limit for Komal usage?",
            type: .singleChoice,
            options: ["Yes", "No", "Not sure yet"],
            required: true
        ),

        // Q5
        SurveyQuestion(
            id: "max_session_length",
            section: .safetyPrivacy,
            number: 5,
            text: "Preferred maximum session length per day",
            type: .singleChoice,
            options: ["15 minutes", "30 minutes", "45 minutes", "60 minutes", "No limit"],
            required: false,
            dependsOn: ("daily_time_limit", "Yes")
        ),

        // Q6
        SurveyQuestion(
            id: "auto_end_session",
            section: .safetyPrivacy,
            number: 6,
            text: "Should sessions end automatically when the time limit is reached?",
            type: .singleChoice,
            options: ["Yes, end immediately", "Show warning then end", "Reminder only", "No"],
            required: false,
            dependsOn: ("daily_time_limit", "Yes")
        ),

        // Q7
        SurveyQuestion(
            id: "feature_consent",
            section: .safetyPrivacy,
            number: 7,
            text: "Which features do you consent to for your child? (Select all that apply)",
            type: .multiChoice,
            options: [
                "Microphone-based interaction",
                "Camera-based interaction",
                "Emotion or expression analysis",
                "None of the above"
            ],
            required: true,
            info: "All processing happens on-device for privacy"
        ),

        // Q8
        SurveyQuestion(
            id: "block_short_videos",
            section: .safetyPrivacy,
            number: 8,
            text: "Should Komal block or gate short, fast-looping video content by default?",
            type: .singleChoice,
            options: ["Block completely", "Gate (requires approval)", "Allow", "Age-appropriate default"],
            required: true,
            info: "TikTok, Reels, Shorts, etc."
        ),

        // Q9
        SurveyQuestion(
            id: "block_live_content",
            section: .safetyPrivacy,
            number: 9,
            text: "Should Komal block or gate live or real-time content by default?",
            type: .singleChoice,
            options: ["Block completely", "Gate (requires approval)", "Allow", "Age-appropriate default"],
            required: true,
            info: "Live streams, real-time video, etc."
        ),

        // Q10
        SurveyQuestion(
            id: "report_viewers",
            section: .safetyPrivacy,
            number: 10,
            text: "Who should be able to view your child's activity reports and insights?",
            type: .multiChoice,
            options: ["Only me", "Co-parent/partner", "Therapist/clinician", "Teacher/educator", "Other family member"],
            required: true
        ),

        // Q11
        SurveyQuestion(
            id: "data_deletion",
            section: .safetyPrivacy,
            number: 11,
            text: "Would you like the option to delete your child's data at any time?",
            type: .singleChoice,
            options: ["Yes, full deletion rights", "Yes, but keep anonymized analytics", "No preference"],
            required: true,
            info: "GDPR & COPPA compliant"
        ),

        // Q12
        SurveyQuestion(
            id: "block_notifications",
            section: .safetyPrivacy,
            number: 12,
            text: "Do you want notifications when access is blocked or gated?",
            type: .singleChoice,
            options: ["Yes, all blocks and gates", "Only blocks", "Only when child requests approval", "No notifications"],
            required: true
        )
    ]
}

// MARK: - B. Child Profile

struct ChildProfileQuestions {
    static let questions: [SurveyQuestion] = [
        // Q13
        SurveyQuestion(
            id: "child_age",
            section: .childProfile,
            number: 13,
            text: "Child's age",
            type: .number,
            required: true,
            validation: .ageRange(min: 3, max: 18)
        ),

        // Q14
        SurveyQuestion(
            id: "primary_languages",
            section: .childProfile,
            number: 14,
            text: "Primary language(s) spoken",
            type: .multiChoice,
            options: ["English", "Spanish", "Mandarin", "Hindi", "Bengali", "Arabic", "French", "Other"],
            required: true
        ),

        // Q15
        SurveyQuestion(
            id: "location",
            section: .childProfile,
            number: 15,
            text: "Country and city",
            type: .text,
            required: false,
            placeholder: "e.g., United States, New York"
        ),

        // Q16
        SurveyQuestion(
            id: "has_diagnosis",
            section: .childProfile,
            number: 16,
            text: "Has your child received a formal developmental or learning diagnosis?",
            type: .singleChoice,
            options: ["Yes", "No", "Under evaluation", "Prefer not to say"],
            required: true
        ),

        // Q17
        SurveyQuestion(
            id: "diagnosis_type",
            section: .childProfile,
            number: 17,
            text: "If yes, which diagnosis? (Optional)",
            type: .multiChoice,
            options: [
                "Autism Spectrum Disorder (ASD)",
                "ADHD",
                "Speech/Language Delay",
                "Learning Disability",
                "Anxiety Disorder",
                "Sensory Processing Disorder",
                "Developmental Delay",
                "Other"
            ],
            required: false,
            dependsOn: ("has_diagnosis", "Yes")
        ),

        // Q18
        SurveyQuestion(
            id: "concerns",
            section: .childProfile,
            number: 18,
            text: "If no diagnosis, what concerns led you to try Komal?",
            type: .multiChoice,
            options: [
                "Social skills challenges",
                "Emotional regulation difficulties",
                "Attention/focus concerns",
                "Language development",
                "Behavioral concerns",
                "School readiness",
                "General SEL support",
                "No specific concerns, preventive use"
            ],
            required: false,
            dependsOn: ("has_diagnosis", "No")
        ),

        // Q19
        SurveyQuestion(
            id: "previous_apps",
            section: .childProfile,
            number: 19,
            text: "Has your child used learning, therapy, or SEL apps before?",
            type: .singleChoice,
            options: ["Yes, multiple apps", "Yes, one or two apps", "No, this is the first", "Not sure"],
            required: false
        )
    ]
}

// MARK: - C. Communication & Learning Style

struct CommunicationQuestions {
    static let questions: [SurveyQuestion] = [
        // Q20
        SurveyQuestion(
            id: "communication_method",
            section: .communication,
            number: 20,
            text: "How does your child usually communicate?",
            type: .singleChoice,
            options: ["Mostly speech", "Speech with gestures", "Mostly gestures/pointing", "AAC device", "Mix of methods", "Emerging/limited"],
            required: true
        ),

        // Q21
        SurveyQuestion(
            id: "instruction_understanding",
            section: .communication,
            number: 21,
            text: "How well does your child understand spoken instructions?",
            type: .singleChoice,
            options: [
                "Understands complex instructions",
                "Understands simple, clear instructions",
                "Needs repetition and visuals",
                "Limited understanding",
                "Not sure"
            ],
            required: true
        ),

        // Q22
        SurveyQuestion(
            id: "learning_style",
            section: .communication,
            number: 22,
            text: "How does your child engage best with learning?",
            type: .multiChoice,
            options: ["Listening", "Talking/discussing", "Visual demonstrations", "Repetition and practice", "Play-based", "Hands-on activities"],
            required: true
        ),

        // Q23
        SurveyQuestion(
            id: "attention_span",
            section: .communication,
            number: 23,
            text: "Typical attention span for a preferred activity",
            type: .singleChoice,
            options: ["Less than 5 minutes", "5-10 minutes", "10-20 minutes", "20-30 minutes", "More than 30 minutes"],
            required: true
        )
    ]
}

// MARK: - D. Sensory & Regulation Snapshot

struct SensoryQuestions {
    static let questions: [SurveyQuestion] = [
        // Q24
        SurveyQuestion(
            id: "sensory_sensitivities",
            section: .sensoryRegulation,
            number: 24,
            text: "Does your child have any sensory sensitivities?",
            type: .singleChoice,
            options: ["Yes, significant", "Yes, mild", "No", "Not sure"],
            required: true
        ),

        // Q25
        SurveyQuestion(
            id: "challenging_inputs",
            section: .sensoryRegulation,
            number: 25,
            text: "Which inputs are most challenging? (Select all that apply)",
            type: .multiChoice,
            options: [
                "Loud sounds",
                "Bright or flashing visuals",
                "Touch/textures",
                "Transitions between activities",
                "None of the above"
            ],
            required: false,
            dependsOn: ("sensory_sensitivities", "Yes, significant")
        ),

        // Q26
        SurveyQuestion(
            id: "frustration_triggers",
            section: .sensoryRegulation,
            number: 26,
            text: "What most commonly leads to frustration or withdrawal?",
            type: .multiChoice,
            options: [
                "Tasks that are too hard",
                "Tasks that are too easy/boring",
                "Social interaction demands",
                "Changes in routine",
                "Sensory overload",
                "Communication challenges",
                "Not sure"
            ],
            required: true
        )
    ]
}

// MARK: - E. Support & Goals

struct SupportGoalsQuestions {
    static let questions: [SurveyQuestion] = [
        // Q27
        SurveyQuestion(
            id: "current_support",
            section: .supportGoals,
            number: 27,
            text: "Is your child currently receiving any therapy or special education support?",
            type: .multiChoice,
            options: [
                "Speech therapy",
                "Occupational therapy",
                "Behavioral therapy (ABA, CBT)",
                "Special education services",
                "Social skills groups",
                "Other therapy",
                "No current support"
            ],
            required: true
        ),

        // Q28
        SurveyQuestion(
            id: "learning_supporter",
            section: .supportGoals,
            number: 28,
            text: "Who usually supports your child during learning activities?",
            type: .multiChoice,
            options: ["Parent/guardian", "Sibling", "Therapist", "Teacher", "Aide/assistant", "Child works independently"],
            required: false
        ),

        // Q29
        SurveyQuestion(
            id: "primary_goal",
            section: .supportGoals,
            number: 29,
            text: "What is your primary goal for using Komal?",
            type: .singleChoice,
            options: [
                "Improve social skills",
                "Support emotional regulation",
                "Enhance communication",
                "Build attention and focus",
                "School readiness",
                "Complement therapy",
                "General SEL development",
                "Other"
            ],
            required: true
        ),

        // Q30
        SurveyQuestion(
            id: "success_definition",
            section: .supportGoals,
            number: 30,
            text: "How would you define a successful experience after 3 months?",
            type: .text,
            required: true,
            placeholder: "Describe what success looks like for your child...",
            info: "Open-ended: helps us personalize the experience"
        )
    ]
}

// MARK: - Survey Question Model

struct SurveyQuestion {
    let id: String
    let section: SurveySection
    let number: Int
    let text: String
    let type: QuestionType
    let options: [String]?
    let required: Bool
    let placeholder: String?
    let info: String?
    let dependsOn: (questionId: String, expectedAnswer: String)?
    let validation: Validation?

    enum QuestionType {
        case singleChoice
        case multiChoice
        case text
        case number
        case scale(min: Int, max: Int)
    }

    enum Validation {
        case ageRange(min: Int, max: Int)
        case minLength(Int)
        case maxLength(Int)
        case email
        case phone
    }

    init(
        id: String,
        section: SurveySection,
        number: Int,
        text: String,
        type: QuestionType,
        options: [String]? = nil,
        required: Bool = false,
        placeholder: String? = nil,
        info: String? = nil,
        dependsOn: (String, String)? = nil,
        validation: Validation? = nil
    ) {
        self.id = id
        self.section = section
        self.number = number
        self.text = text
        self.type = type
        self.options = options
        self.required = required
        self.placeholder = placeholder
        self.info = info
        self.dependsOn = dependsOn
        self.validation = validation
    }
}

// MARK: - Survey Service

class OnboardingService {
    static let shared = OnboardingService()

    private init() {}

    /// Get all survey questions in order
    func getAllQuestions() -> [SurveyQuestion] {
        return SafetyPrivacyQuestions.questions +
               ChildProfileQuestions.questions +
               CommunicationQuestions.questions +
               SensoryQuestions.questions +
               SupportGoalsQuestions.questions
    }

    /// Get questions for a specific section
    func getQuestions(for section: SurveySection) -> [SurveyQuestion] {
        getAllQuestions().filter { $0.section == section }
    }

    /// Check if a question should be shown based on dependencies
    func shouldShow(question: SurveyQuestion, given responses: [String: Any]) -> Bool {
        guard let (dependentId, expectedAnswer) = question.dependsOn else {
            return true  // No dependency, always show
        }

        let actualAnswer = responses[dependentId] as? String
        return actualAnswer == expectedAnswer
    }

    /// Validate a response
    func validate(response: Any?, for question: SurveyQuestion) -> ValidationResult {
        // Required check
        if question.required && response == nil {
            return .invalid("This question is required")
        }

        guard let response = response else {
            return .valid
        }

        // Type-specific validation
        switch question.type {
        case .number:
            guard let number = response as? Int else {
                return .invalid("Must be a number")
            }
            if let .ageRange(min, max) = question.validation {
                if number < min || number > max {
                    return .invalid("Age must be between \(min) and \(max)")
                }
            }

        case .text:
            guard let text = response as? String else {
                return .invalid("Must be text")
            }
            if let .minLength(min) = question.validation {
                if text.count < min {
                    return .invalid("Must be at least \(min) characters")
                }
            }

        default:
            break
        }

        return .valid
    }

    enum ValidationResult {
        case valid
        case invalid(String)
    }

    /// Save survey responses
    func saveSurvey(_ responses: [String: Any]) {
        let survey = OnboardingSurvey(responses: responses)
        // Save to UserDefaults or backend
        if let data = try? JSONEncoder().encode(survey) {
            UserDefaults.standard.set(data, forKey: "komal.onboarding_survey")
        }
    }

    /// Check if survey is complete
    func isSurveyComplete() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "komal.onboarding_survey"),
              let survey = try? JSONDecoder().decode(OnboardingSurvey.self, from: data) else {
            return false
        }

        let allQuestions = getAllQuestions()
        let requiredQuestions = allQuestions.filter { $0.required }

        for question in requiredQuestions {
            if survey.responses[question.id] == nil {
                return false
            }
        }

        return true
    }

    /// Apply survey responses to app settings
    func applySettingsFromSurvey() {
        guard let data = UserDefaults.standard.data(forKey: "komal.onboarding_survey"),
              let survey = try? JSONDecoder().decode(OnboardingSurvey.self, from: data) else {
            return
        }

        let parentControl = ParentControlService.shared
        let responses = survey.responses

        // Apply safety settings
        if let blockShortVideos = responses["block_short_videos"] as? String {
            switch blockShortVideos {
            case "Block completely":
                parentControl.blockURL("tiktok.com")
                parentControl.blockURL("instagram.com/reels")
                parentControl.blockKeyword("shorts")
            case "Age-appropriate default":
                // Use age-based rules (default)
                break
            default:
                break
            }
        }

        if let blockLiveContent = responses["block_live_content"] as? String {
            switch blockLiveContent {
            case "Block completely":
                parentControl.blockKeyword("live")
                parentControl.blockKeyword("streaming")
            default:
                break
            }
        }

        // Apply notification settings
        if let notifications = responses["block_notifications"] as? String {
            parentControl.notificationsEnabled = notifications.contains("Yes")
        }

        // Apply time limits
        if let timeLimit = responses["max_session_length"] as? String {
            // Store for session management
            UserDefaults.standard.set(timeLimit, forKey: "komal.max_session_length")
        }

        print("✅ Applied settings from onboarding survey")
    }
}
