import SwiftUI

struct ContentView: View {
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var challengeService: ChallengeService
  @EnvironmentObject var moduleService: ModuleService
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
        if !moduleService.hasFetchedActiveModule {
          ZStack {
            Color.brandInk.ignoresSafeArea()
            VStack(spacing: 16) {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .brandYellow))
              if let error = moduleService.errorMessage {
                Text(error)
                  .font(.caption)
                  .foregroundColor(.red)
                  .padding(.horizontal, 32)
                  .multilineTextAlignment(.center)
              }
            }
          }
        } else if moduleService.activeModule == nil || moduleService.activeModule?.isComplete == true {
          ProgramSelectionView()
        } else {
          MainTabView()
        }
      } else {
        OnboardingView()
      }
    }
    .task(id: authService.isAuthenticated) {
      if authService.isAuthenticated && !authService.forceOnboarding {
        await moduleService.loadActiveModule()
      }
    }
    .onChange(of: authService.forceOnboarding) { forceOnboarding in
      if !forceOnboarding && authService.isAuthenticated {
        Task { await moduleService.loadActiveModule() }
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
    .environmentObject(ModuleService(auth: auth))
    .environmentObject(PaywallService(authService: auth))
}
