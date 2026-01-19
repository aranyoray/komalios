//
//  FilterActionSlider.swift
//  Komalios
//
//  Button-based filter action selector (Block / Gate / Allow)
//

#if canImport(SwiftUI)
import SwiftUI

struct FilterActionSlider: View {
    let currentAction: FilterAction
    let onActionChanged: (FilterAction) -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            FilterActionButton(
                action: .block,
                isSelected: currentAction == .block,
                onTap: { onActionChanged(.block) }
            )
            
            FilterActionButton(
                action: .gate,
                isSelected: currentAction == .gate,
                onTap: { onActionChanged(.gate) }
            )
            
            FilterActionButton(
                action: .allow,
                isSelected: currentAction == .allow,
                onTap: { onActionChanged(.allow) }
            )
        }
    }
}

// MARK: - Individual Action Button
private struct FilterActionButton: View {
    let action: FilterAction
    let isSelected: Bool
    let onTap: () -> Void
    
    private var buttonColor: Color {
        switch action {
        case .block: return KomalColors.bubblegumPink
        case .gate: return Color.orange
        case .allow: return KomalColors.pearlAqua
        }
    }
    
    private var buttonIcon: String {
        switch action {
        case .block: return "xmark"
        case .gate: return "exclamationmark"
        case .allow: return "checkmark"
        }
    }
    
    private var buttonLabel: String {
        switch action {
        case .block: return "Block"
        case .gate: return "Gate"
        case .allow: return "Allow"
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: buttonIcon)
                    .font(.system(size: 10, weight: .bold))
                
                Text(buttonLabel)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
            }
            .frame(width: 40, height: 32)
            .foregroundColor(isSelected ? .white : buttonColor)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? buttonColor : buttonColor.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
