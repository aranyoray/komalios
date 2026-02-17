#if os(iOS)
import SwiftUI

struct LanguageSelectorView: View {
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        lang.currentLanguage = language
                    }
                }) {
                    HStack {
                        Text("\(language.flag) \(language.nativeName)")
                        if lang.currentLanguage == language {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "globe")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(KomalColors.lavenderPurple)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
        }
    }
}
#endif
