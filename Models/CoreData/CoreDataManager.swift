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
                
                // Check and update streak for yesterday (once per day at reset)
                checkAndUpdateStreakForYesterday()
                
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
        let appGroupID = "group.com.se7en.app"
        
        // ✅ CRITICAL: Check if One Session mode is active - return BASE limit only
        if let sharedDefaults = UserDefaults(suiteName: appGroupID) {
            if sharedDefaults.bool(forKey: "oneSessionActive_\(bundleID)") {
                // One Session mode: return original limit (no +15 extension)
                return baseLimit
            }
        }
        
        // ✅ Check if Extra Time extension is active (puzzle was completed)
        if let sharedDefaults = UserDefaults(suiteName: appGroupID),
           let extensionEndTime = sharedDefaults.object(forKey: "extension_end_\(bundleID)") as? TimeInterval {
            let endDate = Date(timeIntervalSince1970: extensionEndTime)
            if Date() < endDate {
                // Extra Time mode: return base + extension (15 minutes)
                let extensionMinutes = sharedDefaults.integer(forKey: "extensionLimit_\(bundleID)")
                if extensionMinutes > 0 {
                    return baseLimit + extensionMinutes
                }
                // Fallback: add 15 minutes
                return baseLimit + 15
            }
        }
        
        // Also check UserDefaults for extension (legacy)
        if let extensionEndTime = UserDefaults.standard.object(forKey: "extension_end_\(bundleID)") as? Date,
           Date() < extensionEndTime {
            // Extra Time mode: return base + extension
            if let usageRecord = getTodaysUsageRecord(for: bundleID),
               usageRecord.extendedLimitMinutes > 0 {
                return baseLimit + Int(usageRecord.extendedLimitMinutes)
            }
            return baseLimit + 15
        }
        
        // ✅ Add puzzle extensions (for non-active extensions, just add to base)
        let puzzleExtensionMinutes = PuzzleManager.shared.getTotalExtensionMinutes(for: bundleID)
        
        // Check if there's an extension for today (legacy system)
        var extendedLimit = baseLimit + puzzleExtensionMinutes
        if let usageRecord = getTodaysUsageRecord(for: bundleID),
           usageRecord.extendedLimitMinutes > 0 {
            extendedLimit = max(extendedLimit, baseLimit + Int(usageRecord.extendedLimitMinutes))
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
    
    // MARK: - Legacy Credit Methods (No longer used - puzzle system replaces credits)
    
    func deductCredit(reason: String, for usageRecord: AppUsageRecord? = nil) -> CreditTransaction? {
        // Credit system removed - puzzles are used instead
        return nil
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
        // No longer used
        return 0
    }
    
    func payAccountabilityFee() {
        // No longer used - puzzles replace accountability fee
    }
    
    func addCredits(amount: Int, reason: String) -> CreditTransaction? {
        // Credit system removed - puzzles are used instead
        return nil
    }
    
    // MARK: - Streak Management
    
    func checkAndUpdateStreakForYesterday() {
        let userProfile = getOrCreateUserProfile()
        let goals = getActiveAppGoals()
        let screenTimeService = ScreenTimeService.shared
        
        // Check if any limits were exceeded yesterday
        // At midnight reset, we check yesterday's final usage
        // Since usage resets at midnight, we check if current usage is 0 (new day just started)
        // and look at yesterday's usage records if available
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let startOfYesterday = calendar.startOfDay(for: yesterday)
        
        var hasExceededLimit = false
        
        // Check each goal to see if it was exceeded yesterday
        for goal in goals {
            guard let bundleID = goal.appBundleID else { continue }
            
            // Try to get yesterday's usage from Core Data
            if let usageRecord = getAppUsageRecord(for: bundleID, on: startOfYesterday) {
                if Int(usageRecord.actualUsageMinutes) >= Int(goal.dailyLimitMinutes) {
                    hasExceededLimit = true
                    break
                }
            } else {
                // If no record exists, check current usage (should be 0 at reset, but check anyway)
                let currentUsage = screenTimeService.getUsageMinutes(for: bundleID)
                if currentUsage >= Int(goal.dailyLimitMinutes) {
                    hasExceededLimit = true
                    break
                }
            }
        }
        
        if !hasExceededLimit {
            // No limits exceeded yesterday - increment streak
            let previousStreak = Int(userProfile.currentStreak)
            userProfile.currentStreak += 1
            if userProfile.currentStreak > userProfile.longestStreak {
                userProfile.longestStreak = userProfile.currentStreak
            }
            print("🔥 Streak updated: \(previousStreak) → \(userProfile.currentStreak) days")
        } else {
            // Limits were exceeded yesterday - reset streak
            if userProfile.currentStreak > 0 {
                print("💔 Streak broken: Was \(userProfile.currentStreak) days")
            }
            userProfile.currentStreak = 0
        }
        
        userProfile.updatedAt = Date()
        save()
    }
    
    func getAppUsageRecord(for bundleID: String, on date: Date) -> AppUsageRecord? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        // ⚠️ FIX: AppUsageRecord doesn't have appBundleID - need to query through appGoal relationship
        // First find the goal, then find the usage record
        let goals = getActiveAppGoals()
        guard let goal = goals.first(where: { $0.appBundleID == bundleID }) else {
            return nil
        }
        
        let request: NSFetchRequest<AppUsageRecord> = AppUsageRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "appGoal == %@ AND date >= %@ AND date < %@",
            goal,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
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
