#if os(iOS)
import SwiftUI

struct EmojiResponseView: View {
    let subcategory: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
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
        CSVEmojiMappingService.shared.emojisForSubcategory(sub)
    }
}
#endif
