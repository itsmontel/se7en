import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingContainerView()
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    VStack {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                }
                .tag(0)
            
            GoalsView()
                .tabItem {
                    VStack {
                        Image(systemName: "chart.bar.fill")
                        Text("Stats")
                    }
                }
                .tag(1)
            
            AchievementsView()
                .tabItem {
                    VStack {
                        Image(systemName: "trophy.fill")
                        Text("Achievements")
                    }
                }
                .tag(2)
            
            SubscriptionView()
                .tabItem {
                    VStack {
                        Image(systemName: "creditcard.fill")
                        Text("Credits")
                    }
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    VStack {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                    }
                }
                .tag(4)
        }
        .tint(.primary)
    }
}


