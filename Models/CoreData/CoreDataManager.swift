import CoreData
import Foundation

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SE7ENDataModel")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
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
        save()
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
        plan.userProfile = getOrCreateUserProfile()
        save()
        return plan
    }
    
    func getOrCreateCurrentWeeklyPlan() -> WeeklyPlan {
        if let currentPlan = getCurrentWeeklyPlan() {
            return currentPlan
        }
        
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? Date()
        
        return createWeeklyPlan(startDate: startOfWeek, endDate: endOfWeek)
    }
    
    // MARK: - App Goal Methods
    
    func createAppGoal(appName: String, bundleID: String, dailyLimitMinutes: Int) -> AppGoal {
        let goal = AppGoal(context: context)
        goal.id = UUID()
        goal.appName = appName
        goal.appBundleID = bundleID
        goal.dailyLimitMinutes = Int32(dailyLimitMinutes)
        goal.createdAt = Date()
        goal.updatedAt = Date()
        goal.isActive = true
        save()
        return goal
    }
    
    func getActiveAppGoals() -> [AppGoal] {
        let request: NSFetchRequest<AppGoal> = AppGoal.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AppGoal.appName, ascending: true)]
        
        return (try? context.fetch(request)) ?? []
    }
    
    func updateAppGoal(_ goal: AppGoal, dailyLimitMinutes: Int) {
        goal.dailyLimitMinutes = Int32(dailyLimitMinutes)
        goal.updatedAt = Date()
        save()
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
    
    // MARK: - Credit Transaction Methods
    
    func deductCredit(reason: String, for usageRecord: AppUsageRecord? = nil) -> CreditTransaction {
        let transaction = CreditTransaction(context: context)
        transaction.id = UUID()
        transaction.date = Date()
        transaction.amount = -1
        transaction.reason = reason
        transaction.transactionType = "deduction"
        transaction.usageRecord = usageRecord
        transaction.weeklyPlan = getOrCreateCurrentWeeklyPlan()
        
        // Update weekly plan credits
        let weeklyPlan = getOrCreateCurrentWeeklyPlan()
        weeklyPlan.creditsRemaining = max(0, weeklyPlan.creditsRemaining - 1)
        
        save()
        return transaction
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
        weeklyPlan.creditsRemaining = min(7, weeklyPlan.creditsRemaining + Int32(amount))
        
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
}
