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
        .environment(\.textCase, .none)
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
            
            BlockingView()
                .tabItem {
                    VStack {
                        Image(systemName: "hand.raised.fill")
                        Text("Limits")
                    }
                }
                .tag(1)
            
            GoalsView()
                .tabItem {
                    VStack {
                        Image(systemName: "chart.bar.fill")
                        Text("Stats")
                    }
                }
                .tag(2)
            
            AchievementsView()
                .tabItem {
                    VStack {
                        Image(systemName: "trophy.fill")
                        Text("Achievements")
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
        .environment(\.textCase, .none)
    }
}


