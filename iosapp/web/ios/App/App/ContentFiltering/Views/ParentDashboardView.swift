//
//  ParentDashboardView.swift
//  Komal - Parent Dashboard SwiftUI View
//
//  Modern dashboard with statistics and controls
//

import SwiftUI

struct ParentDashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Overview
                    statsSection

                    // Quick Actions
                    quickActionsSection

                    // Recent Activity
                    recentActivitySection

                    // Category Breakdown
                    categoryBreakdownSection
                }
                .padding()
            }
            .navigationTitle("Parent Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.exportSettings) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    // MARK: - Stats Section
    private var statsSection: some View {
        VStack(spacing: 12) {
            Text("Today's Activity")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                StatCard(
                    title: "Blocked",
                    value: "\(viewModel.stats.blocked)",
                    icon: "shield.slash.fill",
                    color: .red
                )

                StatCard(
                    title: "Gated",
                    value: "\(viewModel.stats.gated)",
                    icon: "hand.raised.fill",
                    color: .orange
                )

                StatCard(
                    title: "Allowed",
                    value: "\(viewModel.stats.allowed)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                ActionButton(
                    title: "View Activity Log",
                    icon: "list.bullet.rectangle",
                    action: viewModel.viewActivityLog
                )

                ActionButton(
                    title: "Adjust Filter Settings",
                    icon: "slider.horizontal.3",
                    action: viewModel.adjustSettings
                )

                ActionButton(
                    title: "Export Reports",
                    icon: "doc.text",
                    action: viewModel.exportReports
                )

                Toggle(isOn: $viewModel.biometricsEnabled) {
                    HStack {
                        Image(systemName: "faceid")
                            .foregroundColor(.blue)
                        Text("Enable Biometrics")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Recent Activity
    private var recentActivitySection: some View {
        VStack(spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.recentLogs.isEmpty {
                Text("No recent activity")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.recentLogs.prefix(5), id: \.id) { log in
                    ActivityRow(log: log)
                }
            }
        }
    }

    // MARK: - Category Breakdown
    private var categoryBreakdownSection: some View {
        VStack(spacing: 12) {
            Text("Top Categories")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(viewModel.topCategories, id: \.0) { category, count in
                HStack {
                    Text(category.displayName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(count)")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Activity Row
struct ActivityRow: View {
    let log: ActivityLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.wasBlocked ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(log.wasBlocked ? .red : .green)

            VStack(alignment: .leading, spacing: 4) {
                Text(log.category.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(log.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(timeAgo(from: log.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

// MARK: - View Model
class DashboardViewModel: ObservableObject {
    @Published var stats: FilteringStats
    @Published var recentLogs: [ActivityLog] = []
    @Published var topCategories: [(ContentCategory, Int)] = []
    @Published var biometricsEnabled: Bool {
        didSet {
            ParentControlService.shared.useBiometrics = biometricsEnabled
        }
    }

    private let filterService = ContentFilterService.shared
    private let parentControl = ParentControlService.shared

    init() {
        self.stats = filterService.getFilteringStats()
        self.biometricsEnabled = parentControl.useBiometrics
    }

    func loadData() {
        stats = filterService.getFilteringStats()
        recentLogs = parentControl.getActivityLogs(limit: 10)
        topCategories = stats.topCategories
    }

    func exportSettings() {
        if let json = parentControl.exportSettingsAsJSON() {
            // Share JSON
            let activityVC = UIActivityViewController(
                activityItems: [json],
                applicationActivities: nil
            )

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }

    func viewActivityLog() {
        // Navigate to activity log view
        print("View activity log")
    }

    func adjustSettings() {
        // Navigate to settings
        print("Adjust settings")
    }

    func exportReports() {
        let csv = ContentLogger.shared.exportAsCSV()
        let activityVC = UIActivityViewController(
            activityItems: [csv],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct ParentDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        ParentDashboardView()
    }
}
