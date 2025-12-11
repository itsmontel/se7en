import SwiftUI

struct ExtendLimitSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let app: MonitoredApp
    
    @State private var selectedHours: Int = 1
    @State private var selectedMinutes: Int = 0
    @State private var isExtending = false
    
    private var currentLimitMinutes: Int {
        app.dailyLimit
    }
    
    private var newLimitMinutes: Int {
        (selectedHours * 60) + selectedMinutes
    }
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Extend Limit")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                            
                            Text("Increase your daily limit for \(app.name)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Current Limit Card
                        VStack(spacing: 12) {
                            Text("Current Limit")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.textSecondary)
                            
                            Text(formatTime(currentLimitMinutes))
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                        
                        // Arrow
                        Image(systemName: "arrow.down")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.textSecondary)
                        
                        // New Limit Selection
                        VStack(spacing: 16) {
                            Text("New Limit")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            
                            // Hours Picker
                            VStack(spacing: 8) {
                                Text("Hours")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.textSecondary)
                                
                                Picker("Hours", selection: $selectedHours) {
                                    ForEach(0..<25) { hour in
                                        Text("\(hour)").tag(hour)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 120)
                            }
                            
                            // Minutes Picker
                            VStack(spacing: 8) {
                                Text("Minutes")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.textSecondary)
                                
                                Picker("Minutes", selection: $selectedMinutes) {
                                    ForEach(Array(stride(from: 0, to: 60, by: 15)), id: \.self) { minute in
                                        Text("\(minute)").tag(minute)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 120)
                            }
                            
                            // New Limit Display
                            VStack(spacing: 8) {
                                Text("New Limit")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.textSecondary)
                                
                                Text(formatTime(newLimitMinutes))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                            }
                            .padding(.top, 8)
                        }
                        .padding(20)
                        .background(Color.cardBackground)
                        .cornerRadius(16)
                        
                        // Extend Button
                        Button(action: extendLimit) {
                            HStack(spacing: 12) {
                                if isExtending {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                }
                                
                                Text(isExtending ? "Extending..." : "Extend Limit")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isExtending || newLimitMinutes <= currentLimitMinutes)
                        .opacity(isExtending || newLimitMinutes <= currentLimitMinutes ? 0.6 : 1.0)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func extendLimit() {
        guard newLimitMinutes > currentLimitMinutes else { return }
        
        isExtending = true
        HapticFeedback.medium.trigger()
        
        // Get bundle ID for the app
        let goals = CoreDataManager.shared.getActiveAppGoals()
        let matchingGoal = goals.first { $0.appName == app.name }
        guard let bundleID = matchingGoal?.appBundleID else {
            print("❌ No bundle ID found for app: \(app.name)")
            isExtending = false
            return
        }
        
        // Extend limit (no credit system - extensions are free)
        print("✅ Extending limit for \(app.name)")
        
        // Extend the limit
        let success = CoreDataManager.shared.extendAppLimit(
            for: bundleID,
            newLimitMinutes: newLimitMinutes
        )
        
        if success {
            // Refresh monitored apps to show new limit
            appState.refreshData()
            
            HapticFeedback.success.trigger()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                dismiss()
            }
        } else {
            isExtending = false
            HapticFeedback.error.trigger()
        }
    }
    
    private func formatTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
}

