import SwiftUI
import FamilyControls

struct SelectAllAppsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @Binding var selection: FamilyActivitySelection
    @State private var showingFamilyPicker = false
    
    private let screenTimeService = ScreenTimeService.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Image(systemName: "apps.iphone")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 12) {
                        Text("Select All Your Apps")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.textPrimary)
                        
                        Text("Choose all apps you want to track for screen time. This will show your total usage and top distractions.")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    if !selection.applicationTokens.isEmpty {
                        VStack(spacing: 8) {
                            Text("\(selection.applicationTokens.count) apps selected")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            
                            Button(action: {
                                // Save the selection
                                screenTimeService.allAppsSelection = selection
                                
                                // Refresh dashboard
                                NotificationCenter.default.post(name: .screenTimeDataUpdated, object: nil)
                                
                                dismiss()
                            }) {
                                Text("Save Selection")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.green)
                                    .cornerRadius(14)
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        }
                    } else {
                        Button(action: {
                            showingFamilyPicker = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                Text("Open App Picker")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(14)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationTitle("Select All Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
            }
            .sheet(isPresented: $showingFamilyPicker) {
                if screenTimeService.isAuthorized {
                    FamilyActivityPickerWrapper(
                        selection: $selection,
                        onDone: {
                            if !selection.applicationTokens.isEmpty {
                                // Save the selection
                                screenTimeService.allAppsSelection = selection
                                
                                // Refresh dashboard
                                NotificationCenter.default.post(name: .screenTimeDataUpdated, object: nil)
                                
                                print("✅ Selected \(selection.applicationTokens.count) apps for all apps tracking")
                                showingFamilyPicker = false
                            }
                        },
                        onSkip: {
                            showingFamilyPicker = false
                        },
                        isOnboarding: false
                    )
                }
            }
            .onAppear {
                if screenTimeService.isAuthorized && selection.applicationTokens.isEmpty {
                    showingFamilyPicker = true
                }
            }
        }
    }
}


