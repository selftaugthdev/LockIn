import SwiftUI

struct ContentView: View {
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var challengeService: ChallengeService
  @EnvironmentObject var programService: ProgramService
  @State private var paywallService: PaywallService?

  var body: some View {
    Group {
      if authService.isAuthenticated && !authService.forceOnboarding {
        if let paywallService = paywallService {
          if programService.activeProgram == nil {
            ProgramSelectionView()
              .environmentObject(paywallService)
          } else {
            MainTabView()
              .environmentObject(paywallService)
          }
        } else {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .brandYellow))
        }
      } else {
        OnboardingView()
      }
    }
    .onAppear {
      if paywallService == nil {
        paywallService = PaywallService(authService: authService)
      }
      Task { await programService.loadActiveProgram() }
    }
  }
}

struct MainTabView: View {
  var body: some View {
    TabView {
      ProgramDayView()
        .tabItem {
          Image(systemName: "target")
          Text("Today")
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
  let auth = AuthService()
  ContentView()
    .environmentObject(auth)
    .environmentObject(ChallengeService(auth: auth))
    .environmentObject(ProgramService(auth: auth))
}
