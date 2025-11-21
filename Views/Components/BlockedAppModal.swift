import SwiftUI

struct BlockedAppModal: View {
    @Binding var isPresented: Bool
    let appName: String
    let bundleID: String?
    @EnvironmentObject var appState: AppState
    
    init(isPresented: Binding<Bool>, appName: String, bundleID: String? = nil) {
        self._isPresented = isPresented
        self.appName = appName
        self.bundleID = bundleID
    }
    
    @State private var showButtons = false
    @State private var petScale: CGFloat = 0.8
    
    private var userName: String {
        appState.userName.isEmpty ? "there" : appState.userName
    }
    
    private var petName: String {
        appState.userPet?.name ?? "your pet"
    }
    
    private var petType: String {
        appState.userPet?.type.folderName.lowercased() ?? "dog"
    }
    
    private var sickPetImageName: String {
        "\(petType)sick"
    }
    
    private var creditsRemaining: Int {
        appState.credits
    }
    
    private var failureCount: Int {
        appState.getCurrentFailureCount()
    }
    
    private var penaltyCredits: Int {
        appState.getNextFailurePenalty()
    }
    
    // Check if accountability fee has been paid today (means at least one failure already occurred)
    private var hasPaidAccountabilityFeeToday: Bool {
        let weeklyPlan = CoreDataManager.shared.getOrCreateCurrentWeeklyPlan()
        let today = Calendar.current.startOfDay(for: Date())
        if let paidDate = weeklyPlan.accountabilityFeePaidDate {
            return Calendar.current.startOfDay(for: paidDate) == today
        }
        return false
    }
    
    
    // Determine if this is a subsequent failure (after accountability fee paid)
    // If accountability fee is paid today and credits are 7, this is a subsequent failure
    private var isSubsequentFailure: Bool {
        hasPaidAccountabilityFeeToday && creditsRemaining >= 7
    }
    
    // Get the actual failure number for display
    // If accountability fee is paid, this is at least the 2nd failure
    private var displayFailureNumber: Int {
        if isSubsequentFailure {
            // If accountability fee paid, this is at least 2nd failure
            // Use failureCount + 1, but ensure it's at least 2
            return max(2, failureCount + 1)
        } else {
            // First failure - use failureCount + 1
            return failureCount + 1
        }
    }
    
    private var displayFailureOrdinal: String {
        let count = displayFailureNumber
        switch count {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(count)th"
        }
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    // Don't allow dismissing by tapping outside
                }
            
