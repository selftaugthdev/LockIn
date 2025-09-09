import FirebaseCore
import SwiftUI

@main
struct LockInApp: App {
  @StateObject private var authService = AuthService()
  @StateObject private var challengeService: ChallengeService

  init() {
    FirebaseApp.configure()
    // Initialize challengeService with authService
    let auth = AuthService()
    _authService = StateObject(wrappedValue: auth)
    _challengeService = StateObject(wrappedValue: ChallengeService(auth: auth))
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(authService)
        .environmentObject(challengeService)
        .onAppear {
          AnalyticsService.shared.logAppOpen()
        }
    }
  }
}
