//
//  FilterActionSlider.swift
//  Komalios
//
//  Gradient slider filter action selector (Block / Gate / Allow)
//

#if canImport(SwiftUI)
import SwiftUI

struct FilterActionSlider: View {
    let currentAction: FilterAction
    let onActionChanged: (FilterAction) -> Void

    private static let trackWidth: CGFloat = 90
    private static let trackHeight: CGFloat = 3
    private static let dotSize: CGFloat = 20

    private let gradient = LinearGradient(
        colors: [.red, .orange, .green],
        startPoint: .leading,
        endPoint: .trailing
    )

    private func xOffset(for action: FilterAction) -> CGFloat {
        let usable = Self.trackWidth - Self.dotSize
        switch action {
        case .block: return 0
        case .gate:  return usable / 2
        case .allow: return usable
        }
    }

    private func color(for action: FilterAction) -> Color {
        switch action {
        case .block: return .red
        case .gate:  return .orange
        case .allow: return .green
        }
    }

    private func iconName(for action: FilterAction) -> String {
        switch action {
        case .block: return "xmark"
        case .gate:  return "exclamationmark"
        case .allow: return "checkmark"
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Smooth gradient line — no breaks
            Capsule()
                .fill(gradient)
                .frame(width: Self.trackWidth, height: Self.trackHeight)

            // Single sliding circle with icon — fully white
            ZStack {
                Circle()
                    .fill(color(for: currentAction))
                    .frame(width: Self.dotSize, height: Self.dotSize)

                Circle()
                    .fill(Color.white)
                    .frame(width: Self.dotSize - 4, height: Self.dotSize - 4)

                Image(systemName: iconName(for: currentAction))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
            .offset(x: xOffset(for: currentAction))
        }
        .frame(width: Self.trackWidth, height: Self.dotSize + 2)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let fraction = value.location.x / Self.trackWidth
                    let newAction: FilterAction
                    if fraction < 0.33 {
                        newAction = .block
                    } else if fraction < 0.66 {
                        newAction = .gate
                    } else {
                        newAction = .allow
                    }
                    if newAction != currentAction {
                        onActionChanged(newAction)
                    }
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentAction)
        .flipsForRightToLeftLayoutDirection(true)
    }
}
#endif
