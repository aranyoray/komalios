#if os(iOS)
import SwiftUI

// MARK: - Survey Data Models

struct ChildSurveyData {
    var name: String = ""
    var ageGroup: AgeGroup = .tenToThirteen
    var favoriteWebsites: Set<String> = []
    var interests: Set<String> = []
    var likes: Set<String> = []
    var dislikes: Set<String> = []
    var customLike: String = ""
    var customDislike: String = ""
    var screenTimeGoal: ScreenTimeGoal = .moderate
    var parentConcerns: Set<String> = []
    var selectedAvatarIndex: Int = 1
}

enum ScreenTimeGoal: String, CaseIterable {
    case minimal = "30 min/day"
    case moderate = "1-2 hours/day"
    case flexible = "Flexible"
}

// MARK: - Main Onboarding View

struct PostAuthOnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var pathManager: PathManager
    @EnvironmentObject var lang: LanguageManager
    @State private var currentPage = 0
    @State private var surveyData = ChildSurveyData()
    @State private var preferences: ContentFilterPreferences = ContentFilterPreferences()
    @State private var pinEntry: String = ""
    @State private var pinConfirm: String = ""
    @State private var pinMismatchError: Bool = false
    @State private var enableBiometric: Bool = false
    @State private var showPlanSelection = false

    var onComplete: () -> Void

    private let totalPages = 12

    var body: some View {
        ZStack {
            // Clean white/light gray background
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Language selector + Progress bar
                HStack {
                    Spacer()
                    LanguageSelectorView()
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                SurveyProgressBar(current: currentPage, total: totalPages)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                // Page content
                TabView(selection: $currentPage) {
                    welcomeScreen.tag(0)
                    childInfoScreen.tag(1)
                    websitesScreen.tag(2)
                    interestsScreen.tag(3)
                    likesScreen.tag(4)
                    dislikesScreen.tag(5)
                    parentConcernsScreen.tag(6)
                    filterPreferencesScreen.tag(7)
                    pinSetupScreen.tag(8)
                    guidedAccessScreen.tag(9)
                    avatarSelectionScreen.tag(10)
                    completionScreen.tag(11)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
    }

    // MARK: - Screen 1: Welcome
    
    private var welcomeScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 20)

                    // Professional header
                    VStack(spacing: 16) {
                        if let uiImage = UIImage(named: "komaliconnobg") {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                        }

                        VStack(spacing: 8) {
                            Text(lang.localized("onboarding.welcome.title"))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)

                            Text(lang.localized("onboarding.welcome.subtitle"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                    }

                    // Research-backed info cards
                    VStack(spacing: 16) {
                        InfoCard(
                            icon: "brain.head.profile",
                            title: lang.localized("onboarding.welcome.card1.title"),
                            description: lang.localized("onboarding.welcome.card1.desc"),
                            color: KomalColors.lavenderPurple
                        )

                        InfoCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: lang.localized("onboarding.welcome.card2.title"),
                            description: lang.localized("onboarding.welcome.card2.desc"),
                            color: KomalColors.pearlAqua
                        )

                        InfoCard(
                            icon: "shield.lefthalf.filled",
                            title: lang.localized("onboarding.welcome.card3.title"),
                            description: lang.localized("onboarding.welcome.card3.desc"),
                            color: KomalColors.bubblegumPink
                        )

                        InfoCard(
                            icon: "brain",
                            title: "What is SEL?",
                            description: "Social-Emotional Learning helps children develop self-awareness, social skills, and decision-making. Research shows children with strong SEL skills are 11% more likely to succeed academically.",
                            color: KomalColors.lavenderPurple
                        )
                    }
                    .padding(.horizontal, 24)

                    // Time estimate
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                        Text(lang.localized("onboarding.welcome.time_estimate"))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(KomalColors.textSecondary)
                    .padding(.top, 8)
                }
                .padding(.bottom, 60)
            }

            // Fixed bottom button
            Button(action: { withAnimation { currentPage = 1 } }) {
                Text(lang.localized("onboarding.welcome.begin"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(KomalColors.lavenderPurple)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    // MARK: - Screen 2: Child Info
    
    private var childInfoScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    SurveyHeader(
                        step: lang.localized("onboarding.info.step"),
                        title: lang.localized("onboarding.info.title"),
                        subtitle: lang.localized("onboarding.info.subtitle")
                    )
                    
                    VStack(spacing: 24) {
                        // Name input
                        VStack(alignment: .leading, spacing: 10) {
                            Text("* " + lang.localized("onboarding.info.name_label"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(KomalColors.textPrimary)

                            TextField(lang.localized("onboarding.info.name_placeholder"), text: $surveyData.name)
                                .font(.system(size: 16, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                                )
                        }
                        
                        // Age group
                        VStack(alignment: .leading, spacing: 10) {
                            Text("* " + lang.localized("onboarding.info.age_label"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(KomalColors.textPrimary)

                            Text(lang.localized("onboarding.info.age_desc"))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(KomalColors.textSecondary)
                            
                            VStack(spacing: 10) {
                                ForEach(AgeGroup.allCases.filter { $0 != .eighteenPlus }) { group in
                                    AgeGroupButton(
                                        group: group,
                                        isSelected: surveyData.ageGroup == group,
                                        onTap: { surveyData.ageGroup = group }
                                    )
                                }
                            }
                        }
                        
                        // Research note
                        ResearchNote(
                            text: lang.localized("onboarding.info.research_note")
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 60)
            }
            
            // Navigation
            SurveyNavigation(
                canGoBack: true,
                canGoNext: !surveyData.name.trimmingCharacters(in: .whitespaces).isEmpty,
                onBack: { withAnimation { currentPage = 0 } },
                onNext: {
                    UIApplication.shared.hideKeyboard()
                    preferences = ContentFilterPreferences.defaults(for: surveyData.ageGroup)
                    withAnimation { currentPage = 2 } 
                }
            )
        }
    }

    // MARK: - Screen 3: Favorite Websites
    
    private var websitesScreen: some View {
        let websiteCategories: [(String, String, [(String, String)])] = [
            ("Websites & Search", "globe", [
                ("Google", "google"),
                ("YouTube Kids", "youtubekids"),
                ("PBS Kids", "pbs"),
                ("National Geographic Kids", "natgeo"),
                ("NASA Kids", "nasakids")
            ]),
            ("Streaming & Entertainment", "play.tv.fill", [
                ("Netflix", "netflix"),
                ("Disney+", "disney"),
                ("Nick Jr.", "nickjr"),
                ("Cartoon Network", "cartoonnetwork"),
                ("Sesame Street", "sesamestreet")
            ]),
            ("Learning & Education", "book.fill", [
                ("Khan Academy Kids", "khan"),
                ("ABCmouse", "abc"),
                ("Duolingo", "duolingo"),
                ("BrainPOP", "brainpop"),
                ("Epic! Books", "epic"),
                ("Starfall", "starfall"),
                ("Prodigy Math", "prodigy"),
                ("Coolmath Games", "coolmath"),
                ("Funbrain", "funbrain")
            ]),
            ("Coding & Creativity", "chevron.left.forwardslash.chevron.right", [
                ("Scratch", "scratch"),
                ("Tynker", "tynker"),
                ("Code.org", "codeorg"),
                ("LEGO", "lego")
            ]),
            ("Social Media", "person.2.fill", [
                ("Instagram", "instagram"),
                ("Facebook", "facebook"),
                ("X (Twitter)", "twitter")
            ]),
            ("Gaming", "gamecontroller.fill", [
                ("Roblox", "roblox"),
                ("Minecraft", "minecraft"),
                ("Fortnite", "fortnite"),
                ("Among Us", "amongus"),
                ("Brawl Stars", "brawlstars"),
                ("Clash Royale", "clashroyale"),
                ("Pokemon GO", "pokemongo"),
                ("Animal Crossing", "animalcrossing"),
                ("Subway Surfers", "subwaysurfers")
            ])
        ]

        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    SurveyHeader(
                        step: lang.localized("onboarding.websites.step"),
                        title: lang.localized("onboarding.websites.title"),
                        subtitle: lang.localized("onboarding.websites.subtitle")
                    )

                    Text(lang.localized("onboarding.websites.desc"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(KomalColors.textSecondary)
                        .padding(.horizontal, 24)

                    // Categorized website grid
                    VStack(spacing: 20) {
                        ForEach(websiteCategories, id: \.0) { category in
                            VStack(alignment: .leading, spacing: 10) {
                                // Category header
                                HStack(spacing: 8) {
                                    Image(systemName: category.1)
                                        .font(.system(size: 14))
                                        .foregroundColor(KomalColors.lavenderPurple)
                                    Text(category.0)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(KomalColors.textPrimary)
                                }

                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 10) {
                                    ForEach(category.2, id: \.1) { website in
                                        SelectableChip(
                                            text: website.0,
                                            isSelected: surveyData.favoriteWebsites.contains(website.1),
                                            onTap: {
                                                if surveyData.favoriteWebsites.contains(website.1) {
                                                    surveyData.favoriteWebsites.remove(website.1)
                                                } else if surveyData.favoriteWebsites.count < 5 {
                                                    surveyData.favoriteWebsites.insert(website.1)
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Selection count
                    Text(lang.localized("common.selected_count", surveyData.favoriteWebsites.count, 5))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(surveyData.favoriteWebsites.count == 5 ? KomalColors.lavenderPurple : KomalColors.textSecondary)
                }
                .padding(.bottom, 60)
            }
            
            SurveyNavigation(
                canGoBack: true,
                canGoNext: true,
                onBack: { withAnimation { currentPage = 1 } },
                onNext: { withAnimation { currentPage = 3 } }
            )
        }
    }

    // MARK: - Screen 4: Interests
    
    private var interestsScreen: some View {
        let interests = [
            (lang.localized("onboarding.interest.gaming"), "gamecontroller.fill"),
            (lang.localized("onboarding.interest.animals"), "pawprint.fill"),
            (lang.localized("onboarding.interest.science"), "atom"),
            (lang.localized("onboarding.interest.art"), "paintpalette.fill"),
            (lang.localized("onboarding.interest.music"), "music.note"),
            (lang.localized("onboarding.interest.sports"), "sportscourt.fill"),
            (lang.localized("onboarding.interest.coding"), "chevron.left.forwardslash.chevron.right"),
            (lang.localized("onboarding.interest.reading"), "book.fill"),
            (lang.localized("onboarding.interest.cooking"), "fork.knife"),
            (lang.localized("onboarding.interest.nature"), "leaf.fill"),
            (lang.localized("onboarding.interest.space"), "moon.stars.fill"),
            (lang.localized("onboarding.interest.history"), "building.columns.fill"),
            (lang.localized("onboarding.interest.movies"), "film.fill"),
            (lang.localized("onboarding.interest.crafts"), "scissors"),
            (lang.localized("onboarding.interest.dinosaurs"), "fossil.shell.fill"),
            (lang.localized("onboarding.interest.vehicles"), "car.fill"),
            (lang.localized("onboarding.interest.fashion"), "tshirt.fill"),
            (lang.localized("onboarding.interest.dance"), "figure.dance"),
            (lang.localized("onboarding.interest.photography"), "camera.fill"),
            (lang.localized("onboarding.interest.travel"), "airplane"),
            (lang.localized("onboarding.interest.math"), "function"),
            (lang.localized("onboarding.interest.puzzles"), "puzzlepiece.fill"),
            (lang.localized("onboarding.interest.robots"), "gearshape.2.fill"),
            (lang.localized("onboarding.interest.magic"), "wand.and.stars"),
            (lang.localized("onboarding.interest.superheroes"), "bolt.fill"),
            (lang.localized("onboarding.interest.gardening"), "leaf.arrow.circlepath"),
            (lang.localized("onboarding.interest.astronomy"), "telescope.fill"),
            (lang.localized("onboarding.interest.languages"), "character.bubble.fill"),
            (lang.localized("onboarding.interest.boardgames"), "dice.fill"),
            (lang.localized("onboarding.interest.swimming"), "figure.pool.swim"),
            (lang.localized("onboarding.interest.comics"), "text.bubble.fill"),
            (lang.localized("onboarding.interest.yoga"), "figure.yoga"),
            (lang.localized("onboarding.interest.theater"), "theatermasks.fill")
        ]
        
        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    SurveyHeader(
                        step: lang.localized("onboarding.interests.step"),
                        title: "* " + lang.localized("onboarding.interests.title"),
                        subtitle: lang.localized("onboarding.interests.subtitle")
                    )

                    Text(lang.localized("onboarding.interests.desc"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(KomalColors.textSecondary)
                        .padding(.horizontal, 24)
                    
                    // Interest grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(interests, id: \.0) { interest in
                            InterestTile(
                                title: interest.0,
                                icon: interest.1,
                                isSelected: surveyData.interests.contains(interest.0),
                                onTap: {
                                    if surveyData.interests.contains(interest.0) {
                                        surveyData.interests.remove(interest.0)
                                    } else if surveyData.interests.count < 5 {
                                        surveyData.interests.insert(interest.0)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Text(lang.localized("common.selected_count", surveyData.interests.count, 5))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(surveyData.interests.count >= 3 ? KomalColors.lavenderPurple : KomalColors.textSecondary)
                }
                .padding(.bottom, 60)
            }
            
            SurveyNavigation(
                canGoBack: true,
                canGoNext: surveyData.interests.count >= 3,
                onBack: { withAnimation { currentPage = 2 } },
                onNext: { withAnimation { currentPage = 4 } }
            )
        }
    }

    // MARK: - Screen 5: Likes
    
    private var likesScreen: some View {
        let likeOptions = [
            lang.localized("onboarding.like.watching_videos"),
            lang.localized("onboarding.like.playing_games"),
            lang.localized("onboarding.like.chatting"),
            lang.localized("onboarding.like.learning"),
            lang.localized("onboarding.like.creative"),
            lang.localized("onboarding.like.exploring"),
            lang.localized("onboarding.like.music"),
            lang.localized("onboarding.like.virtual_worlds"),
            lang.localized("onboarding.like.puzzles"),
            lang.localized("onboarding.like.funny"),
            lang.localized("onboarding.like.stories"),
            lang.localized("onboarding.like.making_videos"),
            lang.localized("onboarding.like.drawing"),
            lang.localized("onboarding.like.photography"),
            lang.localized("onboarding.like.coding"),
            lang.localized("onboarding.like.reading_comics"),
            lang.localized("onboarding.like.collecting"),
            lang.localized("onboarding.like.building"),
            lang.localized("onboarding.like.cooking_videos"),
            lang.localized("onboarding.like.science_experiments"),
            lang.localized("onboarding.like.dancing"),
            lang.localized("onboarding.like.trivia"),
            lang.localized("onboarding.like.anime"),
            lang.localized("onboarding.like.podcasts"),
            lang.localized("onboarding.like.shopping"),
            lang.localized("onboarding.like.live_streams")
        ]
        
        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    SurveyHeader(
                        step: lang.localized("onboarding.likes.step"),
                        title: "* " + lang.localized("onboarding.likes.title"),
                        subtitle: lang.localized("onboarding.likes.subtitle")
                    )

                    Text(lang.localized("onboarding.likes.desc"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(KomalColors.textSecondary)
                        .padding(.horizontal, 24)
                    
                    // Likes grid
                    FlowLayoutView(items: likeOptions) { option in
                        SelectableChip(
                            text: option,
                            isSelected: surveyData.likes.contains(option),
                            onTap: {
                                if surveyData.likes.contains(option) {
                                    surveyData.likes.remove(option)
                                } else {
                                    surveyData.likes.insert(option)
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Custom input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lang.localized("onboarding.likes.other"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)

                        TextField(lang.localized("onboarding.likes.other_placeholder"), text: $surveyData.customLike)
                            .font(.system(size: 15))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 60)
            }
            
            SurveyNavigation(
                canGoBack: true,
                canGoNext: surveyData.likes.count >= 1,
                onBack: { withAnimation { currentPage = 3 } },
                onNext: { withAnimation { currentPage = 5 } }
            )
        }
    }

    // MARK: - Screen 6: Dislikes
    
    private var dislikesScreen: some View {
        let dislikeOptions = [
            lang.localized("onboarding.dislike.scary"),
            lang.localized("onboarding.dislike.loud"),
            lang.localized("onboarding.dislike.mean"),
            lang.localized("onboarding.dislike.strangers"),
            lang.localized("onboarding.dislike.violent"),
            lang.localized("onboarding.dislike.sad"),
            lang.localized("onboarding.dislike.ads"),
            lang.localized("onboarding.dislike.reading"),
            lang.localized("onboarding.dislike.timed"),
            lang.localized("onboarding.dislike.losing"),
            lang.localized("onboarding.dislike.popups"),
            lang.localized("onboarding.dislike.rushed")
        ]
        
        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    SurveyHeader(
                        step: lang.localized("onboarding.dislikes.step"),
                        title: lang.localized("onboarding.dislikes.title"),
                        subtitle: lang.localized("onboarding.dislikes.subtitle")
                    )

                    Text(lang.localized("onboarding.dislikes.desc"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(KomalColors.textSecondary)
                        .padding(.horizontal, 24)
                    
                    // Dislikes grid
                    FlowLayoutView(items: dislikeOptions) { option in
                        SelectableChip(
                            text: option,
                            isSelected: surveyData.dislikes.contains(option),
                            color: KomalColors.bubblegumPink,
                            onTap: {
                                if surveyData.dislikes.contains(option) {
                                    surveyData.dislikes.remove(option)
                                } else {
                                    surveyData.dislikes.insert(option)
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Custom input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lang.localized("onboarding.dislikes.other"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)

                        TextField(lang.localized("onboarding.dislikes.other_placeholder"), text: $surveyData.customDislike)
                            .font(.system(size: 15))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal, 24)
                    
                    ResearchNote(
                        text: lang.localized("onboarding.dislikes.research_note")
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 60)
            }
            
            SurveyNavigation(
                canGoBack: true,
                canGoNext: true,
                onBack: { withAnimation { currentPage = 4 } },
                onNext: { withAnimation { currentPage = 6 } }
            )
        }
    }

    // MARK: - Screen 7: Parent Concerns
    
    private var parentConcernsScreen: some View {
        let concerns = [
            (lang.localized("onboarding.concern.cyberbullying"), "exclamationmark.bubble.fill", lang.localized("onboarding.concern.cyberbullying.desc")),
            (lang.localized("onboarding.concern.inappropriate"), "eye.slash.fill", lang.localized("onboarding.concern.inappropriate.desc")),
            (lang.localized("onboarding.concern.predators"), "person.fill.questionmark", lang.localized("onboarding.concern.predators.desc")),
            (lang.localized("onboarding.concern.addiction"), "hourglass", lang.localized("onboarding.concern.addiction.desc")),
            (lang.localized("onboarding.concern.privacy"), "lock.open.fill", lang.localized("onboarding.concern.privacy.desc")),
            (lang.localized("onboarding.concern.misinfo"), "xmark.circle.fill", lang.localized("onboarding.concern.misinfo.desc")),
            (lang.localized("onboarding.concern.scams"), "creditcard.fill", lang.localized("onboarding.concern.scams.desc")),
            (lang.localized("onboarding.concern.mental"), "heart.fill", lang.localized("onboarding.concern.mental.desc"))
        ]
        
        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    SurveyHeader(
                        step: lang.localized("onboarding.concerns.step"),
                        title: "* " + lang.localized("onboarding.concerns.title"),
                        subtitle: lang.localized("onboarding.concerns.subtitle")
                    )

                    Text(lang.localized("onboarding.concerns.desc"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(KomalColors.textSecondary)
                        .padding(.horizontal, 24)
                    
                    // Concerns list
                    VStack(spacing: 12) {
                        ForEach(concerns, id: \.0) { concern in
                            ConcernRow(
                                title: concern.0,
                                icon: concern.1,
                                description: concern.2,
                                isSelected: surveyData.parentConcerns.contains(concern.0),
                                onTap: {
                                    if surveyData.parentConcerns.contains(concern.0) {
                                        surveyData.parentConcerns.remove(concern.0)
                                    } else {
                                        surveyData.parentConcerns.insert(concern.0)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 60)
            }
            
            SurveyNavigation(
                canGoBack: true,
                canGoNext: surveyData.parentConcerns.count >= 1,
                onBack: { withAnimation { currentPage = 5 } },
                onNext: {
                    applyParentConcernsToFilters()
                    withAnimation { currentPage = 7 }
                }
            )
        }
    }

    // MARK: - Screen 8: Filter Preferences

    private var filterPreferencesScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    SurveyHeader(
                        step: lang.localized("onboarding.filters.step"),
                        title: lang.localized("onboarding.filters.title"),
                        subtitle: lang.localized("onboarding.filters.subtitle")
                    )

                    Text(lang.localized("onboarding.filters.desc"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(KomalColors.textSecondary)
                        .padding(.horizontal, 24)

                    VStack(spacing: 12) {
                        ForEach(OnboardingCategory.allCategories) { category in
                            CategorySettingsCard(category: category, preferences: $preferences)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 60)
            }

            SurveyNavigation(
                canGoBack: true,
                canGoNext: true,
                onBack: { withAnimation { currentPage = 6 } },
                onNext: { withAnimation { currentPage = 8 } }
            )
        }
    }

    private var pinSetupScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    SurveyHeader(
                        step: lang.localized("onboarding.pin.step"),
                        title: lang.localized("onboarding.pin.title"),
                        subtitle: lang.localized("onboarding.pin.subtitle")
                    )

                    Text(lang.localized("onboarding.pin.desc"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(KomalColors.textSecondary)
                        .padding(.horizontal, 24)

                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("* " + lang.localized("onboarding.pin.enter"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(KomalColors.textPrimary)

                            SecureField(lang.localized("onboarding.pin.placeholder"), text: $pinEntry)
                                .keyboardType(.numberPad)
                                .font(.system(size: 18, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                                )
                                .onChange(of: pinEntry) {
                                    if pinEntry.count > 4 { pinEntry = String(pinEntry.prefix(4)) }
                                }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("* " + lang.localized("onboarding.pin.confirm"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(KomalColors.textPrimary)

                            SecureField(lang.localized("onboarding.pin.confirm_placeholder"), text: $pinConfirm)
                                .keyboardType(.numberPad)
                                .font(.system(size: 18, weight: .medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(pinMismatchError ? Color.red : Color.black.opacity(0.1), lineWidth: pinMismatchError ? 2 : 0.5)
                                )
                                .onChange(of: pinConfirm) {
                                    if pinConfirm.count > 4 { pinConfirm = String(pinConfirm.prefix(4)) }
                                }

                            if pinMismatchError {
                                Text(lang.localized("onboarding.pin.mismatch"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }

                        // Biometric toggle
                        if BiometricAuthService.availableBiometricType != .none {
                            HStack(spacing: 12) {
                                Image(systemName: BiometricAuthService.biometricIcon)
                                    .font(.system(size: 22))
                                    .foregroundColor(KomalColors.lavenderPurple)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lang.localized("onboarding.pin.enable_biometric", BiometricAuthService.biometricName))
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)
                                    Text(lang.localized("onboarding.pin.use_biometric", BiometricAuthService.biometricName))
                                        .font(.system(size: 12))
                                        .foregroundColor(KomalColors.textSecondary)
                                }

                                Spacer()

                                Toggle("", isOn: $enableBiometric)
                                    .labelsHidden()
                                    .tint(KomalColors.lavenderPurple)
                            }
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    ResearchNote(
                        text: lang.localized("onboarding.pin.research_note")
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 60)
            }

            SurveyNavigation(
                canGoBack: true,
                canGoNext: pinEntry.count >= 4 && pinConfirm.count >= 4,
                onBack: { withAnimation { currentPage = 7 } },
                onNext: {
                    UIApplication.shared.hideKeyboard()
                    if pinEntry == pinConfirm {
                        pinMismatchError = false
                        KeychainService.savePin(pinEntry)
                        BiometricAuthService.isBiometricEnabled = enableBiometric
                        appState.parentSettings.biometricEnabled = enableBiometric
                        withAnimation { currentPage = 9 }  // Go to avatar selection
                    } else {
                        pinMismatchError = true
                    }
                }
            )
        }
    }

    // MARK: - Screen 10: Guided Access Setup

    private var guidedAccessScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // Shield + lock icon header
                    ZStack {
                        Circle()
                            .fill(KomalColors.lavenderPurple.opacity(0.15))
                            .frame(width: 90, height: 90)

                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 40))
                            .foregroundColor(KomalColors.lavenderPurple)
                    }

                    VStack(spacing: 8) {
                        Text(lang.localized("onboarding.guided_access.title"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)

                        Text(lang.localized("onboarding.guided_access.explanation"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    // Step cards
                    VStack(spacing: 12) {
                        GuidedAccessStepCard(
                            stepNumber: 1,
                            text: lang.localized("onboarding.guided_access.step1")
                        )
                        GuidedAccessStepCard(
                            stepNumber: 2,
                            text: lang.localized("onboarding.guided_access.step2")
                        )
                        GuidedAccessStepCard(
                            stepNumber: 3,
                            text: lang.localized("onboarding.guided_access.step3")
                        )
                    }
                    .padding(.horizontal, 24)

                    // Open Settings button
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gear")
                                .font(.system(size: 16, weight: .semibold))
                            Text(lang.localized("onboarding.guided_access.open_settings"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(KomalColors.lavenderPurple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KomalColors.lavenderPurple.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(KomalColors.lavenderPurple, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)

                    ResearchNote(
                        text: lang.localized("onboarding.guided_access.research_note")
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 60)
            }

            SurveyNavigation(
                canGoBack: true,
                canGoNext: true,
                onBack: { withAnimation { currentPage = 8 } },
                onNext: { withAnimation { currentPage = 10 } }
            )
        }
    }

    // MARK: - Screen 11: Avatar Selection

    private var avatarSelectionScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    SurveyHeader(
                        step: "10",
                        title: lang.localized("onboarding.avatar.title"),
                        subtitle: lang.localized("onboarding.avatar.subtitle")
                    )

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(RikiCharacter.allCharacters) { character in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    surveyData.selectedAvatarIndex = character.id
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    if let uiImage = UIImage(named: character.imageName) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 64, height: 64)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        surveyData.selectedAvatarIndex == character.id ? KomalColors.lavenderPurple : Color.clear,
                                                        lineWidth: 3
                                                    )
                                            )
                                    }

                                    Text(character.name)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(
                                            surveyData.selectedAvatarIndex == character.id ? KomalColors.lavenderPurple : KomalColors.textPrimary
                                        )
                                }
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(surveyData.selectedAvatarIndex == character.id ? KomalColors.lavenderPurple.opacity(0.1) : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            surveyData.selectedAvatarIndex == character.id ? KomalColors.lavenderPurple : Color.gray.opacity(0.2),
                                            lineWidth: surveyData.selectedAvatarIndex == character.id ? 2 : 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 60)
            }

            SurveyNavigation(
                canGoBack: true,
                canGoNext: true,
                onBack: { withAnimation { currentPage = 9 } },
                onNext: { withAnimation { currentPage = 11 } }
            )
        }
    }

    // MARK: - Screen 12: Completion

    private var completionScreen: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)
                
                // Success icon
                ZStack {
                    Circle()
                        .fill(KomalColors.pearlAqua.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 44))
                        .foregroundColor(KomalColors.pearlAqua)
                }
                
                VStack(spacing: 8) {
                    Text(lang.localized("onboarding.complete.title"))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)

                    Text(lang.localized("onboarding.complete.subtitle", surveyData.name))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary)
                }
                
                // Summary card
                VStack(alignment: .leading, spacing: 16) {
                    Text(lang.localized("onboarding.complete.summary"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(KomalColors.textSecondary)

                    SummaryItem(label: lang.localized("onboarding.complete.name"), value: surveyData.name)
                    SummaryItem(label: lang.localized("onboarding.complete.age_group"), value: surveyData.ageGroup.rawValue)
                    SummaryItem(label: lang.localized("onboarding.complete.interests"), value: surveyData.interests.prefix(3).joined(separator: ", "))
                    SummaryItem(label: lang.localized("onboarding.complete.concerns"), value: surveyData.parentConcerns.prefix(2).joined(separator: ", "))
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(KomalColors.lavenderPurple)
                        Text(lang.localized("onboarding.complete.adjust_note"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
                .padding(.horizontal, 24)
                
                Spacer().frame(height: 20)
                
                // Complete button
                Button(action: {
                    // Save profile & preferences first
                    appState.activeProfile = ChildProfile(name: surveyData.name, ageGroup: surveyData.ageGroup, selectedAvatarIndex: surveyData.selectedAvatarIndex)
                    appState.contentFilterPreferences = preferences
                    appState.savePreferences()

                    // Show plan selection
                    showPlanSelection = true
                }) {
                    Text(lang.localized("onboarding.complete.start"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(KomalColors.pearlAqua)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)

                Button(action: { withAnimation { currentPage = 10 } }) {
                    Text(lang.localized("onboarding.complete.review"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary)
                }
                .padding(.bottom, 20)
            }
        }
        .fullScreenCover(isPresented: $showPlanSelection) {
            PlanSelectionView { plan in
                appState.subscriptionState.currentPlan = plan
                if let productID = plan.productID {
                    appState.subscriptionState.purchasedProductID = productID
                }
                appState.hasSelectedPlan = true
                appState.hasCompletedOnboarding = true
                appState.savePreferences()
                showPlanSelection = false
                onComplete()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func applyParentConcernsToFilters() {
        // B27 fix: parentConcerns stores localized display strings (from lang.localized()),
        // which differ by language. We match against the localization *keys* instead of
        // hardcoded English strings, so the mapping works regardless of the active locale.
        // Each canonical key corresponds to the key used in parentConcernsScreen's concerns array.
        let canonicalKeys: [(key: String, localized: String)] = [
            ("onboarding.concern.cyberbullying", lang.localized("onboarding.concern.cyberbullying")),
            ("onboarding.concern.inappropriate", lang.localized("onboarding.concern.inappropriate")),
            ("onboarding.concern.mental", lang.localized("onboarding.concern.mental")),
            ("onboarding.concern.addiction", lang.localized("onboarding.concern.addiction")),
            ("onboarding.concern.scams", lang.localized("onboarding.concern.scams")),
        ]

        // Build a set of canonical keys that the user selected
        let selectedKeys: Set<String> = Set(
            canonicalKeys
                .filter { surveyData.parentConcerns.contains($0.localized) }
                .map { $0.key }
        )

        if selectedKeys.contains("onboarding.concern.cyberbullying") {
            preferences.discriminationHateSpeech = .block
        }
        if selectedKeys.contains("onboarding.concern.inappropriate") {
            preferences.graphicViolence = .block
            preferences.explicitSexual = .block
            preferences.matureContent = .block
        }
        if selectedKeys.contains("onboarding.concern.mental") {
            preferences.parasocialContent = .block
            preferences.beautyFilters = .block
        }
        if selectedKeys.contains("onboarding.concern.addiction") {
            preferences.shortFormVideos = .block
            preferences.gamingContent = .gate
        }
        if selectedKeys.contains("onboarding.concern.scams") {
            preferences.speculativeFinance = .block
            preferences.getRichQuick = .block
            preferences.subscriptionPages = .block
        }
        // Save updated preferences
        appState.contentFilterPreferences = preferences
    }
}

// MARK: - Supporting Components

struct SurveyProgressBar: View {
    let current: Int
    let total: Int
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                Rectangle()
                    .fill(KomalColors.lavenderPurple)
                    .frame(width: geometry.size.width * min(CGFloat(current) / CGFloat(max(total, 1)), 1.0), height: 4)
                    .cornerRadius(2)
                    .animation(.easeInOut(duration: 0.3), value: current)
            }
        }
        .frame(height: 4)
    }
}

struct SurveyHeader: View {
    let step: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text("common.step_of".localized(step))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(KomalColors.lavenderPurple)
                .tracking(1.5)
            
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)
            
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
    }
}

struct SurveyNavigation: View {
    let canGoBack: Bool
    let canGoNext: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            if canGoBack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("common.back".localized)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(KomalColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                    )
                }
            }
            
            Button(action: onNext) {
                HStack(spacing: 6) {
                    Text("common.continue".localized)
                        .font(.system(size: 16, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(canGoNext ? .white : Color.gray.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canGoNext ? KomalColors.lavenderPurple : Color.gray.opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(canGoNext ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(!canGoNext)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct InfoCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(KomalColors.textPrimary)
                
                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(KomalColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
}

struct GuidedAccessStepCard: View {
    let stepNumber: Int
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(KomalColors.lavenderPurple)
                    .frame(width: 32, height: 32)

                Text("\(stepNumber)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(KomalColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }
}

struct ResearchNote: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundColor(KomalColors.lavenderPurple)
            
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(KomalColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(KomalColors.lavenderPurple.opacity(0.08))
        .cornerRadius(10)
    }
}

struct AgeGroupButton: View {
    let group: AgeGroup
    let isSelected: Bool
    let onTap: () -> Void
    
    private var ageDescription: String {
        switch group {
        case .under10: return "onboarding.age.under10".localized
        case .tenToThirteen: return "onboarding.age.10to13".localized
        case .thirteenToSixteen: return "onboarding.age.13to16".localized
        case .sixteenToEighteen: return "onboarding.age.16to18".localized
        case .eighteenPlus: return "onboarding.age.18plus".localized
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSelected ? KomalColors.lavenderPurple : KomalColors.textPrimary)
                    
                    Text(ageDescription)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(KomalColors.textSecondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? KomalColors.lavenderPurple : Color.gray.opacity(0.45), lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(KomalColors.lavenderPurple)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(14)
            .background(isSelected ? KomalColors.lavenderPurple.opacity(0.08) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? KomalColors.lavenderPurple : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SelectableChip: View {
    let text: String
    let isSelected: Bool
    var color: Color = KomalColors.lavenderPurple
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : KomalColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? color : Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? color : Color.gray.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct InterestTile: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? KomalColors.lavenderPurple : KomalColors.textSecondary)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? KomalColors.lavenderPurple : KomalColors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(isSelected ? KomalColors.lavenderPurple.opacity(0.1) : Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? KomalColors.lavenderPurple : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ConcernRow: View {
    let title: String
    let icon: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? KomalColors.bubblegumPink : KomalColors.textSecondary)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(KomalColors.textPrimary)
                    
                    Text(description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(KomalColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? KomalColors.bubblegumPink : Color.gray.opacity(0.45))
            }
            .padding(14)
            .background(isSelected ? KomalColors.bubblegumPink.opacity(0.08) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? KomalColors.bubblegumPink : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SummaryItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(KomalColors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(KomalColors.textPrimary)
                .lineLimit(1)
        }
    }
}

struct FlowLayoutView<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    
    var body: some View {
        WrappingHStack(items: items, content: content)
    }
}

// Proper wrapping layout using ViewThatFits approach
struct WrappingHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    
    @State private var totalHeight: CGFloat = .zero
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 5)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { dimension in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geometry -> Color in
            DispatchQueue.main.async {
                binding.wrappedValue = geometry.size.height
            }
            return Color.clear
        }
    }
}

// MARK: - Category Settings Card (used by FilterPreferencesView)

struct CategorySettingsCard: View {
    let category: OnboardingCategory
    @Binding var preferences: ContentFilterPreferences
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(KomalColors.lavenderPurple)
                        .frame(width: 32)

                    Text(category.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(KomalColors.textSecondary)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(isExpanded ? 16 : 16)
            }
            .buttonStyle(.plain)

            // Items
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(category.items) { item in
                        CategoryItemRow(item: item, preferences: $preferences)

                        if item.id != category.items.last?.id {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(16)
                .padding(.top, -8)
            }
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 2)
    }
}

// MARK: - Category Item Row

struct CategoryItemRow: View {
    let item: OnboardingCategoryItem
    @Binding var preferences: ContentFilterPreferences

    private var currentAction: FilterAction {
        preferences[keyPath: item.keyPath]
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textPrimary)

                Text(item.description)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Action selector - Three-position slider
            FilterActionSlider(
                currentAction: currentAction,
                onActionChanged: { newAction in
                    preferences[keyPath: item.keyPath] = newAction
                }
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#if canImport(PreviewsMacros)
#Preview {
    PostAuthOnboardingView(onComplete: {})
        .environmentObject(AppState())
}
#endif
#endif

