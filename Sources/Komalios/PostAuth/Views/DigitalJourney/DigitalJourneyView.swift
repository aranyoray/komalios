//
//  DigitalJourneyView.swift
//  Komalios
//
//  Parent-facing view showing child's browsing history with AI-powered grouping
//

#if os(iOS)
import SwiftUI

struct DigitalJourneyView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = DigitalJourneyViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                KomalColors.warmGray
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Analyzing browsing activity...")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                } else if viewModel.allItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "globe")
                            .font(.system(size: 48))
                            .foregroundColor(KomalColors.textSecondary.opacity(0.5))
                        Text("No browsing history yet")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                        Text("History will appear here as your child browses")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary.opacity(0.7))
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Filter pills
                            filterPills
                                .padding(.horizontal, 16)

                            // Needs Attention section
                            if !viewModel.filteredFlaggedGroups.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("Needs Attention")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(KomalColors.textPrimary)
                                    }
                                    .padding(.horizontal, 20)

                                    ForEach(viewModel.filteredFlaggedGroups) { group in
                                        TopicGroupCard(group: group, onChangeAction: { itemId, action in
                                            viewModel.changeAction(for: itemId, to: action)
                                        })
                                    }
                                }
                            }

                            // Allowed Links section
                            if !viewModel.filteredTopicGroups.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(KomalColors.pearlAqua)
                                        Text("Allowed Links")
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                            .foregroundColor(KomalColors.textPrimary)
                                    }
                                    .padding(.horizontal, 20)

                                    ForEach(viewModel.filteredTopicGroups) { group in
                                        TopicGroupCard(group: group, onChangeAction: { itemId, action in
                                            viewModel.changeAction(for: itemId, to: action)
                                        })
                                    }
                                }
                            }

                            Color.clear.frame(height: 40)
                        }
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle("Digital Journey")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadHistory()
        }
    }

    private var filterPills: some View {
        HStack(spacing: 8) {
            ForEach(DigitalJourneyViewModel.ActionFilter.allCases, id: \.rawValue) { filter in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.selectedFilter = filter
                    }
                }) {
                    Text(filter.rawValue)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(viewModel.selectedFilter == filter ? .white : KomalColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(viewModel.selectedFilter == filter ? KomalColors.lavenderPurple : Color.white)
                        )
                        .overlay(
                            Capsule()
                                .stroke(viewModel.selectedFilter == filter ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
            }
            Spacer()
        }
    }
}

// MARK: - Topic Group Card

struct TopicGroupCard: View {
    let group: TopicGroup
    let onChangeAction: (String, String) -> Void
    @State private var isExpanded = false

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(group.emojiSummary)
                                    .font(.system(size: 16))
                                Text(group.topicName)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(KomalColors.textPrimary)
                            }

                            Text(group.intentDescription)
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        VStack(spacing: 4) {
                            Text("\(group.items.count)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.lavenderPurple)
                            Text("links")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(KomalColors.textSecondary)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                // Expanded items
                if isExpanded {
                    Divider()

                    ForEach(group.items) { item in
                        HistoryItemRow(item: item, onChangeAction: onChangeAction)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    let item: HistoryItem
    let onChangeAction: (String, String) -> Void

    private var actionColor: Color {
        switch item.action {
        case "BLOCK": return .red
        case "GATE": return .orange
        case "ALLOW": return KomalColors.pearlAqua
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Page title or URL
                    Text(item.pageTitle ?? shortenURL(item.url))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                        .lineLimit(1)

                    Text(shortenURL(item.url))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(KomalColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Action badge
                Text(item.action)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(actionColor))

                // Emoji
                if let emoji = item.emojiResponse {
                    Text(emoji)
                        .font(.system(size: 18))
                }
            }

            HStack {
                // Timestamp
                Text(formatDate(item.timestamp))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)

                Spacer()

                // Parent action buttons
                HStack(spacing: 6) {
                    actionButton("Allow", action: "ALLOW", color: KomalColors.pearlAqua)
                    actionButton("Gate", action: "GATE", color: .orange)
                    actionButton("Block", action: "BLOCK", color: .red)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func actionButton(_ label: String, action: String, color: Color) -> some View {
        Button(action: {
            onChangeAction(item.id, action)
        }) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(item.action == action ? .white : color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(item.action == action ? color : color.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }

    private func shortenURL(_ url: String) -> String {
        var shortened = url
        shortened = shortened.replacingOccurrences(of: "https://www.", with: "")
        shortened = shortened.replacingOccurrences(of: "https://", with: "")
        shortened = shortened.replacingOccurrences(of: "http://www.", with: "")
        shortened = shortened.replacingOccurrences(of: "http://", with: "")
        if shortened.count > 50 {
            shortened = String(shortened.prefix(50)) + "..."
        }
        return shortened
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
#endif
