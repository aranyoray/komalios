#if canImport(SwiftUI)
import SwiftUI

// MARK: - Color Palette

struct KomalColors {
    // Primary Colors - New Palette
    static let white = Color(hex: "FCFCFC")          // White
    static let bubblegumPink = Color(hex: "F7567C")  // Bubblegum Pink
    static let lavenderPurple = Color(hex: "8269ff") // Lavender Purple
    static let pearlAqua = Color(hex: "99E1D9")      // Pearl Aqua (cool teal)

    // Semantic Colors
    static let primary = bubblegumPink       // Primary actions, focus
    static let secondary = pearlAqua         // Secondary actions, calm
    static let accent = lavenderPurple       // Cool backgrounds, highlights

    // Backgrounds
    static let background = Color(hex: "F8F8FC")  // Very light lavender tint
    static let surface = lavenderPurple
    static let warmGray = Color(hex: "F5F5F5")

    // Success/Safe indicators
    static let success = pearlAqua
    static let successGreen = pearlAqua

    // Info and gentle alerts
    static let info = pearlAqua
    static let gentleBlue = pearlAqua
    static let softPink = bubblegumPink

    // Functional
    static let textPrimary = Color(hex: "2C3E50")
    static let textSecondary = Color(hex: "7F8C8D")

    // Legacy names for compatibility
    static let yellow = lavenderPurple
    static let violet = bubblegumPink
    static let softWhite = white
    static let pastelYellowLight = lavenderPurple
    static let pastelVioletLight = bubblegumPink
    static let pastelVioletDark = bubblegumPink
    static let cornsilk = lavenderPurple  // Alias for backward compatibility
}

// MARK: - Animations

struct KomalAnimations {
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.7)
    static let gentle = Animation.easeInOut(duration: 0.3)
    static let subtle = Animation.easeInOut(duration: 0.2)
}

// MARK: - Shadows

struct KomalShadows {
    static let soft = Shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    static let card = Shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Custom Button Styles

struct PillButtonStyle: ButtonStyle {
    var backgroundColor: Color = KomalColors.bubblegumPink
    var foregroundColor: Color = KomalColors.white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(KomalAnimations.subtle, value: configuration.isPressed)
    }
}

struct SecondaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(KomalColors.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(KomalColors.pearlAqua.opacity(0.5))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(KomalAnimations.subtle, value: configuration.isPressed)
    }
}

// MARK: - Bubbly Card

struct BubblyCard<Content: View>: View {
    let content: Content
    var backgroundColor: Color = .white
    var tintColor: Color? = nil

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    init(backgroundColor: Color, @ViewBuilder content: () -> Content) {
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    init(tintColor: Color, @ViewBuilder content: () -> Content) {
        self.backgroundColor = .white
        self.tintColor = tintColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(tintColor != nil ? tintColor!.opacity(0.15) : backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - Rounded Text Field Style

struct RoundedTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(KomalColors.lavenderPurple.opacity(0.2))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(KomalColors.bubblegumPink, lineWidth: 2)
            )
    }
}

extension View {
    func roundedTextFieldStyle() -> some View {
        modifier(RoundedTextFieldStyle())
    }
}

// MARK: - Background

struct GradientBackground: View {
    var backgroundColor: Color = KomalColors.background

    var body: some View {
        backgroundColor
            .ignoresSafeArea()
    }
}

// MARK: - Section Header

struct SectionHeaderView: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(KomalColors.bubblegumPink)

            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(KomalColors.textPrimary)

            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Animated Icon

struct AnimatedIcon: View {
    let systemName: String
    let size: CGFloat
    let color: Color
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(color)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                ) {
                    scale = 1.05
                }
            }
    }
}

// MARK: - Breathing Circle (for Riki)

struct BreathingCircle: View {
    let size: CGFloat
    let color: Color
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true)
                ) {
                    scale = 1.1
                }
            }
    }
}

// MARK: - Loading Indicator

struct PlayfulLoadingView: View {
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(KomalColors.pearlAqua.opacity(0.3), lineWidth: 4)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(KomalColors.bubblegumPink, lineWidth: 4)
                    .frame(width: 50, height: 50)
                    .rotationEffect(Angle(degrees: rotation))
            }

            Text("Scanning for safe browsing...")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(KomalColors.textSecondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .onAppear {
            withAnimation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? KomalColors.bubblegumPink : KomalColors.lavenderPurple.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .scaleEffect(index == currentStep ? 1.2 : 1.0)
                    .animation(KomalAnimations.spring, value: currentStep)
            }
        }
    }
}

// MARK: - Color Extension (Hex Support)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - LinearGradient Extension
// Note: LinearGradient properties are not directly accessible in iOS 16

#endif
