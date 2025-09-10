import SwiftUI

struct ContentView: View {
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var challengeService: ChallengeService
  // @State private var paywallService: PaywallService?

  var body: some View {
    Group {
      if authService.isAuthenticated && !authService.forceOnboarding {
        MainTabView()
        // if let paywallService = paywallService {
        //   MainTabView()
        //     .environmentObject(paywallService)
        // } else {
        //   ProgressView()
        //     .progressViewStyle(CircularProgressViewStyle(tint: .brandYellow))
        // }
      } else {
        OnboardingView()
      }
    }
    // .onAppear {
    //   if paywallService == nil {
    //     paywallService = PaywallService(authService: authService)
    //   }
    // }
  }
}

struct MainTabView: View {
  var body: some View {
    TabView {
      DailyChallengeView()
        .tabItem {
          Image(systemName: "target")
          Text("Challenge")
        }

      ProgressView()
        .tabItem {
          Image(systemName: "chart.line.uptrend.xyaxis")
          Text("Progress")
        }

      LeaderboardView()
        .tabItem {
          Image(systemName: "trophy")
          Text("Leaderboard")
        }

      SettingsView()
        .tabItem {
          Image(systemName: "gear")
          Text("Settings")
        }
    }
    .accentColor(.brandYellow)
  }
}

#Preview {
  ContentView()
    .environmentObject(AuthService())
    .environmentObject(ChallengeService(auth: AuthService()))
}
