#if os(iOS)
import SwiftUI

struct EmojiResponseView: View {
    let subcategory: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("How are you feeling?")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            HStack(spacing: 16) {
                ForEach(EmojiMapper.emojisForSubcategory(subcategory), id: \.self) { emoji in
                    Button { onSelect(emoji) } label: { Text(emoji).font(.system(size: 36)) }
                        .buttonStyle(ScaleButtonStyle())
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white).shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4))
    }
}

enum EmojiMapper {
    static func emojisForSubcategory(_ sub: String) -> [String] {
        let s = sub.lowercased()
        if s.contains("violen") || s.contains("weapon")     { return ["😨", "😟", "😔", "👍", "😌"] }
        if s.contains("bully") || s.contains("harass")      { return ["😢", "😡", "😞", "🤗", "💪"] }
        if s.contains("sexual") || s.contains("explicit")   { return ["😳", "😖", "😟", "👍", "😊"] }
        if s.contains("drug") || s.contains("alcohol")      { return ["🤔", "😟", "😞", "👍", "💪"] }
        if s.contains("scam") || s.contains("gambling")     { return ["🤔", "😒", "😟", "👍", "😊"] }
        if s.contains("horror") || s.contains("scary")      { return ["😱", "😨", "😟", "😌", "💪"] }
        if s.contains("parasocial") || s.contains("influencer") { return ["🤔", "😐", "😊", "👍", "😎"] }
        return ["😊", "🤔", "😟", "😢", "👍"]
    }
}
#endif
