import CoreData
import Foundation

@MainActor
class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SE7ENDataModel")
        
        // Configure for automatic migration
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.shouldMigrateStoreAutomatically = true
        storeDescription?.shouldInferMappingModelAutomatically = true
        
        container.loadPersistentStores { description, error in
            if let error = error {
                // Log error but don't crash - try to recover
                print("❌ Core Data failed to load: \(error.localizedDescription)")
                
                // Attempt to delete and recreate store if migration fails
                if let url = description.url {
                    do {
                        try FileManager.default.removeItem(at: url)
                        print("🔄 Removed corrupted store, will recreate on next launch")
                    } catch {
                        print("❌ Failed to remove corrupted store: \(error)")
                    }
                }
            } else {
                print("✅ Core Data loaded successfully")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save Core Data context: \(error)")
            }
        }
    }
    
    // MARK: - User Profile Methods
    
    func createUserProfile() -> UserProfile {
        let profile = UserProfile(context: context)
        profile.id = UUID()
        profile.createdAt = Date()
        profile.updatedAt = Date()
        profile.currentStreak = 0
        profile.longestStreak = 0
        profile.hasActiveSubscription = false
        profile.isOnboarding = true // Default to true for new users
        save()
        print("✅ Created new UserProfile with isOnboarding = true")
        return profile
    }
    
    func getUserProfile() -> UserProfile? {
        let request: NSFetchRequest<UserProfile> = UserProfile.fetchRequest()
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
    
    func getOrCreateUserProfile() -> UserProfile {
        if let profile = getUserProfile() {
            return profile
        }
        return createUserProfile()
    }
    
    // MARK: - Weekly Plan Methods
    
    func getCurrentWeeklyPlan() -> WeeklyPlan? {
        let request: NSFetchRequest<WeeklyPlan> = WeeklyPlan.fetchRequest()
        request.predicate = NSPredicate(format: "startDate <= %@ AND endDate >= %@", Date() as NSDate, Date() as NSDate)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    func createWeeklyPlan(startDate: Date, endDate: Date) -> WeeklyPlan {
        let plan = WeeklyPlan(context: context)
        plan.id = UUID()
        plan.startDate = startDate
        plan.endDate = endDate
        plan.creditsRemaining = 7
        plan.isCompleted = false
        plan.paymentAmount = 0.0
        plan.failureCount = 0 // Reset failure count for new week
        plan.lastFailureDate = nil
        plan.lastDailyResetDate = Calendar.current.startOfDay(for: Date()) // Track daily reset
        plan.userProfile = getOrCreateUserProfile()
        save()
        return plan
    }
    
    func getOrCreateCurrentWeeklyPlan() -> WeeklyPlan {
        if let currentPlan = getCurrentWeeklyPlan() {
            // Check if we need to reset credits for new day (daily reset to 7)
            let today = Calendar.current.startOfDay(for: Date())
            let lastResetDate = currentPlan.lastDailyResetDate.map { Calendar.current.startOfDay(for: $0) } ?? today
            
            // If it's a new day, reset credits to 7 and clear accountability fee
            if today > lastResetDate {
                print("🔄 Daily reset: Resetting credits to 7")
                currentPlan.creditsRemaining = 7
                currentPlan.lastDailyResetDate = today
                
                // Reset failure date and accountability fee tracking for new day
                currentPlan.lastFailureDate = nil
                currentPlan.accountabilityFeePaidDate = nil
                
                // Apply pending limit changes
                applyPendingLimitChanges()
                
                save()
            }
            
            // Check if we need to reset failure count for new week (Monday)
            let planStartDate = Calendar.current.startOfDay(for: currentPlan.startDate ?? Date())
            let planEndDate = Calendar.current.startOfDay(for: currentPlan.endDate ?? Date())
            let calendar = Calendar.current
            
            // Check if we're in a new week (Monday or past end date)
            let startOfCurrentWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
            let startOfPlanWeek = calendar.dateInterval(of: .weekOfYear, for: planStartDate)?.start ?? planStartDate
            
            // If we're past the end date OR it's a new week (different Monday), reset failure count
            if today > planEndDate || startOfCurrentWeek > startOfPlanWeek {
                // New week started (Monday) - reset failure count so progressive penalty starts at 1 credit
                print("🔄 Weekly reset: Resetting failure count to 0 for new week")
                currentPlan.failureCount = 0
                currentPlan.lastFailureDate = nil
                
                // Update plan dates to current week
                let endOfCurrentWeek = calendar.date(byAdding: .day, value: 6, to: startOfCurrentWeek) ?? today
                currentPlan.startDate = startOfCurrentWeek
                currentPlan.endDate = endOfCurrentWeek
                
                save()
            }
            
            return currentPlan
        }
        
        // Create new weekly plan starting from Monday of current week
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? Date()
        
        return createWeeklyPlan(startDate: startOfWeek, endDate: endOfWeek)
    }
    
    func performDailyResetIfNeeded() {
        // Called explicitly to ensure daily reset happens
        _ = getOrCreateCurrentWeeklyPlan()
    }
    
    // MARK: - App Goal Methods
    
    func createAppGoal(appName: String, bundleID: String, dailyLimitMinutes: Int) -> AppGoal {
        print("\n📝 CoreDataManager.createAppGoal called:")
        print("   appName: '\(appName)'")
        print("   bundleID: '\(bundleID)'")
        print("   limit: \(dailyLimitMinutes) minutes")
        
        let goal = AppGoal(context: context)
        goal.id = UUID()
        goal.appName = appName  // ✅ Critical - ensure this is set!
        goal.appBundleID = bundleID
        goal.dailyLimitMinutes = Int32(dailyLimitMinutes)
        goal.createdAt = Date()
        goal.updatedAt = Date()
        goal.isActive = true
        
        save()
        
        // ✅ Verify it was saved
        print("✅ Goal created and saved")
        print("   Saved name: '\(goal.appName ?? "NIL")'")
        print("   Saved ID: '\(goal.appBundleID ?? "NIL")'")
        print("   Goal UUID: \(goal.id?.uuidString ?? "NIL")\n")
        
        return goal
    }
    
    func getActiveAppGoals() -> [AppGoal] {
        let request: NSFetchRequest<AppGoal> = AppGoal.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AppGoal.appName, ascending: true)]
        
        let allGoals = (try? context.fetch(request)) ?? []
        
        // Filter out apps that don't have Screen Time tokens (mock apps)
        let screenTimeService = ScreenTimeService.shared
        return allGoals.filter { goal in
            guard let bundleID = goal.appBundleID else { return false }
            // Only return apps that have Screen Time tokens
            return screenTimeService.hasSelection(for: bundleID)
        }
    }
    
    // Clean up mock apps that don't have Screen Time tokens
    func cleanupMockApps() {
        let request: NSFetchRequest<AppGoal> = AppGoal.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        
        guard let allGoals = try? context.fetch(request) else { return }
        
        let screenTimeService = ScreenTimeService.shared
        var deletedCount = 0
        
        for goal in allGoals {
            guard let bundleID = goal.appBundleID else { continue }
            // Delete apps that don't have Screen Time tokens (mock apps)
            if !screenTimeService.hasSelection(for: bundleID) {
                print("🗑️ Deleting mock app: \(goal.appName ?? "Unknown")")
                context.delete(goal)
                deletedCount += 1
            }
        }
        
        if deletedCount > 0 {
            save()
            print("✅ Deleted \(deletedCount) mock app(s) without Screen Time tokens")
        }
    }
    
    func updateAppGoal(_ goal: AppGoal, dailyLimitMinutes: Int) {
        goal.dailyLimitMinutes = Int32(dailyLimitMinutes)
        goal.updatedAt = Date()
        save()
    }
    
    func applyPendingLimitChanges() {
        let goals = getActiveAppGoals()
        for goal in goals {
            guard let bundleID = goal.appBundleID else { continue }
            let key = "pendingLimit_\(bundleID)"
            
            if let pendingLimit = UserDefaults.standard.object(forKey: key) as? Int {
                print("📝 Applying pending limit change for \(goal.appName ?? "Unknown"): \(pendingLimit) minutes")
                updateAppGoal(goal, dailyLimitMinutes: pendingLimit)
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }
    
    func deleteAppGoal(_ goal: AppGoal) {
        context.delete(goal)
        save()
    }
    
    // MARK: - Usage Record Methods
    
    func createUsageRecord(for goal: AppGoal, date: Date, actualUsageMinutes: Int, didExceedLimit: Bool) -> AppUsageRecord {
        let record = AppUsageRecord(context: context)
        record.id = UUID()
        record.date = date
        record.actualUsageMinutes = Int32(actualUsageMinutes)
        record.didExceedLimit = didExceedLimit
        record.appGoal = goal
        save()
        return record
    }
    
    func getTodaysUsageRecords() -> [AppUsageRecord] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        let request: NSFetchRequest<AppUsageRecord> = AppUsageRecord.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AppUsageRecord.date, ascending: false)]
        
        return (try? context.fetch(request)) ?? []
    }
    
    func getTodaysUsageRecord(for bundleID: String) -> AppUsageRecord? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        let goals = getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else { return nil }
        
        let request: NSFetchRequest<AppUsageRecord> = AppUsageRecord.fetchRequest()
        request.predicate = NSPredicate(format: "appGoal == %@ AND date >= %@ AND date < %@", goal, startOfDay as NSDate, endOfDay as NSDate)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    func extendAppLimit(for bundleID: String, newLimitMinutes: Int) -> Bool {
        let goals = getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else {
            print("❌ No goal found for bundle ID: \(bundleID)")
            return false
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        var usageRecord = getTodaysUsageRecord(for: bundleID)
        
        // Create usage record if it doesn't exist
        if usageRecord == nil {
            usageRecord = createUsageRecord(
                for: goal,
                date: today,
                actualUsageMinutes: 0,
                didExceedLimit: false
            )
        }
        
        // Set extended limit
        usageRecord?.extendedLimitMinutes = Int32(newLimitMinutes)
        save()
        
        print("✅ Extended limit for \(goal.appName ?? bundleID) to \(newLimitMinutes) minutes for today")
        return true
    }
    
    func getEffectiveDailyLimit(for bundleID: String) -> Int {
        let goals = getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else {
            return 0
        }
        
        let baseLimit = Int(goal.dailyLimitMinutes)
        
        // ✅ NEW: Add puzzle extensions
        let puzzleExtensionMinutes = PuzzleManager.shared.getTotalExtensionMinutes(for: bundleID)
        
        // Check if there's an extension for today (legacy system)
        var extendedLimit = baseLimit + puzzleExtensionMinutes
        if let usageRecord = getTodaysUsageRecord(for: bundleID),
           usageRecord.extendedLimitMinutes > 0 {
            extendedLimit = max(extendedLimit, Int(usageRecord.extendedLimitMinutes))
        }
        
        // Check restriction period settings
        let restrictionPeriod = UserDefaults.standard.string(forKey: "restrictionPeriod_\(bundleID)") ?? "Daily"
        let restrictionLimit = UserDefaults.standard.object(forKey: "restrictionLimit_\(bundleID)") as? Int
        
        // If there's a restriction limit set, check if it's still active
        if let restrictionLimit = restrictionLimit {
            let endDate = UserDefaults.standard.object(forKey: "restrictionEndDate_\(bundleID)") as? Date ?? Date.distantFuture
            let now = Date()
            
            if now < endDate {
                // Restriction is still active, use restriction limit (but add puzzle extensions)
                return restrictionLimit + puzzleExtensionMinutes
            } else {
                // Restriction has expired, check if we should revert to base limit
                if restrictionPeriod == "One-time" {
                    // One-time restrictions expire and revert to base limit
                    // Clear the restriction settings
                    UserDefaults.standard.removeObject(forKey: "restrictionPeriod_\(bundleID)")
                    UserDefaults.standard.removeObject(forKey: "restrictionLimit_\(bundleID)")
                    UserDefaults.standard.removeObject(forKey: "restrictionStartDate_\(bundleID)")
                    UserDefaults.standard.removeObject(forKey: "restrictionEndDate_\(bundleID)")
                    print("🔄 One-time restriction expired for \(bundleID), reverting to base limit")
                    return baseLimit + puzzleExtensionMinutes
                } else if restrictionPeriod == "Weekly" {
                    // Weekly restrictions expire after 7 days
                    UserDefaults.standard.removeObject(forKey: "restrictionPeriod_\(bundleID)")
                    UserDefaults.standard.removeObject(forKey: "restrictionLimit_\(bundleID)")
                    UserDefaults.standard.removeObject(forKey: "restrictionStartDate_\(bundleID)")
                    UserDefaults.standard.removeObject(forKey: "restrictionEndDate_\(bundleID)")
                    print("🔄 Weekly restriction expired for \(bundleID), reverting to base limit")
                    return baseLimit + puzzleExtensionMinutes
                }
                // Daily restrictions don't expire, but use restriction limit if set
                return restrictionLimit + puzzleExtensionMinutes
            }
        }
        
        return extendedLimit
    }
    
    // MARK: - Credit Transaction Methods
    
    func deductCredit(reason: String, for usageRecord: AppUsageRecord? = nil) -> CreditTransaction {
        let weeklyPlan = getOrCreateCurrentWeeklyPlan()
        let today = Calendar.current.startOfDay(for: Date())
        
        // Check if accountability fee has been paid today
        let accountabilityFeePaidDate = weeklyPlan.accountabilityFeePaidDate.map { Calendar.current.startOfDay(for: $0) }
        let hasPaidAccountabilityFeeToday = accountabilityFeePaidDate == today
        
        // If already paid today, no credit deduction (just block the app)
        if hasPaidAccountabilityFeeToday {
            print("💳 Accountability fee already paid today - no credit deduction")
            let transaction = CreditTransaction(context: context)
            transaction.id = UUID()
            transaction.date = Date()
            transaction.amount = 0 // No deduction
            transaction.reason = "\(reason) (accountability fee already paid today)"
            transaction.transactionType = "deduction"
            transaction.usageRecord = usageRecord
            transaction.weeklyPlan = weeklyPlan
            save()
            return transaction
        }
        
        // First failure of the day - deduct all credits (user must pay 99 cents or wait)
        // Set credits to 0 to indicate they need to pay accountability fee
        weeklyPlan.lastFailureDate = Date()
        weeklyPlan.creditsRemaining = 0
        
        // Create transaction
        let transaction = CreditTransaction(context: context)
        transaction.id = UUID()
        transaction.date = Date()
        transaction.amount = -Int32(7) // Deduct all 7 credits
        transaction.reason = "\(reason) (Daily limit exceeded - pay 99¢ to renew or wait till tomorrow)"
        transaction.transactionType = "deduction"
        transaction.usageRecord = usageRecord
        transaction.weeklyPlan = weeklyPlan
        
        print("💳 Daily limit exceeded: Credits set to 0. User must pay 99¢ to renew for today or wait till tomorrow.")
        
        save()
        return transaction
    }
    
    func resetWeeklyFailureCount() {
        let weeklyPlan = getOrCreateCurrentWeeklyPlan()
        weeklyPlan.failureCount = 0
        weeklyPlan.lastFailureDate = nil
        save()
    }
    
    func getCurrentFailureCount() -> Int {
        // No longer using progressive failure count
        // Return 0 as we now use simple daily accountability fee system
        return 0
    }
    
    func getNextFailurePenalty() -> Int {
        // Always 7 credits (99 cents) - simple accountability fee
        return 7
    }
    
    func payAccountabilityFee() {
        // When user pays 99 cents, restore credits to 7 for the day
        let weeklyPlan = getOrCreateCurrentWeeklyPlan()
        let today = Calendar.current.startOfDay(for: Date())
        
        weeklyPlan.creditsRemaining = 7
        weeklyPlan.accountabilityFeePaidDate = today
        
        // Create transaction for accountability fee payment
        let transaction = CreditTransaction(context: context)
        transaction.id = UUID()
        transaction.date = Date()
        transaction.amount = 7 // Add 7 credits
        transaction.reason = "Accountability fee paid (99¢) - credits restored for today"
        transaction.transactionType = "payment"
        transaction.weeklyPlan = weeklyPlan
        
        print("✅ Accountability fee paid - credits restored to 7 for today")
        save()
    }
    
    func addCredits(amount: Int, reason: String) -> CreditTransaction {
        let transaction = CreditTransaction(context: context)
        transaction.id = UUID()
        transaction.date = Date()
        transaction.amount = Int32(amount)
        transaction.reason = reason
        transaction.transactionType = "addition"
        transaction.weeklyPlan = getOrCreateCurrentWeeklyPlan()
        
        // Update weekly plan credits
        let weeklyPlan = getOrCreateCurrentWeeklyPlan()
        let oldCredits = weeklyPlan.creditsRemaining
        weeklyPlan.creditsRemaining = min(7, weeklyPlan.creditsRemaining + Int32(amount))
        
        // If credits reach 7 and they were below 7 before, mark accountability fee as paid
        let today = Calendar.current.startOfDay(for: Date())
        if oldCredits < 7 && weeklyPlan.creditsRemaining >= 7 {
            weeklyPlan.accountabilityFeePaidDate = today
            print("✅ Accountability fee marked as paid - credits reached 7")
        }
        
        save()
        return transaction
    }
    
    // MARK: - Achievement Methods
    
    func unlockAchievement(achievementID: String) -> AchievementRecord {
        let record = AchievementRecord(context: context)
        record.id = UUID()
        record.achievementID = achievementID
        record.unlockedAt = Date()
        save()
        return record
    }
    
    func getUnlockedAchievements() -> [AchievementRecord] {
        let request: NSFetchRequest<AchievementRecord> = AchievementRecord.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AchievementRecord.unlockedAt, ascending: false)]
        
        return (try? context.fetch(request)) ?? []
    }
    
    func isAchievementUnlocked(achievementID: String) -> Bool {
        let request: NSFetchRequest<AchievementRecord> = AchievementRecord.fetchRequest()
        request.predicate = NSPredicate(format: "achievementID == %@", achievementID)
        request.fetchLimit = 1
        
        return ((try? context.fetch(request)) ?? []).count > 0
    }
    
    // MARK: - User Preferences Methods
    
    func saveUserPreferences(userName: String?, pet: Pet?, isOnboarding: Bool, averageScreenTimeHours: Int) {
        let profile = getOrCreateUserProfile()
        
        if let userName = userName {
            profile.userName = userName
        }
        
        if let pet = pet {
            profile.petType = pet.type.rawValue
            profile.petName = pet.name
            profile.petHealthState = pet.healthState.rawValue
        }
        
        profile.isOnboarding = isOnboarding
        profile.averageScreenTimeHours = Int32(averageScreenTimeHours)
        profile.updatedAt = Date()
        
        save()
    }
    
    func loadUserPreferences() -> (userName: String?, pet: Pet?, isOnboarding: Bool, averageScreenTimeHours: Int) {
        let profile = getOrCreateUserProfile()
        
        let userName = profile.userName
        var pet: Pet? = nil
        
        if let petTypeString = profile.petType,
           let petType = PetType(rawValue: petTypeString),
           let petName = profile.petName,
           let healthStateString = profile.petHealthState,
           let healthState = PetHealthState(rawValue: healthStateString) {
            pet = Pet(type: petType, name: petName, healthState: healthState)
        }
        
        let isOnboarding = profile.isOnboarding
        let averageScreenTimeHours = Int(profile.averageScreenTimeHours)
        
        return (userName, pet, isOnboarding, averageScreenTimeHours)
    }
    
    // MARK: - Daily History Methods
    
    func getDailyHistory(for weeklyPlan: WeeklyPlan) -> [DailyHistory] {
        guard let transactions = weeklyPlan.transactions as? Set<CreditTransaction> else {
            return []
        }
        
        // Group transactions by day and calculate credit changes
        let calendar = Calendar.current
        var dailyCreditChanges: [Date: Int] = [:]
        
        for transaction in transactions {
            let day = calendar.startOfDay(for: transaction.date ?? Date())
            dailyCreditChanges[day, default: 0] += Int(transaction.amount)
        }
        
        // Convert to DailyHistory array
        return dailyCreditChanges.map { date, creditChange in
            DailyHistory(date: date, creditChange: creditChange)
        }.sorted { $0.date > $1.date }
    }
    
    func getAllWeeklyPlans() -> [WeeklyPlan] {
        let request: NSFetchRequest<WeeklyPlan> = WeeklyPlan.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WeeklyPlan.startDate, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }
    
    // MARK: - Error Handling & Migration
    
    func saveWithErrorHandling() throws {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("❌ Core Data save error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func performMigrationIfNeeded() {
        // Check if migration is needed
        // For now, we'll use lightweight migration which Core Data handles automatically
        // In the future, if schema changes require custom migration, add it here
        
        let storeDescription = persistentContainer.persistentStoreDescriptions.first
        storeDescription?.shouldMigrateStoreAutomatically = true
        storeDescription?.shouldInferMappingModelAutomatically = true
    }
}
