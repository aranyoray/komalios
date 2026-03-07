#if os(iOS)
import SwiftUI

struct HistoryBatchDetailView: View {
    let batch: HistoryBatch
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                KomalColors.warmGray
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Emoji sequence timeline
                        if !batch.emojiSequence.isEmpty {
                            SettingsCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(LanguageManager.localized("history.emoji_journey"))
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(KomalColors.textSecondary)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 4) {
                                            ForEach(Array(batch.emojiSequence.enumerated()), id: \.offset) { index, emoji in
                                                Text(emoji)
                                                    .font(.system(size: 28))
                                                    .frame(width: 44, height: 44)
                                                    .background(
                                                        Circle()
                                                            .fill(KomalColors.lavenderPurple.opacity(0.12))
                                                    )

                                                if index < batch.emojiSequence.count - 1 {
                                                    Text("—")
                                                        .font(.system(size: 16, weight: .light))
                                                        .foregroundColor(KomalColors.textSecondary.opacity(0.4))
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }

                        // Combined summary card
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 12) {
                                CardHeader(icon: "doc.text.magnifyingglass", title: LanguageManager.localized("history.summary"), color: KomalColors.lavenderPurple)

                                HStack(spacing: 8) {
                                    if let emoji = batch.leadEmoji {
                                        Text(emoji)
                                            .font(.system(size: 24))
                                    }
                                    Text(batch.topicLabel)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)
                                }

                                Text(Self.generalizedTimeOfDay(from: batch.events.first?.timestamp))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(KomalColors.textSecondary)

                                if !batch.analysis.isEmpty {
                                    Text(batch.analysis)
                                        .font(.system(size: 15, weight: .regular, design: .rounded))
                                        .foregroundColor(KomalColors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                if let intent = batch.browsingIntent, !intent.isEmpty {
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "lightbulb.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(KomalColors.bubblegumPink)
                                        Text(intent)
                                            .font(.system(size: 14, weight: .regular, design: .rounded))
                                            .italic()
                                            .foregroundColor(KomalColors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }

                        // Domain-grouped links
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 12) {
                                CardHeader(icon: "list.bullet", title: LanguageManager.localized("history.pages_visited"), color: KomalColors.lavenderPurple)

                                ForEach(Array(domainGroups.enumerated()), id: \.offset) { groupIndex, group in
                                    if groupIndex > 0 {
                                        Divider()
                                            .padding(.vertical, 4)
                                    }

                                    // Domain header
                                    HStack(spacing: 6) {
                                        Image(systemName: "globe")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(KomalColors.lavenderPurple)
                                        Text(group.domain)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(KomalColors.textPrimary)
                                        Text("(\(group.events.count))")
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundColor(KomalColors.textSecondary)
                                        Spacer()
                                    }

                                    // Events under this domain
                                    ForEach(Array(group.events.enumerated()), id: \.element.id) { eventIndex, event in
                                        if eventIndex > 0 {
                                            Divider()
                                        }
                                        eventRow(event)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle(LanguageManager.localized("history.session_detail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text(LanguageManager.localized("history.back_label"))
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(KomalColors.lavenderPurple)
                    }
                }
            }
        }
    }

    // MARK: - Domain Groups

    private struct DomainGroup {
        let domain: String
        let events: [LocalHistoryEvent]
    }

    private var domainGroups: [DomainGroup] {
        var groups: [String: [LocalHistoryEvent]] = [:]
        var order: [String] = []
        for event in batch.events {
            let domain = event.domain
            if groups[domain] == nil { order.append(domain) }
            groups[domain, default: []].append(event)
        }
        return order.compactMap { domain in
            guard let events = groups[domain] else { return nil }
            return DomainGroup(domain: domain, events: events)
        }
    }

    // MARK: - Event Row

    private func eventRow(_ event: LocalHistoryEvent) -> some View {
        let isNavigable = event.action.uppercased() == "ALLOW" && URL(string: event.url) != nil

        return Button {
            guard isNavigable, let url = URL(string: event.url) else { return }
            appState.pendingBrowserURL = url
            appState.pendingNavigationTab = .browser
            dismiss()
        } label: {
            HStack(spacing: 12) {
                actionBadge(event.action)

                VStack(alignment: .leading, spacing: 4) {
                    if let title = event.pageTitle, !title.isEmpty {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                            .lineLimit(1)
                    }

                    Text(event.domain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(KomalColors.textSecondary)
                        .lineLimit(1)

                    if let sub = event.subcategory, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.lavenderPurple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(KomalColors.lavenderPurple.opacity(0.1))
                            .cornerRadius(6)
                    }
                }

                Spacer()

                if let emoji = event.emojiResponse {
                    Text(emoji)
                        .font(.system(size: 20))
                }

                if isNavigable {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KomalColors.textSecondary.opacity(0.5))
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(!isNavigable)
    }

    private func actionBadge(_ action: String) -> some View {
        let (color, icon): (Color, String) = {
            switch action.uppercased() {
            case "ALLOW": return (KomalColors.pearlAqua, "checkmark.circle.fill")
            case "GATE", "GATED": return (.orange, "exclamationmark.triangle.fill")
            case "BLOCK": return (.red, "xmark.circle.fill")
            default: return (KomalColors.textSecondary, "circle.fill")
            }
        }()

        return Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundColor(color)
    }

    static func generalizedTimeOfDay(from date: Date?) -> String {
        guard let date = date else { return "" }
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        default: return "Evening"
        }
    }
}

extension HistoryBatch: Equatable {
    static func == (lhs: HistoryBatch, rhs: HistoryBatch) -> Bool {
        lhs.id == rhs.id
    }
}
#endif
