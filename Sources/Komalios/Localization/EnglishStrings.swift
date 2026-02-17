#if os(iOS)
// swiftlint:disable file_length type_body_length
enum EnglishStrings {
    static let all: [String: String] = {
        var d = [String: String]()

        // MARK: - Common
        d["common.back"] = "Back"
        d["common.continue"] = "Continue"
        d["common.done"] = "Done"
        d["common.skip"] = "Skip"
        d["common.cancel"] = "Cancel"
        d["common.save"] = "Save"
        d["common.delete"] = "Delete"
        d["common.yes"] = "Yes"
        d["common.no"] = "No"
        d["common.ok"] = "OK"
        d["common.close"] = "Close"
        d["common.enter"] = "Enter"
        d["common.selected_count"] = "%d/%d selected"
        d["common.step_of"] = "STEP %@"

        // MARK: - Splash
        d["splash.title"] = "Komal"
        d["splash.tagline"] = "Your child's safe digital companion"

        // MARK: - Onboarding Welcome
        d["onboarding.welcome.title"] = "Child Safety Assessment"
        d["onboarding.welcome.subtitle"] = "Evidence-based digital wellbeing profile"
        d["onboarding.welcome.card1.title"] = "Developmental Psychology"
        d["onboarding.welcome.card1.desc"] = "Settings tailored to cognitive development stages as defined by child psychology research."
        d["onboarding.welcome.card2.title"] = "Behavioral Analysis"
        d["onboarding.welcome.card2.desc"] = "Understanding browsing patterns to create personalized safety boundaries."
        d["onboarding.welcome.card3.title"] = "Proactive Protection"
        d["onboarding.welcome.card3.desc"] = "Content filtering based on identified risk factors and preferences."
        d["onboarding.welcome.time_estimate"] = "This assessment takes approximately 3-4 minutes"
        d["onboarding.welcome.begin"] = "Begin Assessment"
        d["onboarding.welcome.language"] = "Language"

        // MARK: - Onboarding Child Info
        d["onboarding.info.step"] = "1 of 6"
        d["onboarding.info.title"] = "Basic Information"
        d["onboarding.info.subtitle"] = "Help us understand who we're protecting"
        d["onboarding.info.name_label"] = "Child's First Name"
        d["onboarding.info.name_placeholder"] = "Enter name"
        d["onboarding.info.age_label"] = "Age Group"
        d["onboarding.info.age_desc"] = "Content restrictions are calibrated based on developmental milestones"
        d["onboarding.info.research_note"] = "Research shows that age-appropriate content boundaries support healthy cognitive development and reduce anxiety in children."

        // Age group descriptions
        d["onboarding.age.under10"] = "Early childhood - Maximum protection"
        d["onboarding.age.10to13"] = "Pre-teen - Guided exploration"
        d["onboarding.age.13to16"] = "Teen - Balanced boundaries"
        d["onboarding.age.16to18"] = "Late teen - Age-appropriate freedom"
        d["onboarding.age.18plus"] = "Adult - Full access"

        // MARK: - Onboarding Websites
        d["onboarding.websites.step"] = "2 of 6"
        d["onboarding.websites.title"] = "Favorite Websites"
        d["onboarding.websites.subtitle"] = "Select up to 5 websites your child visits most"
        d["onboarding.websites.desc"] = "Understanding browsing habits helps us identify trusted sources and personalize protection."

        // MARK: - Onboarding Interests
        d["onboarding.interests.step"] = "3 of 6"
        d["onboarding.interests.title"] = "Topics of Interest"
        d["onboarding.interests.subtitle"] = "What does your child enjoy learning about?"
        d["onboarding.interests.desc"] = "Select 3-5 topics. This helps us understand what content to prioritize and protect."

        // Interest names
        d["onboarding.interest.gaming"] = "Gaming"
        d["onboarding.interest.animals"] = "Animals"
        d["onboarding.interest.science"] = "Science"
        d["onboarding.interest.art"] = "Art & Drawing"
        d["onboarding.interest.music"] = "Music"
        d["onboarding.interest.sports"] = "Sports"
        d["onboarding.interest.coding"] = "Coding"
        d["onboarding.interest.reading"] = "Reading"
        d["onboarding.interest.cooking"] = "Cooking"
        d["onboarding.interest.nature"] = "Nature"
        d["onboarding.interest.space"] = "Space"
        d["onboarding.interest.history"] = "History"
        d["onboarding.interest.movies"] = "Movies"
        d["onboarding.interest.crafts"] = "Crafts"
        d["onboarding.interest.dinosaurs"] = "Dinosaurs"
        d["onboarding.interest.vehicles"] = "Vehicles"
        d["onboarding.interest.fashion"] = "Fashion"
        d["onboarding.interest.dance"] = "Dance"

        // MARK: - Onboarding Likes
        d["onboarding.likes.step"] = "4 of 6"
        d["onboarding.likes.title"] = "What They Enjoy Online"
        d["onboarding.likes.subtitle"] = "Understanding positive online experiences"
        d["onboarding.likes.desc"] = "Select activities your child enjoys. This helps us ensure they have access to enriching content."
        d["onboarding.likes.other"] = "Other (optional)"
        d["onboarding.likes.other_placeholder"] = "Add something else they enjoy..."

        // Like options
        d["onboarding.like.watching_videos"] = "Watching videos"
        d["onboarding.like.playing_games"] = "Playing games"
        d["onboarding.like.chatting"] = "Chatting with friends"
        d["onboarding.like.learning"] = "Learning new things"
        d["onboarding.like.creative"] = "Creative projects"
        d["onboarding.like.exploring"] = "Exploring websites"
        d["onboarding.like.music"] = "Listening to music"
        d["onboarding.like.virtual_worlds"] = "Virtual worlds"
        d["onboarding.like.puzzles"] = "Puzzles & challenges"
        d["onboarding.like.funny"] = "Funny content"
        d["onboarding.like.stories"] = "Stories & books"
        d["onboarding.like.making_videos"] = "Making videos"

        // MARK: - Onboarding Dislikes
        d["onboarding.dislikes.step"] = "5 of 6"
        d["onboarding.dislikes.title"] = "What Bothers Them"
        d["onboarding.dislikes.subtitle"] = "Identifying triggers and discomforts"
        d["onboarding.dislikes.desc"] = "Select things that upset or concern your child online. This helps us filter potentially distressing content."
        d["onboarding.dislikes.other"] = "Other concerns (optional)"
        d["onboarding.dislikes.other_placeholder"] = "Add other things that bother them..."
        d["onboarding.dislikes.research_note"] = "Understanding what distresses children online allows us to proactively filter content before exposure, reducing anxiety and negative experiences."

        // Dislike options
        d["onboarding.dislike.scary"] = "Scary content"
        d["onboarding.dislike.loud"] = "Loud noises/jumpscares"
        d["onboarding.dislike.mean"] = "Mean comments"
        d["onboarding.dislike.strangers"] = "Strangers messaging"
        d["onboarding.dislike.violent"] = "Violent games"
        d["onboarding.dislike.sad"] = "Sad stories"
        d["onboarding.dislike.ads"] = "Confusing ads"
        d["onboarding.dislike.reading"] = "Too much reading"
        d["onboarding.dislike.timed"] = "Timed challenges"
        d["onboarding.dislike.losing"] = "Losing in games"
        d["onboarding.dislike.popups"] = "Pop-up videos"
        d["onboarding.dislike.rushed"] = "Being rushed"

        // MARK: - Onboarding Concerns
        d["onboarding.concerns.step"] = "6 of 8"
        d["onboarding.concerns.title"] = "Your Concerns"
        d["onboarding.concerns.subtitle"] = "What worries you most about your child online?"
        d["onboarding.concerns.desc"] = "Select your top concerns. We'll prioritize protection in these areas."

        // Concern items
        d["onboarding.concern.cyberbullying"] = "Cyberbullying"
        d["onboarding.concern.cyberbullying.desc"] = "Harassment, mean messages, exclusion"
        d["onboarding.concern.inappropriate"] = "Inappropriate Content"
        d["onboarding.concern.inappropriate.desc"] = "Violence, mature themes, explicit material"
        d["onboarding.concern.predators"] = "Online Predators"
        d["onboarding.concern.predators.desc"] = "Strangers, grooming, personal info requests"
        d["onboarding.concern.addiction"] = "Screen Addiction"
        d["onboarding.concern.addiction.desc"] = "Excessive use, difficulty stopping"
        d["onboarding.concern.privacy"] = "Privacy Risks"
        d["onboarding.concern.privacy.desc"] = "Data collection, location sharing"
        d["onboarding.concern.misinfo"] = "Misinformation"
        d["onboarding.concern.misinfo.desc"] = "Fake news, conspiracy theories"
        d["onboarding.concern.scams"] = "Financial Scams"
        d["onboarding.concern.scams.desc"] = "In-app purchases, phishing"
        d["onboarding.concern.mental"] = "Mental Health"
        d["onboarding.concern.mental.desc"] = "Anxiety, comparison, FOMO"

        // MARK: - Onboarding Filters
        d["onboarding.filters.step"] = "7 of 8"
        d["onboarding.filters.title"] = "Content Filters"
        d["onboarding.filters.subtitle"] = "Review and customize content filtering"
        d["onboarding.filters.desc"] = "These defaults are based on your child's age and your concerns. Adjust any setting below."

        // MARK: - Onboarding PIN
        d["onboarding.pin.step"] = "8 of 8"
        d["onboarding.pin.title"] = "Set Parent PIN"
        d["onboarding.pin.subtitle"] = "Create a PIN to protect parent settings"
        d["onboarding.pin.desc"] = "This PIN will be required to access parent mode and approve gated content."
        d["onboarding.pin.enter"] = "Enter PIN"
        d["onboarding.pin.placeholder"] = "4-digit PIN"
        d["onboarding.pin.confirm"] = "Confirm PIN"
        d["onboarding.pin.confirm_placeholder"] = "Confirm PIN"
        d["onboarding.pin.mismatch"] = "PINs do not match. Please try again."
        d["onboarding.pin.enable_biometric"] = "Enable %@"
        d["onboarding.pin.use_biometric"] = "Use %@ instead of PIN"
        d["onboarding.pin.research_note"] = "A parent PIN ensures only authorized adults can modify safety settings and approve gated content."

        // MARK: - Onboarding Completion
        d["onboarding.complete.title"] = "Profile Complete"
        d["onboarding.complete.subtitle"] = "%@'s safety profile is ready"
        d["onboarding.complete.summary"] = "Assessment Summary"
        d["onboarding.complete.name"] = "Name"
        d["onboarding.complete.age_group"] = "Age Group"
        d["onboarding.complete.interests"] = "Interests"
        d["onboarding.complete.concerns"] = "Key Concerns"
        d["onboarding.complete.adjust_note"] = "Settings can be adjusted anytime in the app"
        d["onboarding.complete.start"] = "Start Using Komal"
        d["onboarding.complete.review"] = "Review Answers"

        // MARK: - Menu / Navigation
        d["menu.browse"] = "Browse"
        d["menu.talk"] = "Talk"
        d["menu.reflect"] = "Reflect"
        d["menu.settings"] = "Settings"

        // MARK: - Settings
        d["settings.title"] = "Settings"
        d["settings.whos_using"] = "Who's Using?"
        d["settings.whos_using.desc"] = "Select who is currently using the device"
        d["settings.child"] = "Child"
        d["settings.child.subtitle"] = "Safe browsing"
        d["settings.parent"] = "Parent"
        d["settings.parent.subtitle"] = "Full access"

        // Settings - Child Mode
        d["settings.child.greeting"] = "Hi %@!"
        d["settings.child.greeting_default"] = "Hi there!"
        d["settings.child.safe_msg"] = "Komal is here to keep you safe while you explore!"
        d["settings.child.chatty"] = "Feeling Chatty?"
        d["settings.child.chatty.desc"] = "Talk to Riki! Your friendly companion is always here to chat and help you out."
        d["settings.child.go_talk"] = "Go to Talk"
        d["settings.child.profile"] = "Your Profile"
        d["settings.child.explorer"] = "Explorer"
        d["settings.child.age"] = "Age: %@"
        d["settings.child.journey"] = "My Journey"
        d["settings.child.day_streak"] = "Day Streak"
        d["settings.child.milestones"] = "Milestones"
        d["settings.child.view_journey"] = "View My Journey"

        // Settings - Parent Mode
        d["settings.parent.digital_journey"] = "Digital Journey"
        d["settings.parent.view_journey"] = "View Digital Journey"
        d["settings.parent.journey_desc"] = "See your child's browsing activity with AI insights"
        d["settings.parent.wellness"] = "Child Wellness"
        d["settings.parent.wellness_dashboard"] = "Wellness Dashboard"
        d["settings.parent.wellness_desc"] = "Mood trends, conversations, growth metrics"
        d["settings.parent.morning_checkin"] = "Morning Check-in"
        d["settings.parent.morning_desc"] = "Daily morning mood anchor"
        d["settings.parent.evening_winddown"] = "Evening Wind-down"
        d["settings.parent.evening_desc"] = "Daily evening reflection anchor"
        d["settings.parent.child_profile"] = "Child Profile"
        d["settings.parent.name_label"] = "Name"
        d["settings.parent.name_placeholder"] = "Child's Name"
        d["settings.parent.age_label"] = "Age Group"
        d["settings.parent.controls"] = "Parent Controls"
        d["settings.parent.notify_block"] = "Notify on Block"
        d["settings.parent.notify_desc"] = "Get alerts when blocked content is accessed"
        d["settings.parent.safe_search"] = "Force Safe Search"
        d["settings.parent.safe_search_desc"] = "Enforce strict safety on search engines"
        d["settings.parent.view_insights"] = "View Insights"
        d["settings.parent.insights_desc"] = "See browsing activity and blocked content"
        d["settings.parent.modify_content"] = "Modify Content"
        d["settings.parent.modify_filters"] = "Modify Filters"
        d["settings.parent.custom_keywords"] = "Custom Keywords"
        d["settings.parent.add_keyword"] = "Add keyword (e.g. 'weapons')"
        d["settings.parent.no_keywords"] = "No custom keywords added yet."
        d["settings.parent.custom_websites"] = "Custom Websites"
        d["settings.parent.add_website"] = "Add website (e.g. 'badsite.com')"
        d["settings.parent.no_websites"] = "No custom websites added yet."

        // Settings - Account
        d["settings.account"] = "Account"
        d["settings.account.guest"] = "Using as Guest"
        d["settings.account.guest_desc"] = "Your data is stored locally on this device only. Sign in to sync across devices."
        d["settings.account.sign_in"] = "Sign In"
        d["settings.account.exit_guest"] = "Exit Guest Mode"
        d["settings.account.delete"] = "Delete Account"
        d["settings.account.logout"] = "Logout"
        d["settings.account.login"] = "Login"
        d["settings.account.sync_desc"] = "Sign in to sync your preferences across devices"

        // Settings - Alerts
        d["settings.alert.logout.title"] = "Logout"
        d["settings.alert.logout.message"] = "Do you want to logout?"
        d["settings.alert.delete.title"] = "Delete Account"
        d["settings.alert.delete.message"] = "Are You Sure to delete account? This action cannot be undone."

        // Settings - PIN Entry
        d["settings.pin.title"] = "Enter Parent PIN"
        d["settings.pin.subtitle"] = "Enter your 4-digit PIN to access parent settings"
        d["settings.pin.placeholder"] = "PIN"
        d["settings.pin.error"] = "Incorrect PIN. Try again."
        d["settings.pin.biometric"] = "Use %@"

        // MARK: - Riki / Talk
        d["riki.choose_friend"] = "Choose a Friend"
        d["riki.who_chat"] = "Who would you like to chat with?"
        d["riki.typing"] = "Typing..."
        d["riki.online"] = "Online"
        d["riki.listening"] = "Listening..."
        d["riki.tap_send"] = "Tap to send"
        d["riki.tap_talk"] = "Tap to talk"
        d["riki.speaking"] = "%@ is speaking..."
        d["riki.error_fallback"] = "Oops! I got a little confused there. Can you try saying that again?"

        // Character greetings
        d["riki.greeting.momo"] = "Hey friend! I'm Momo. What's on your mind today?"
        d["riki.greeting.goldie"] = "Hey there! I'm Goldie, and I'm so happy to see you! What should we talk about?"
        d["riki.greeting.oreo"] = "Hello! I'm Oreo. Ready for a fun chat?"
        d["riki.greeting.leo"] = "Hey! I'm Leo. Tell me something brave about your day!"
        d["riki.greeting.bunny"] = "Hi there! I'm Bunny. What fun things have you been up to?"
        d["riki.greeting.tiki"] = "Hey! I'm Tiki. What adventure shall we go on today?"
        d["riki.greeting.fluffy"] = "Hi! I'm Fluffy. Come sit with me and let's have a cozy chat!"
        d["riki.greeting.kitty"] = "Hey! I'm Kitty. I've been napping and now I'm ready to chat!"
        d["riki.greeting.panda"] = "Hi there! I'm Panda. Want to hang out and chat for a bit?"
        d["riki.greeting.ellie"] = "Hey! I'm Ellie. I never forget my friends! What's new with you?"
        d["riki.greeting.ducky"] = "Hey! I'm Ducky. Let's make today a good one — what's going on?"

        // Character personalities
        d["riki.personality.momo"] = "A playful, curious monkey who loves climbing trees and exploring. Energetic and fun, loves jokes and riddles. Talks like a real buddy who's always up for an adventure."
        d["riki.personality.goldie"] = "A loyal, enthusiastic golden retriever. Loves playing fetch, going on walks, and making friends happy. Super supportive, always excited to hear what's going on in your life."
        d["riki.personality.oreo"] = "A clever, friendly monkey who loves puzzles and learning new things. Thoughtful and encouraging, great at helping you think through tricky stuff."
        d["riki.personality.leo"] = "A brave, kind lion who leads with courage. Encourages you to be brave, try new things, and believe in yourself. Warm and protective, like a big brother."
        d["riki.personality.bunny"] = "A gentle, sweet bunny who loves gardens, nature, and cozy things. A calming presence who's really good at listening and understanding how you feel."
        d["riki.personality.tiki"] = "An adventurous tiger who loves exploring and discovering new things. Brave but gentle, loves telling stories about nature and faraway places."
        d["riki.personality.fluffy"] = "A soft, warm-hearted sheep who loves comfort and kindness. Very gentle and calming, great at helping you with feelings and worries. Like a best friend who always makes you feel better."
        d["riki.personality.kitty"] = "A curious, independent cat who loves cozy spots and being playful. Witty and fun, sometimes a little cheeky but always kind at heart."
        d["riki.personality.panda"] = "A chill, lovable panda who enjoys taking it easy and being silly. Laid-back and funny, always knows how to make you laugh with goofy comments."
        d["riki.personality.ellie"] = "A wise, caring elephant with a great memory. Thoughtful and nurturing, loves sharing fun facts and helping you learn new things. Like a really smart friend who makes learning feel easy."
        d["riki.personality.ducky"] = "A cheerful, bubbly duck who loves being upbeat and positive. Great at cheering you up when things feel tough, always finds the bright side."

        // MARK: - Reflection
        d["reflect.title"] = "Reflection Time"
        d["reflect.how_feeling"] = "How are you feeling right now?"
        d["reflect.select_emotion"] = "Select an emotion to begin"
        d["reflect.session.title"] = "Guided Reflection"
        d["reflect.session.breathe"] = "Let's take a deep breath together"
        d["reflect.session.think_about"] = "Think about..."
        d["reflect.session.complete"] = "Great reflection!"
        d["reflect.session.done"] = "You did great! Remember, it's okay to feel any emotion."
        d["reflect.coping.title"] = "Coping Strategies"
        d["reflect.coping.try_this"] = "Try this:"

        // Emotions
        d["reflect.emotion.happy"] = "Happy"
        d["reflect.emotion.sad"] = "Sad"
        d["reflect.emotion.angry"] = "Angry"
        d["reflect.emotion.scared"] = "Scared"
        d["reflect.emotion.worried"] = "Worried"
        d["reflect.emotion.calm"] = "Calm"
        d["reflect.emotion.excited"] = "Excited"
        d["reflect.emotion.confused"] = "Confused"
        d["reflect.emotion.tired"] = "Tired"
        d["reflect.emotion.lonely"] = "Lonely"
        d["reflect.emotion.grateful"] = "Grateful"
        d["reflect.emotion.frustrated"] = "Frustrated"

        // Reflection exercises
        d["reflect.exercise.gratitude"] = "Name 3 things you're grateful for today"
        d["reflect.exercise.breathing"] = "Deep Breathing"
        d["reflect.exercise.body_scan"] = "Body Scan"
        d["reflect.exercise.journaling"] = "Write about your feelings"

        // Coping strategies
        d["reflect.coping.deep_breath"] = "Take 5 deep breaths"
        d["reflect.coping.talk"] = "Talk to someone you trust"
        d["reflect.coping.move"] = "Go for a walk or stretch"
        d["reflect.coping.create"] = "Draw or write about how you feel"
        d["reflect.coping.music"] = "Listen to your favorite music"
        d["reflect.coping.count"] = "Count backwards from 10"

        // MARK: - Browser
        d["browser.address_placeholder"] = "Search or enter URL"
        d["browser.loading"] = "Loading..."
        d["browser.new_tab"] = "New Tab"
        d["browser.tabs"] = "Tabs"
        d["browser.close_tab"] = "Close Tab"
        d["browser.menu"] = "Menu"
        d["browser.share"] = "Share"
        d["browser.reload"] = "Reload"
        d["browser.forward"] = "Forward"
        d["browser.history"] = "History"
        d["browser.homepage"] = "Homepage"

        // MARK: - Blocked Content
        d["blocked.title"] = "Content Blocked"
        d["blocked.message"] = "This page has been blocked for your safety."
        d["blocked.reason"] = "Reason: %@"
        d["blocked.ask_parent"] = "Ask a parent to allow this"
        d["blocked.go_back"] = "Go Back"
        d["blocked.countdown"] = "Going back in %d..."
        d["blocked.emoji_prompt"] = "How does this make you feel?"

        // MARK: - Gate (parent approval)
        d["gate.title"] = "Parent Approval Needed"
        d["gate.message"] = "This content needs parent approval to access."
        d["gate.enter_pin"] = "Enter parent PIN to continue"

        // MARK: - Emoji Check-in
        d["checkin.how_feeling"] = "How're you feeling exploring this?"
        d["checkin.how_are_you"] = "How are you feeling?"

        // MARK: - Anchor - Morning
        d["anchor.morning.title"] = "Good Morning!"
        d["anchor.morning.subtitle"] = "How are you feeling this morning?"
        d["anchor.morning.set_intention"] = "Set your intention for today"
        d["anchor.morning.intention_placeholder"] = "Today I want to..."
        d["anchor.morning.ready"] = "I'm ready for today!"

        // MARK: - Anchor - Evening
        d["anchor.evening.title"] = "Evening Reflection"
        d["anchor.evening.subtitle"] = "How was your day?"
        d["anchor.evening.best_part"] = "What was the best part of your day?"
        d["anchor.evening.best_placeholder"] = "The best part was..."
        d["anchor.evening.learned"] = "What did you learn today?"
        d["anchor.evening.learned_placeholder"] = "I learned..."
        d["anchor.evening.goodnight"] = "Goodnight!"

        // MARK: - Reconnection
        d["reconnection.title"] = "Welcome Back!"
        d["reconnection.subtitle"] = "We missed you! It's been a while."
        d["reconnection.whats_new"] = "Here's what's new since you were away"
        d["reconnection.lets_go"] = "Let's Go!"
        d["reconnection.missed_days"] = "You've been away for %d days"

        // MARK: - Growth / Journey
        d["growth.title"] = "Growth Journey"
        d["growth.milestones"] = "Milestones"
        d["growth.weekly_snapshot"] = "Weekly Snapshot"
        d["growth.streak"] = "Streak"
        d["growth.days"] = "days"
        d["growth.level"] = "Level"
        d["growth.explorer"] = "Explorer"
        d["growth.adventurer"] = "Adventurer"
        d["growth.champion"] = "Champion"
        d["growth.legend"] = "Legend"
        d["growth.earned"] = "Earned!"
        d["growth.locked"] = "Keep going!"
        d["growth.snapshot.conversations"] = "Conversations"
        d["growth.snapshot.reflections"] = "Reflections"
        d["growth.snapshot.browsing_time"] = "Browsing Time"
        d["growth.snapshot.mood_checks"] = "Mood Checks"

        // MARK: - Digital Journey
        d["journey.title"] = "Digital Journey"
        d["journey.ai_insights"] = "AI Insights"
        d["journey.history"] = "History"
        d["journey.no_activity"] = "No activity recorded yet"
        d["journey.time_spent"] = "Time Spent"
        d["journey.sites_visited"] = "Sites Visited"
        d["journey.blocked_attempts"] = "Blocked Attempts"

        // MARK: - Parent Insights
        d["insights.title"] = "Parent Insights"
        d["insights.wellness"] = "Wellness Overview"
        d["insights.mood_trends"] = "Mood Trends"
        d["insights.chat_activity"] = "Chat Activity"
        d["insights.browsing_summary"] = "Browsing Summary"
        d["insights.alerts"] = "Alerts"
        d["insights.no_alerts"] = "No alerts to show"
        d["insights.this_week"] = "This Week"
        d["insights.this_month"] = "This Month"

        // MARK: - Browsing History
        d["history.title"] = "Browsing History"
        d["history.today"] = "Today"
        d["history.yesterday"] = "Yesterday"
        d["history.earlier"] = "Earlier"
        d["history.no_history"] = "No browsing history yet"
        d["history.clear"] = "Clear History"
        d["history.clear_confirm"] = "Are you sure you want to clear all browsing history?"

        // MARK: - Contextual Prompts
        d["prompt.welcome_back"] = "Welcome back! Ready to explore?"
        d["prompt.take_break"] = "You've been browsing for a while. Take a break?"
        d["prompt.try_reflect"] = "How about checking in with your feelings?"
        d["prompt.chat_riki"] = "Want to chat with a friend?"
        d["prompt.new_milestone"] = "You earned a new milestone!"
        d["prompt.dismiss"] = "Maybe later"
        d["prompt.lets_go"] = "Let's go!"

        // MARK: - Notifications
        d["notification.morning.title"] = "Good Morning!"
        d["notification.morning.body"] = "Start your day with a morning check-in"
        d["notification.evening.title"] = "Evening Time"
        d["notification.evening.body"] = "Wind down with an evening reflection"
        d["notification.reconnect.title"] = "We miss you!"
        d["notification.reconnect.body"] = "Your friends are waiting to chat with you"
        d["notification.milestone.title"] = "New Milestone!"
        d["notification.milestone.body"] = "You've earned a new achievement. Check it out!"

        // MARK: - Mood History
        d["mood.history.title"] = "Mood History"
        d["mood.history.recent"] = "Recent Moods"
        d["mood.history.no_entries"] = "No mood entries yet"
        d["mood.history.trend"] = "Your mood trend"

        // MARK: - Screen Time
        d["screentime.minimal"] = "30 min/day"
        d["screentime.moderate"] = "1-2 hours/day"
        d["screentime.flexible"] = "Flexible"

        return d
    }()
}
// swiftlint:enable file_length type_body_length
#endif
