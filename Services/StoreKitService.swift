import StoreKit
import Foundation
import Combine

class StoreKitService: ObservableObject {
    nonisolated static let shared = StoreKitService()
    
    // Product IDs for the app
    private enum ProductIDs {
        static let weeklySubscription = "se7en_weekly_subscription"
        static let oneCredit = "se7en_one_credit"
        static let threeCredits = "se7en_three_credits"
        static let sevenCredits = "se7en_seven_credits"
    }
    
    @Published var subscriptionProduct: Product?
    @Published var creditProducts: [Product] = []
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
                ProductIDs.weeklySubscription,
                ProductIDs.oneCredit,
                ProductIDs.threeCredits,
                ProductIDs.sevenCredits
            ])
            
            for product in products {
                switch product.id {
                case ProductIDs.weeklySubscription:
                    subscriptionProduct = product
                case ProductIDs.oneCredit, ProductIDs.threeCredits, ProductIDs.sevenCredits:
                    creditProducts.append(product)
                default:
                    break
                }
            }
            
            // Sort credit products by price
            creditProducts.sort { $0.price < $1.price }
            
            print("Loaded \(products.count) products")
        } catch {
            print("Failed to load products: \(error)")
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
                
                if transaction.productID == ProductIDs.weeklySubscription &&
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
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
        } catch {
            print("Failed to restore purchases: \(error)")
        }
    }
    
    // MARK: - Credit Purchases
    
    func purchaseCredits(_ productID: String) async -> Bool {
        guard let product = creditProducts.first(where: { $0.id == productID }) else {
            print("Credit product not found: \(productID)")
            return false
        }
        
        let success = await purchase(product)
        
        if success {
            // Add credits based on product
            let creditsToAdd: Int
            switch productID {
            case ProductIDs.oneCredit:
                creditsToAdd = 1
            case ProductIDs.threeCredits:
                creditsToAdd = 3
            case ProductIDs.sevenCredits:
                creditsToAdd = 7
            default:
                creditsToAdd = 0
            }
            
            if creditsToAdd > 0 {
                appState.addCredits(amount: creditsToAdd, reason: "Purchased \(creditsToAdd) credit(s)")
            }
        }
        
        return success
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
        case ProductIDs.weeklySubscription:
            isSubscribed = true
            appState.updateSubscriptionStatus(true)
            
        case ProductIDs.oneCredit:
            appState.addCredits(amount: 1, reason: "Purchased 1 credit")
            
        case ProductIDs.threeCredits:
            appState.addCredits(amount: 3, reason: "Purchased 3 credits")
            
        case ProductIDs.sevenCredits:
            appState.addCredits(amount: 7, reason: "Purchased 7 credits")
            
        default:
            print("Unknown product ID: \(transaction.productID)")
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Listen for new transactions
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    await MainActor.run {
                        self.processTransactionSync(transaction)
                    }
                    
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
    
    func getCreditProduct(for credits: Int) -> Product? {
        switch credits {
        case 1:
            return creditProducts.first { $0.id == ProductIDs.oneCredit }
        case 3:
            return creditProducts.first { $0.id == ProductIDs.threeCredits }
        case 7:
            return creditProducts.first { $0.id == ProductIDs.sevenCredits }
        default:
            return nil
        }
    }
    
    func formatPrice(for product: Product) -> String {
        return product.displayPrice
    }
    
    // MARK: - Subscription Info
    
    func getSubscriptionInfo() -> (price: String, period: String)? {
        guard let product = subscriptionProduct else { return nil }
        
        let price = product.displayPrice
        let period = localizedPeriod(for: product.subscription?.subscriptionPeriod) ?? "week"
        
        return (price: price, period: period)
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
    
    // MARK: - Weekly Payment Processing
    
    func processWeeklyPayment(creditsLost: Int) async {
        guard creditsLost > 0 && creditsLost <= 7 else { return }
        
        // If user has active subscription, no payment needed
        if isSubscribed {
            print("User has active subscription, no payment required")
            return
        }
        
        // Calculate payment amount ($1 per lost credit)
        let paymentAmount = Double(creditsLost)
        
        // In a real app, you would process the payment here
        // For now, just log the payment
        print("Processing weekly payment: $\(paymentAmount) for \(creditsLost) lost credits")
        
        // Update the weekly plan with payment amount
        let weeklyPlan = coreDataManager.getCurrentWeeklyPlan()
        weeklyPlan?.paymentAmount = paymentAmount
        coreDataManager.save()
    }
}
