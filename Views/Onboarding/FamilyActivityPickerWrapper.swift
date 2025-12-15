import SwiftUI
import FamilyControls

struct FamilyActivityPickerWrapper: View {
    @Binding var selection: FamilyActivitySelection
    let onDone: () -> Void
    let onSkip: () -> Void
    var isOnboarding: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                FamilyActivityPicker(selection: $selection)
                
                // Overlay buttons at the bottom since FamilyActivityPicker doesn't show toolbar properly
                VStack {
                    Spacer()
                    
                    HStack(spacing: 16) {
                        if !isOnboarding {
                            Button(action: {
                                onSkip()
                                dismiss()
                            }) {
                                Text("Cancel")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                        }
                        
                        Button(action: {
                            print("🔘 Continue button tapped")
                            print("📱 Selection has \(selection.applicationTokens.count) apps")
                            print("📱 Selection has \(selection.categoryTokens.count) categories")
                            
                            // Validate selection during onboarding
                            // Accept either individual apps OR categories (categories include all apps in them)
                            if isOnboarding && selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
                                print("⚠️ No apps or categories selected during onboarding - require selection")
                                return
                            }
                            
                            // Categories are actually better - they include all apps in those categories
                            if !selection.categoryTokens.isEmpty {
                                print("✅ Categories selected - this will track all apps in those categories")
                            }
                            
                            print("✅ Processing selection...")
                            
                            // Call onDone to process the selection (this will handle dismissal)
                            // Process asynchronously to avoid blocking UI
                            onDone()
                        }) {
                            Text(isOnboarding ? "Continue" : "Done")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .disabled(false) // Ensure button is always enabled
                        .allowsHitTesting(true) // Ensure button is tappable
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .padding(.top, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.appBackground.opacity(0.0), Color.appBackground.opacity(0.98)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120)
                        .ignoresSafeArea(edges: .bottom)
                    )
                    .allowsHitTesting(true) // Ensure entire button area is tappable
                }
            }
            .navigationTitle(isOnboarding ? "Select ALL Apps" : "Select Apps to Monitor")
            .navigationBarTitleDisplayMode(.inline)
            .textCase(.none)
        }
    }
}

