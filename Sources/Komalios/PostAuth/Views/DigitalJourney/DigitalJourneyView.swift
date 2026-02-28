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
    @StateObject private var historyViewModel = BrowsingHistoryViewModel(showAllByDefault: true)
    @Environment(\.dismiss) private var dismiss

    enum JourneyTab: String, CaseIterable {
        case insights = "ai_insights"
        case history = "history"

        var displayName: String {
            switch self {
            case .insights: return LanguageManager.localized("journey.tab.insights")
            case .history: return LanguageManager.localized("journey.tab.history")
            }
        }
    }

    @State private var selectedTab: JourneyTab = .insights
    @State private var selectedBatch: HistoryBatch?

    var body: some View {
        NavigationView {
            ZStack {
                KomalColors.warmGray
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented tab picker
                    Picker("", selection: $selectedTab) {
                        ForEach(JourneyTab.allCases, id: \.self) { tab in
                            Text(tab.displayName).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    switch selectedTab {
                    case .insights:
                        insightsContent
                    case .history:
                        historyContent
                    }
                }
            }
            .navigationTitle(LanguageManager.localized("journey.title"))
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
            .fullScreenCover(item: $selectedBatch) { batch in
                HistoryBatchDetailView(batch: batch)
                    .environmentObject(appState)
            }
        }
        .task {
            viewModel.loadHistory()
            await historyViewModel.loadHistory()
        }
        .onChange(of: historyViewModel.selectedTimeRange) { historyViewModel.onFilterChanged() }
    }

    // MARK: - AI Insights Content

    private var insightsContent: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(LanguageManager.localized("journey.analyzing"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }
                .frame(maxHeight: .infinity)
            } else if viewModel.allItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundColor(KomalColors.textSecondary.opacity(0.5))
                    Text(LanguageManager.localized("journey.no_history"))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                    Text(LanguageManager.localized("journey.history_will_appear"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Filter pills
                        filterPills
                            .padding(.horizontal, 16)

                        // Needs Attention section
                        if !viewModel.filteredFlaggedGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(LanguageManager.localized("journey.needs_attention"))
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
                                    Text(LanguageManager.localized("journey.allowed_links"))
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

                        Color.clear.frame(height: 20)
                    }
                    .padding(.top, 12)
                }
            }
        }
    }

    // MARK: - History Content

    private var historyContent: some View {
        Group {
            if historyViewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text(LanguageManager.localized("journey.loading_history"))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                }
                .frame(maxHeight: .infinity)
            } else if historyViewModel.batches.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(KomalColors.textSecondary.opacity(0.5))
                    Text(LanguageManager.localized("journey.no_history"))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.textPrimary)
                    Text(LanguageManager.localized("journey.history_will_appear"))
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 24)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        historyTimeRangeBar

                        LazyVStack(spacing: 12) {
                            ForEach(historyViewModel.batches) { batch in
                                TopicBoxCard(batch: batch) {
                                    selectedBatch = batch
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - History Time Range Bar

    private var historyTimeRangeBar: some View {
        SettingsCard {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)

                Text(LanguageManager.localized("journey.time_range"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)

                Spacer()

                Menu {
                    ForEach(TimeRangeOption.allCases) { option in
                        Button(action: {
                            historyViewModel.selectedTimeRange = option
                        }) {
                            HStack {
                                Text(option.displayName)
                                if historyViewModel.selectedTimeRange == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(historyViewModel.selectedTimeRange.displayName)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(KomalColors.background)
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Filter Pills (AI Insights)

    private var filterPills: some View {
        HStack(spacing: 8) {
            ForEach(DigitalJourneyViewModel.ActionFilter.allCases, id: \.rawValue) { filter in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.selectedFilter = filter
                    }
                }) {
                    Text(filter.displayName)
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
                            Text(LanguageManager.localized("journey.links"))
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
                    actionButton(LanguageManager.localized("filter.allow"), action: "ALLOW", color: KomalColors.pearlAqua)
                    actionButton(LanguageManager.localized("filter.gate"), action: "GATE", color: .orange)
                    actionButton(LanguageManager.localized("filter.block"), action: "BLOCK", color: .red)
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

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    private func formatDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
}

#endif
