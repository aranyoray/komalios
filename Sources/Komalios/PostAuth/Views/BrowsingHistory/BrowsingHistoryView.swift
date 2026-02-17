#if os(iOS)
import SwiftUI

struct BrowsingHistoryView: View {
    @StateObject private var viewModel = BrowsingHistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBatch: HistoryBatch?

    var body: some View {
        NavigationView {
            ZStack {
                KomalColors.warmGray
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading browsing history...")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                    }
                } else if viewModel.batches.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(KomalColors.textSecondary.opacity(0.5))
                        Text("No browsing history yet")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                        Text("History will appear here as your child browses.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            timeRangeBar

                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.batches) { batch in
                                    TopicBoxCard(batch: batch) {
                                        selectedBatch = batch
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Browsing History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Settings")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(KomalColors.lavenderPurple)
                    }
                }
            }
            .fullScreenCover(item: $selectedBatch) { batch in
                HistoryBatchDetailView(batch: batch)
            }
        }
        .task {
            await viewModel.loadHistory()
        }
        .onChange(of: viewModel.selectedTimeRange) { _ in viewModel.onFilterChanged() }
    }

    // MARK: - Time Range Bar

    private var timeRangeBar: some View {
        SettingsCard {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(KomalColors.textSecondary)

                Text("Time Range")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(KomalColors.textSecondary)

                Spacer()

                Menu {
                    ForEach(TimeRangeOption.allCases) { option in
                        Button(action: {
                            viewModel.selectedTimeRange = option
                        }) {
                            HStack {
                                Text(option.rawValue)
                                if viewModel.selectedTimeRange == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.selectedTimeRange.rawValue)
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
}

// MARK: - Topic Box Card

struct TopicBoxCard: View {
    let batch: HistoryBatch
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    // Header: emoji + topic label + chevron
                    HStack {
                        if let emoji = batch.leadEmoji {
                            Text(emoji)
                                .font(.system(size: 22))
                        }

                        Text(batch.topicLabel)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(KomalColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(KomalColors.textSecondary)
                    }

                    // Faded title preview with favicons
                    ZStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(previewItems.enumerated()), id: \.offset) { _, item in
                                HStack(spacing: 6) {
                                    if let faviconURL = item.faviconURL {
                                        AsyncImage(url: faviconURL) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 14, height: 14)
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                        } placeholder: {
                                            Image(systemName: "globe")
                                                .font(.system(size: 10))
                                                .foregroundColor(KomalColors.textSecondary.opacity(0.4))
                                                .frame(width: 14, height: 14)
                                        }
                                    } else {
                                        Circle()
                                            .fill(KomalColors.textSecondary.opacity(0.3))
                                            .frame(width: 5, height: 5)
                                    }
                                    Text(item.title)
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundColor(KomalColors.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }

                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: 30)
                    }

                    // Footer: domain + time + page count
                    HStack {
                        if let domain = batch.primaryDomain {
                            Text(domain)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(KomalColors.textSecondary.opacity(0.7))
                                .lineLimit(1)
                        }

                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(KomalColors.textSecondary.opacity(0.7))
                        Text(batch.timeRange)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.textSecondary.opacity(0.7))
                            .lineLimit(1)

                        Spacer()

                        Text("\(batch.events.count) pages")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(KomalColors.lavenderPurple)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private struct PreviewItem {
        let title: String
        let faviconURL: URL?
    }

    private var previewItems: [PreviewItem] {
        batch.events
            .filter { $0.pageTitle != nil && !$0.pageTitle!.isEmpty }
            .prefix(3)
            .map { event in
                let domain = event.domain
                let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=32")
                return PreviewItem(title: event.pageTitle ?? "", faviconURL: faviconURL)
            }
    }
}

// MARK: - TimeRangeOption Equatable for onChange

extension TimeRangeOption: Equatable {}
#endif
