import Foundation
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit
import DeviceActivity

// DeviceActivity extensions moved to Extensions/DeviceActivityExtensions.swift

// MARK: - Family Activity Service

class FamilyActivityService: ObservableObject {
    static let shared = FamilyActivityService()
    
    @Published var selection = FamilyActivitySelection()
    @Published var isPresented = false
    
    private init() {}
    
    // MARK: - App Selection
    
    func presentAppPicker() {
        isPresented = true
    }
    
    func handleSelectionComplete() {
        isPresented = false
        
        // Process selected apps
        processSelectedApps()
    }
    
    private func processSelectedApps() {
        print("📱 Processing \(selection.applicationTokens.count) selected apps")
        
        // Convert selected apps to app goals
        for token in selection.applicationTokens {
            if let bundleID = extractBundleID(from: token) {
                let appName = getAppName(for: bundleID) ?? bundleID
                
                // Create app goal with default 60-minute limit
                let appState = AppState()
                appState.addAppGoal(
                    appName: appName,
                    bundleID: bundleID,
                    dailyLimitMinutes: 60
                )
                
                print("✅ Added app goal for: \(appName)")
            }
        }
        
        // Store the selection for Screen Time monitoring
        ScreenTimeService.shared.updateAppSelections(selection)
    }
    
    // MARK: - Helper Methods
    
    private func extractBundleID(from token: Any) -> String? {
        // Tokens from FamilyActivitySelection don't directly expose bundle ID
        // In a real implementation, you'd need to:
        // 1. Use the token directly with DeviceActivity APIs
        // 2. Or maintain a mapping of tokens to bundle IDs
        
        print("ℹ️  Token received - use directly with DeviceActivity")
        return nil // Would need Apple's internal API to extract
    }
    
    private func getAppName(for bundleID: String) -> String? {
        // In a real implementation, you might:
        // 1. Use LSApplicationWorkspace (private API)
        // 2. Maintain a hardcoded mapping of common apps
        // 3. Ask user to provide name
        
        let commonApps = [
            "com.burbn.instagram": "Instagram",
            "com.zhiliaoapp.musically": "TikTok",
            "com.toyopagroup.picaboo": "Snapchat",
            "com.facebook.Facebook": "Facebook",
            "com.atebits.Tweetie2": "Twitter",
            "com.youtube.YouTubeApp": "YouTube"
        ]
        
        return commonApps[bundleID] ?? bundleID.components(separatedBy: ".").last?.capitalized
    }
}

// MARK: - SwiftUI View for App Picker

struct FamilyActivityPickerView: View {
    @Binding var selection: FamilyActivitySelection
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Select Apps")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            isPresented = false
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            isPresented = false
                            FamilyActivityService.shared.handleSelectionComplete()
                        }
                    }
                }
        }
    }
}

// MARK: - ScreenTimeService Extension for App Selections

extension ScreenTimeService {
    
    func updateAppSelections(_ selection: FamilyActivitySelection) {
        print("🔄 Updating app selections with \(selection.applicationTokens.count) apps")
        
        // Store tokens for each selected app
        for token in selection.applicationTokens {
            // Since we can't extract bundle ID directly, we'll use the token hash as identifier
            let identifier = String(token.hashValue)
            
            var appSelection = FamilyActivitySelection()
            appSelection.applicationTokens = Set([token])
            
            monitoredAppSelections[identifier] = appSelection
            
            print("📱 Stored selection for app token: \(identifier)")
        }
        
        // Set up monitoring for all selected apps
        setupMonitoringForSelectedApps()
    }
    
    private func setupMonitoringForSelectedApps() {
        guard isAuthorized else {
            print("❌ Not authorized - cannot set up monitoring")
            return
        }
        
        print("🔧 Setting up monitoring for \(monitoredAppSelections.count) selected apps")
        
        // Create a combined schedule for all apps
        setupCombinedDeviceActivitySchedule()
    }
    
    private func setupCombinedDeviceActivitySchedule() {
        // Create daily schedule (reset at midnight)
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        
        // Get all monitored application tokens
        // Tokens from FamilyActivitySelection are compatible with DeviceActivity
        // We'll use them directly from the selections
        
        // Create events for warning and limit thresholds
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        
        for (identifier, selection) in monitoredAppSelections {
            // Get the app goal for this selection (if available)
            let goals = coreDataManager.getActiveAppGoals()
            let defaultLimit = 60 // Default 60 minutes if no goal found
            
            // Find matching goal (this is approximate since we can't match exactly)
            let goal = goals.first // Use first available goal as fallback
            let limitMinutes = goal?.dailyLimitMinutes ?? Int32(defaultLimit)
            
            // Warning at 80% of limit
            let warningMinutes = Int(Double(limitMinutes) * 0.8)
            
            let warningEvent = DeviceActivityEvent(
                applications: selection.applicationTokens,
                threshold: DateComponents(minute: warningMinutes)
            )
            
            let limitEvent = DeviceActivityEvent(
                applications: selection.applicationTokens,
                threshold: DateComponents(minute: Int(limitMinutes))
            )
            
            events[.warningEvent(for: identifier)] = warningEvent
            events[.limitEvent(for: identifier)] = limitEvent
        }
        
        do {
            // Start monitoring with combined schedule
            try deviceActivityCenter.startMonitoring(.se7enDaily, during: schedule, events: events)
            
            if !activeSchedules.contains(.se7enDaily) {
                activeSchedules.append(.se7enDaily)
            }
            
            let totalTokens = monitoredAppSelections.values.reduce(0) { $0 + $1.applicationTokens.count }
            print("✅ Started combined monitoring for \(totalTokens) apps")
        } catch {
            print("❌ Failed to start combined monitoring: \(error)")
        }
    }
}

