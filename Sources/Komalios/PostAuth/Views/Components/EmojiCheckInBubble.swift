#if os(iOS)
import SwiftUI

struct EmojiCheckInBubble: View {
    let onEmojiSelected: (String) -> Void
    let avatarIndex: Int
    @State private var isExpanded = true

    private let emojis: [String]

    private var selectedAvatar: String {
        "animal\(avatarIndex)"
    }

    init(subcategory: String = "", avatarIndex: Int = 1, onEmojiSelected: @escaping (String) -> Void) {
        self.onEmojiSelected = onEmojiSelected
        self.avatarIndex = avatarIndex
        self.emojis = EmojiMapper.emojisForSubcategory(subcategory)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if isExpanded {
                VStack(spacing: 10) {
                    Text(LanguageManager.shared.localized("checkin.how_are_you"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)

                    HStack(spacing: 12) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button {
                                withAnimation(KomalAnimations.spring) { isExpanded = false }
                                onEmojiSelected(emoji)
                            } label: {
                                Text(emoji).font(.system(size: 30))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.white)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .transition(.scale(scale: 0.5, anchor: .bottomTrailing).combined(with: .opacity))
            }

            Button {
                withAnimation(KomalAnimations.spring) { isExpanded.toggle() }
            } label: {
                if let uiImage = UIImage(named: selectedAvatar) {
                    Image(uiImage: uiImage).resizable().aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56).clipShape(Circle())
                        .overlay(Circle().stroke(KomalColors.bubblegumPink, lineWidth: 3))
                        .shadow(color: KomalColors.bubblegumPink.opacity(0.3), radius: 6, x: 0, y: 3)
                } else {
                    Image(systemName: "pawprint.fill").font(.system(size: 28)).foregroundColor(.white)
                        .frame(width: 56, height: 56).background(Circle().fill(KomalColors.bubblegumPink))
                }
            }
            .scaleEffect(isExpanded ? 1.1 : 1.0)
            .animation(KomalAnimations.spring, value: isExpanded)
        }
        .padding(.trailing, 16).padding(.bottom, 64)
    }
}
#endif
