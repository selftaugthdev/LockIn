import SwiftUI

struct ContentView: View {
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var challengeService: ChallengeService
  @EnvironmentObject var programService: ProgramService
  @EnvironmentObject var paywallService: PaywallService

  var body: some View {
    Group {
      if authService.isInitializing {
        ZStack {
          Color.brandInk.ignoresSafeArea()
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .brandYellow))
        }
      } else if authService.isAuthenticated && !authService.forceOnboarding {
        if programService.activeProgram == nil {
          ProgramSelectionView()
        } else {
          MainTabView()
        }
      } else {
        OnboardingView()
      }
    }
    .onChange(of: authService.isAuthenticated) { isAuthenticated in
      if isAuthenticated && !authService.forceOnboarding {
        Task { await programService.loadActiveProgram() }
      }
    }
    .onChange(of: authService.forceOnboarding) { forceOnboarding in
      if !forceOnboarding && authService.isAuthenticated {
        Task { await programService.loadActiveProgram() }
      }
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

      AdvisorView()
        .tabItem {
          Image(systemName: "brain.head.profile")
          Text("Advisor")
        }

      LibraryView()
        .tabItem {
          Image(systemName: "books.vertical")
          Text("Library")
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
    .environmentObject(PaywallService(authService: auth))
}
