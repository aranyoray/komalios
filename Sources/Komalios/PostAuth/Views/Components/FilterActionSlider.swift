//
//  FilterActionSlider.swift
//  Komalios
//
//  Created on 18/01/26.
//

#if canImport(SwiftUI)
import SwiftUI

struct FilterActionSlider: View {
    let currentAction: FilterAction
    let onActionChanged: (FilterAction) -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    private let sliderWidth: CGFloat = 120
    private let thumbSize: CGFloat = 28
    
    // Calculate equal segment width (3 equal parts)
    private var segmentWidth: CGFloat {
        sliderWidth / 3
    }
    
    private var basePosition: CGFloat {
        switch currentAction {
        case .block: return 0 // Start of pink (Block) segment
        case .gate: return segmentWidth // Start of orange (Gate) segment
        case .allow: return segmentWidth * 2 // Start of aqua (Allow) segment
        }
    }
    
    private var thumbPosition: CGFloat {
        basePosition + dragOffset
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background track with equal parts of each color
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: KomalColors.bubblegumPink, location: 0.0),
                            .init(color: KomalColors.bubblegumPink, location: 0.333),
                            .init(color: Color.orange, location: 0.333),
                            .init(color: Color.orange, location: 0.666),
                            .init(color: KomalColors.pearlAqua, location: 0.666),
                            .init(color: KomalColors.pearlAqua, location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: sliderWidth, height: 8)
                .cornerRadius(4)
            
            // Thumb
            Circle()
                .fill(Color.white)
                .frame(width: thumbSize, height: thumbSize)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                .overlay(
                    Circle()
                        .stroke(getColorForAction(currentAction), lineWidth: 3)
                )
                .overlay(
                    Image(systemName: getIconForAction(currentAction))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(getColorForAction(currentAction))
                )
                .offset(x: thumbPosition - thumbSize / 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let newOffset = value.translation.width
                            // Clamp the offset to keep thumb within bounds
                            let minOffset = -basePosition // Allow dragging back to start (0)
                            let maxOffset = sliderWidth - basePosition - thumbSize // Allow dragging to end
                            dragOffset = max(minOffset, min(maxOffset, newOffset))
                        }
                        .onEnded { value in
                            isDragging = false
                            
                            // If drag distance is very small, treat as tap
                            if abs(value.translation.width) < 5 && abs(value.translation.height) < 5 {
                                // Tap detected - move to next action
                                let nextAction = getNextAction()
                                onActionChanged(nextAction)
                            } else {
                                // Actual drag - snap to nearest position
                                let totalPosition = basePosition + dragOffset
                                let newAction = snapToAction(position: totalPosition)
                                
                                // Only update if action changed
                                if newAction != currentAction {
                                    onActionChanged(newAction)
                                }
                            }
                            
                            // Animate to final position
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            // Only handle tap if not dragging
                            if !isDragging {
                                let nextAction = getNextAction()
                                onActionChanged(nextAction)
                            }
                        }
                )
        }
        .frame(width: sliderWidth, height: thumbSize)
    }
    
    private func snapToAction(position: CGFloat) -> FilterAction {
        // Determine which segment the thumb is in based on position
        // Snap to the start of each color segment (equal parts)
        let segmentWidth = sliderWidth / 3
        if position < segmentWidth {
            return .block
        } else if position < segmentWidth * 2 {
            return .gate
        } else {
            return .allow
        }
    }
    
    private func getColorForAction(_ action: FilterAction) -> Color {
        switch action {
        case .block: return KomalColors.bubblegumPink
        case .gate: return Color.orange
        case .allow: return KomalColors.pearlAqua
        }
    }
    
    private func getIconForAction(_ action: FilterAction) -> String {
        switch action {
        case .block: return "xmark"
        case .gate: return "exclamationmark"
        case .allow: return "checkmark"
        }
    }
    
    private func getNextAction() -> FilterAction {
        // Cycle through: Block → Gate → Allow → Block
        switch currentAction {
        case .block: return .gate
        case .gate: return .allow
        case .allow: return .block
        }
    }
}
#endif