            // Modal card - centered and constrained to safe area
            VStack {
                Spacer()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Pet Image Section with gradient background
                        ZStack {
                            // Gradient background
                            LinearGradient(
                                colors: [
                                    Color.error.opacity(0.15),
                                    Color.error.opacity(0.05),
                                    Color.cardBackground
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            
                            VStack(spacing: 20) {
                                // Sick pet image
                                Image(sickPetImageName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 160, height: 160)
                                    .scaleEffect(petScale)
                                    .shadow(color: Color.error.opacity(0.3), radius: 20, x: 0, y: 10)
                                    .id(sickPetImageName) // Force re-render
                            }
                            .padding(.top, 30)
                            .padding(.bottom, 20)
                        }
                        
                        // Content Section
                        VStack(spacing: 18) {
                            // Title
                            VStack(spacing: 10) {
                                Text("Daily Limit Reached")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                // Divider line
                                Rectangle()
                                    .fill(LinearGradient(
                                        colors: [Color.error.opacity(0.5), Color.error.opacity(0.2)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(height: 3)
                                    .cornerRadius(1.5)
                                    .padding(.horizontal, 30)
                            }
                            .padding(.top, 24)
                            
                            // Message
                            VStack(spacing: 12) {
                                Text("Bad news, \(userName)!")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                
                                Text("You've hit your daily limit for **\(appName)**. As a result, \(petName) is feeling sick, and SE7EN has blocked this app until tomorrow at midnight.")
                                    .font(.system(size: 15, weight: .regular, design: .rounded))
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                // Progressive penalty warning and explanation
                                if isSubsequentFailure {
                                    // Subsequent failure after accountability fee paid - don't show "first failure" message
                                    Text("You've exceeded your limit for **\(appName)**. Since you've already paid your accountability fee today, no additional credits will be deducted.")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.error)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, 4)
                                    
                                    Text("You've already paid your accountability fee for today (have 7 credits). This app is blocked because you exceeded its limit. If you exceed limits on other apps today, they'll also be blocked but no additional credits will be deducted. Credits reset to 7 daily at midnight.")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.textPrimary.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, 4)
                                } else {
                                    // First failure - show penalty warning
                                    Text("This is your **\(displayFailureOrdinal) failure** this week. You'll lose **\(penaltyCredits) credit\(penaltyCredits == 1 ? "" : "s")** for this failure.")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.error)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.top, 4)
                                    
                                    // Show explanation based on credits
                                    if creditsRemaining < 7 {
                                        Text("To continue using it today, you need to buy credits to reach **7 credits** (accountability fee). Once you have 7 credits, you can unblock this app. Other apps that haven't exceeded their limits will continue to work normally. Credits reset to 7 daily at midnight.")
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundColor(.textPrimary.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                            .lineSpacing(3)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                            
                            // Credit indicator
                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(creditsRemaining < 7 ? .error : .primary)
                                    
                                    Text("\(creditsRemaining) / 7 credits")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(creditsRemaining < 7 ? .error : .textPrimary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(creditsRemaining < 7 ? Color.error.opacity(0.1) : Color.primary.opacity(0.1))
                                .cornerRadius(10)
                                
                                if creditsRemaining < 7 {
                                    Text("Need \(7 - creditsRemaining) more credit\(7 - creditsRemaining == 1 ? "" : "s") to unblock")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.error)
                                } else {
                                    Text("Accountability fee paid - can unblock")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.textSecondary)
                                }
                            }
                            .padding(.top, 2)
                            
                            // Buttons
                            if showButtons {
                                VStack(spacing: 12) {
                                    // Unlock button (only enabled if credits >= 7)
                                    if creditsRemaining < 7 {
                                        Button(action: {
                                            HapticFeedback.medium.trigger()
                                            dismissModal()
                                            // Navigate to credits/purchase screen
                                            NotificationCenter.default.post(name: NSNotification.Name("OpenCreditsView"), object: nil)
                                        }) {
                                            HStack(spacing: 10) {
                                                Image(systemName: "creditcard.fill")
                                                    .font(.system(size: 17, weight: .semibold))
                                                
                                                Text("Buy \(7 - creditsRemaining) Credit\(7 - creditsRemaining == 1 ? "" : "s") to Unblock")
                                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.primary, Color.primary.opacity(0.8)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(DesignSystem.cornerRadiusMedium)
                                            .shadow(color: Color.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                                        }
                                    } else {
                                        Button(action: {
                                            HapticFeedback.medium.trigger()
                                            unblockWithCredit()
                                        }) {
                                            HStack(spacing: 10) {
                                                Image(systemName: "lock.open.fill")
                                                    .font(.system(size: 17, weight: .semibold))
                                                
                                                Text("Unblock App")
                                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(
                                                LinearGradient(
                                                    colors: [Color.primary, Color.primary.opacity(0.8)],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .cornerRadius(DesignSystem.cornerRadiusMedium)
                                            .shadow(color: Color.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                                        }
                                    }
                                    
                                    // Wait till tomorrow button
                                    Button(action: {
                                        HapticFeedback.light.trigger()
                                        dismissModal()
                                    }) {
                                        HStack(spacing: 10) {
                                            Image(systemName: "clock.fill")
                                                .font(.system(size: 17, weight: .semibold))
                                            
                                            Text("I Can Wait Till Tomorrow")
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.primary.opacity(0.1))
                                        .cornerRadius(DesignSystem.cornerRadiusMedium)
                                    }
                                }
                                .padding(.top, 6)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
                .frame(maxWidth: 600)
                .frame(maxHeight: UIScreen.main.bounds.height * 0.85)
                .background(Color.cardBackground)
                .cornerRadius(DesignSystem.cornerRadiusLarge)
                .shadow(color: Color.black.opacity(0.3), radius: 40, x: 0, y: 20)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .scaleEffect(isPresented ? 1.0 : 0.9)
            .opacity(isPresented ? 1.0 : 0.0)
        }
        .onAppear {
            // Animate pet entrance
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                petScale = 1.0
            }
            
            // Animate buttons appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    showButtons = true
                }
            }
            
            // Trigger haptic feedback
            HapticFeedback.medium.trigger()
        }
    }
    
    private func unblockWithCredit() {
        // Use provided bundleID or find it from Core Data app goals
        var appBundleID = bundleID
        if appBundleID == nil {
            // Look up bundleID from Core Data AppGoal by app name
            let coreDataManager = CoreDataManager.shared
            let goals = coreDataManager.getActiveAppGoals()
            let matchingGoal = goals.first { $0.appName == appName }
            appBundleID = matchingGoal?.appBundleID
        }
        
        guard let finalBundleID = appBundleID else {
            print("❌ Could not find bundle ID for app: \(appName)")
            HapticFeedback.error.trigger()
            return
        }
        
        // Unblock with credit
        let success = ScreenTimeService.shared.unblockAppWithCredit(finalBundleID)
        
        if success {
            // Update app state
            appState.refreshData()
            
            // Show success feedback
            HapticFeedback.success.trigger()
            
            // Dismiss modal after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismissModal()
            }
        } else {
            // Show error feedback
            HapticFeedback.error.trigger()
        }
    }
    
    private func dismissModal() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

#Preview {
    BlockedAppModal(isPresented: .constant(true), appName: "Instagram", bundleID: "com.instagram.instagram")
        .environmentObject(AppState())
}

