import StoreKit
import Foundation
import Combine

@MainActor
final class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    
    // Product IDs for the app
    private enum ProductIDs {
        static let biWeeklySubscription = "se7en_biweekly_subscription"
    }
    
    @Published var subscriptionProduct: Product?
    @Published var isSubscribed = false
    @Published var purchaseState: PurchaseState = .idle
    
    private var updateListenerTask: Task<Void, Error>?
    private let coreDataManager = CoreDataManager.shared
    private let appState = AppState()
    
    enum PurchaseState {
        case idle
        case purchasing
        case success
        case failed(Error)
    }
    
    private init() {
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [
                ProductIDs.biWeeklySubscription
            ])
            
            for product in products {
                if product.id == ProductIDs.biWeeklySubscription {
                    subscriptionProduct = product
                }
            }
            
            print("Loaded subscription product")
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    // MARK: - Purchase Restoration
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            print("Purchases restored")
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }
    
    // MARK: - Subscription Management
    
    func purchaseSubscription() async -> Bool {
        guard let product = subscriptionProduct else {
            print("Subscription product not available")
            return false
        }
        
        return await purchase(product)
    }
    
    func checkSubscriptionStatus() async {
        // Check for active subscription entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID == ProductIDs.biWeeklySubscription &&
                   transaction.revocationDate == nil {
                    isSubscribed = true
                    appState.updateSubscriptionStatus(true)
                    return
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        isSubscribed = false
        appState.updateSubscriptionStatus(false)
    }
    
    // MARK: - Purchase Flow
    
    private func purchase(_ product: Product) async -> Bool {
        purchaseState = .purchasing
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Process the transaction
                await processTransaction(transaction)
                
                // Finish the transaction
                await transaction.finish()
                
                purchaseState = .success
                return true
                
            case .userCancelled:
                purchaseState = .idle
                print("User cancelled purchase")
                return false
                
            case .pending:
                purchaseState = .idle
                print("Purchase is pending")
                return false
                
            @unknown default:
                purchaseState = .idle
                print("Unknown purchase result")
                return false
            }
        } catch {
            purchaseState = .failed(error)
            print("Purchase failed: \(error)")
            return false
        }
    }
    
    private func processTransaction(_ transaction: Transaction) async {
        await MainActor.run {
            processTransactionSync(transaction)
        }
    }
    
    @MainActor
    private func processTransactionSync(_ transaction: Transaction) {
        print("Processing transaction: \(transaction.productID)")
        
        switch transaction.productID {
        case ProductIDs.biWeeklySubscription:
            // Subscription handled by checkSubscriptionStatus
            print("Subscription transaction processed")
            
        default:
            print("Unknown product ID: \(transaction.productID)")
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task { [weak self] in
            guard let self else { return }
            // Listen for new transactions
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                        self.processTransactionSync(transaction)
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let signedType):
            return signedType
        case .unverified(_, let error):
            throw error
        }
    }
    
    // MARK: - Product Helpers
    
    func formatPrice(for product: Product) -> String {
        return product.displayPrice
    }
    
    // MARK: - Subscription Info
    
    func getSubscriptionInfo() -> (price: String, period: String, trialDays: Int)? {
        guard let product = subscriptionProduct else { return nil }
        
        let price = product.displayPrice
        let period = localizedPeriod(for: product.subscription?.subscriptionPeriod) ?? "14 days"
        let trialDays = product.subscription?.introductoryOffer?.period.value ?? 7
        
        return (price: price, period: period, trialDays: trialDays)
    }
    
    private func localizedPeriod(for period: Product.SubscriptionPeriod?) -> String? {
        guard let period = period else { return nil }
        
        switch period.unit {
        case .day:
            return period.value == 1 ? "day" : "\(period.value) days"
        case .week:
            return period.value == 1 ? "week" : "\(period.value) weeks"
        case .month:
            return period.value == 1 ? "month" : "\(period.value) months"
        case .year:
            return period.value == 1 ? "year" : "\(period.value) years"
        @unknown default:
            return "period"
        }
    }
}
