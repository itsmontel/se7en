import Foundation
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit
import DeviceActivity

// DeviceActivity extensions moved to Extensions/DeviceActivityExtensions.swift

// MARK: - Family Activity Service

@MainActor
final class FamilyActivityService: ObservableObject {
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
        print("🔄 Legacy updateAppSelections called with \(selection.applicationTokens.count) apps")
        print("ℹ️ This method is deprecated - use addAppGoalFromSelection() instead")
        
        // This method is now handled by addAppGoalFromSelection() in ScreenTimeService
        // which properly stores individual app tokens with real bundle IDs
    }
    
    // Removed duplicate monitoring setup - now handled by ScreenTimeService.setupMonitoringForApp()
}

