#if os(iOS)
import Foundation
import StoreKit
import os.log

private let log = Logger(subsystem: "com.komalkids.komal", category: "Subscription")

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var purchaseError: String?
    @Published private(set) var isPurchasing = false
    @Published private(set) var transactionHistory: [TransactionInfo] = []

    private let productIDs: Set<String> = [
        "grow_month_999",
        "thrive_monthly_1449"
    ]

    private var transactionListener: Task<Void, Never>?

    private init() {
        log.info("SubscriptionService initialized — listening for transaction updates")
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Fetch Products

    func fetchProducts() async {
        log.info("Fetching products for IDs: \(self.productIDs.joined(separator: ", "))")
        do {
            let storeProducts = try await Product.products(for: productIDs)
            products = storeProducts.sorted { $0.price < $1.price }
            log.info("Fetched \(storeProducts.count) products:")
            for p in products {
                log.info("  - \(p.id): \(p.displayName) @ \(p.displayPrice) (\(p.subscription?.subscriptionPeriod.debugDescription ?? "n/a"))")
            }
            if storeProducts.isEmpty {
                log.warning("No products returned — check product IDs in App Store Connect and StoreKit config")
            }
        } catch {
            log.error("Failed to fetch products: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async -> Bool {
        log.info("Starting purchase for: \(product.id) (\(product.displayName) @ \(product.displayPrice))")
        isPurchasing = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                log.info("Purchase result: success — verifying transaction...")
                let transaction = try checkVerified(verification)
                log.info("Transaction verified — id=\(transaction.id), productID=\(transaction.productID), purchaseDate=\(transaction.purchaseDate.description)")
                if let exp = transaction.expirationDate {
                    log.info("  expirationDate=\(exp.description)")
                }
                await transaction.finish()
                log.info("Transaction finished")
                await updatePurchasedProducts()
                isPurchasing = false
                return true

            case .userCancelled:
                log.info("Purchase cancelled by user for: \(product.id)")
                isPurchasing = false
                return false

            case .pending:
                log.warning("Purchase pending (Ask to Buy or deferred): \(product.id)")
                purchaseError = "Purchase is pending approval."
                isPurchasing = false
                return false

            @unknown default:
                log.warning("Purchase returned unknown result for: \(product.id)")
                isPurchasing = false
                return false
            }
        } catch {
            log.error("Purchase failed for \(product.id): \(error.localizedDescription)")
            purchaseError = error.localizedDescription
            isPurchasing = false
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        log.info("Restoring purchases via AppStore.sync()...")
        do {
            try await AppStore.sync()
            log.info("AppStore.sync() completed")
            await updatePurchasedProducts()
        } catch {
            log.error("Restore failed: \(error.localizedDescription)")
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Update Entitlements

    func updatePurchasedProducts() async {
        log.info("Updating purchased products from currentEntitlements...")
        var purchased: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                // Only count as active if not expired
                if let expiration = transaction.expirationDate, expiration < Date() {
                    log.warning("  Expired entitlement skipped: \(transaction.productID), expired=\(expiration.description)")
                    continue
                }
                purchased.insert(transaction.productID)
                log.info("  Active entitlement: \(transaction.productID), expires=\(transaction.expirationDate?.description ?? "never")")
            } catch {
                log.error("  Verification failed for entitlement: \(error.localizedDescription)")
            }
        }

        purchasedProductIDs = purchased
        log.info("Purchased product IDs: \(purchased.isEmpty ? "(none)" : purchased.joined(separator: ", "))")
        log.info("Derived plan: \(self.currentPlan().displayName)")
    }

    // MARK: - Current Plan

    func currentPlan() -> SubscriptionPlan {
        if purchasedProductIDs.contains("thrive_monthly_1449") {
            return .thrive
        } else if purchasedProductIDs.contains("grow_month_999") {
            return .grow
        }
        return .essentials
    }

    // MARK: - Helpers

    func product(for plan: SubscriptionPlan) -> Product? {
        guard let id = plan.productID else { return nil }
        let found = products.first { $0.id == id }
        if found == nil {
            log.warning("Product not found for plan \(plan.displayName) (id=\(id)). Available: \(self.products.map(\.id).joined(separator: ", "))")
        }
        return found
    }

    func priceString(for plan: SubscriptionPlan) -> String? {
        guard let product = product(for: plan) else { return nil }
        return product.displayPrice
    }

    // MARK: - Transaction History

    struct TransactionInfo: Identifiable {
        let id: UInt64
        let productID: String
        let purchaseDate: Date
        let expirationDate: Date?
        let price: Decimal?
        let displayPrice: String?
        let isRevoked: Bool

        var planName: String {
            switch productID {
            case "thrive_monthly_1449": return "Thrive"
            case "grow_month_999": return "Grow"
            default: return productID
            }
        }
    }

    func fetchTransactionHistory() async {
        log.info("Fetching full transaction history (Transaction.all)...")
        var history: [TransactionInfo] = []

        for await result in Transaction.all {
            do {
                let transaction = try checkVerified(result)
                let product = products.first { $0.id == transaction.productID }
                let info = TransactionInfo(
                    id: transaction.id,
                    productID: transaction.productID,
                    purchaseDate: transaction.purchaseDate,
                    expirationDate: transaction.expirationDate,
                    price: product?.price,
                    displayPrice: product?.displayPrice,
                    isRevoked: transaction.revocationDate != nil
                )
                history.append(info)
                log.info("  Txn #\(transaction.id): \(transaction.productID), purchased=\(transaction.purchaseDate.description), expires=\(transaction.expirationDate?.description ?? "n/a"), revoked=\(transaction.revocationDate != nil)")
            } catch {
                log.error("  Skipped unverified transaction: \(error.localizedDescription)")
            }
        }

        transactionHistory = history.sorted { $0.purchaseDate > $1.purchaseDate }
        log.info("Transaction history: \(history.count) total entries")
    }

    /// Returns the next renewal date from the latest active entitlement
    func currentRenewalDate() async -> Date? {
        log.info("Checking current renewal date...")
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                log.info("  Renewal date for \(transaction.productID): \(transaction.expirationDate?.description ?? "none")")
                return transaction.expirationDate
            } catch {
                log.error("  Verification failed when checking renewal: \(error.localizedDescription)")
            }
        }
        log.info("  No active entitlements found — no renewal date")
        return nil
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached {
            log.info("Transaction listener started (background)")
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    log.info("Transaction update received: id=\(transaction.id), product=\(transaction.productID)")
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                } catch {
                    log.error("Transaction update: verification failed — \(error.localizedDescription)")
                }
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            log.error("Verification failed: \(error.localizedDescription)")
            throw error
        case .verified(let value):
            return value
        }
    }
}
#endif
