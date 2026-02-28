#if os(iOS)
import SwiftUI
import StoreKit
import os.log

private let log = Logger(subsystem: "com.komalkids.komal", category: "PlanSelection")

struct PlanSelectionView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: SubscriptionPlan = .grow
    @State private var showError = false
    @State private var errorMessage = ""

    /// When true, shows a close button (used from Settings). When false, non-dismissable (used from onboarding).
    var allowDismiss: Bool = false
    var onPlanSelected: (SubscriptionPlan) -> Void

    var body: some View {
        NavigationStack {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            if let uiImage = UIImage(named: "komaliconnobg") {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 60)
                            }

                            Text(LanguageManager.localized("plan.choose_title"))
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)

                            Text(LanguageManager.localized("plan.choose_subtitle"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(KomalColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                        // Plan Cards
                        VStack(spacing: 16) {
                            ForEach(SubscriptionPlan.allCases) { plan in
                                PlanCard(
                                    plan: plan,
                                    priceString: subscriptionService.priceString(for: plan),
                                    isSelected: selectedPlan == plan,
                                    isRecommended: plan == .grow
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedPlan = plan
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 80)
                }

                // Bottom pinned area
                VStack(spacing: 12) {
                    // Subscribe / Start button
                    Button(action: {
                        Task { await handleSelection() }
                    }) {
                        HStack {
                            if subscriptionService.isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(selectedPlan == .essentials ? LanguageManager.localized("plan.start_essentials") : LanguageManager.localized("plan.subscribe_to").replacingOccurrences(of: "%@", with: selectedPlan.displayName))
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor(for: selectedPlan))
                        .cornerRadius(14)
                    }
                    .disabled(subscriptionService.isPurchasing)

                    // Restore purchases
                    Button(action: {
                        Task {
                            await subscriptionService.restorePurchases()
                            let restored = subscriptionService.currentPlan()
                            if restored != .essentials {
                                onPlanSelected(restored)
                            }
                        }
                    }) {
                        Text(LanguageManager.localized("plan.restore_purchases"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(KomalColors.textSecondary)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    Color(UIColor.systemGroupedBackground)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: -4)
                )
            }
        }
        .interactiveDismissDisabled(!allowDismiss)
        .toolbar {
            if allowDismiss {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LanguageManager.localized("common.done")) { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(KomalColors.lavenderPurple)
                }
            }
        }
        .task {
            log.info("PlanSelectionView appeared (allowDismiss=\(self.allowDismiss))")
            await subscriptionService.fetchProducts()
            await subscriptionService.updatePurchasedProducts()
            let existing = subscriptionService.currentPlan()
            log.info("Existing plan on load: \(existing.displayName)")
            if existing != .essentials && !allowDismiss {
                log.info("Auto-completing with existing plan: \(existing.displayName)")
                onPlanSelected(existing)
            } else if allowDismiss {
                selectedPlan = existing
            }
        }
        .alert(LanguageManager.localized("plan.purchase_error"), isPresented: $showError) {
            Button(LanguageManager.localized("common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        } // NavigationStack
    }

    private func handleSelection() async {
        log.info("User confirmed plan selection: \(self.selectedPlan.displayName)")
        if selectedPlan == .essentials {
            log.info("Essentials (free) selected — completing immediately")
            onPlanSelected(.essentials)
            return
        }

        guard let product = subscriptionService.product(for: selectedPlan) else {
            log.error("Product not found for \(self.selectedPlan.displayName) — cannot purchase")
            errorMessage = LanguageManager.localized("plan.unavailable")
            showError = true
            return
        }

        log.info("Initiating StoreKit purchase for \(product.id)...")
        let success = await subscriptionService.purchase(product)
        if success {
            let plan = subscriptionService.currentPlan()
            log.info("Purchase succeeded — derived plan: \(plan.displayName)")
            onPlanSelected(plan)
        } else if let error = subscriptionService.purchaseError {
            log.error("Purchase failed: \(error)")
            errorMessage = error
            showError = true
        } else {
            log.info("Purchase did not complete (user cancelled or no error)")
        }
    }

    private func accentColor(for plan: SubscriptionPlan) -> Color {
        switch plan {
        case .essentials: return KomalColors.pearlAqua
        case .grow: return KomalColors.lavenderPurple
        case .thrive: return KomalColors.bubblegumPink
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: SubscriptionPlan
    let priceString: String?
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void

    private var cardColor: Color {
        switch plan {
        case .essentials: return KomalColors.pearlAqua
        case .grow: return KomalColors.lavenderPurple
        case .thrive: return KomalColors.bubblegumPink
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Title row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(plan.displayName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(KomalColors.textPrimary)

                            if isRecommended {
                                Text(LanguageManager.localized("plan.recommended"))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(cardColor)
                                    .cornerRadius(6)
                            }
                        }

                        // Price
                        if plan == .essentials {
                            Text(LanguageManager.localized("plan.free"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(cardColor)
                        } else if let price = priceString {
                            Text(LanguageManager.localized("plan.per_month").replacingOccurrences(of: "%@", with: price))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(cardColor)
                        } else {
                            Text(LanguageManager.localized("plan.loading"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(KomalColors.textSecondary)
                        }

                        Text(plan.tagline)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .italic()
                            .foregroundColor(KomalColors.textSecondary)
                    }

                    Spacer()

                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(isSelected ? cardColor : Color.gray.opacity(0.35), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(cardColor)
                                .frame(width: 14, height: 14)
                        }
                    }
                }

                // Features
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(cardColor)

                            Text(feature)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(KomalColors.textSecondary)
                        }
                    }
                }

                // Profile count
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(cardColor)
                    if let max = plan.maxChildProfiles {
                        Text(LanguageManager.localized("plan.profiles_up_to").replacingOccurrences(of: "%d", with: "\(max)"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(cardColor)
                    } else {
                        Text(LanguageManager.localized("plan.profiles_unlimited"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(cardColor)
                    }
                }
            }
            .padding(18)
            .background(isSelected ? cardColor.opacity(0.08) : Color.white)
            .contentShape(Rectangle())
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? cardColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
