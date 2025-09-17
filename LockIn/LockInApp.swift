import FirebaseCore
import GoogleSignIn
import SwiftUI

@main
struct LockInApp: App {
  @StateObject private var authService = AuthService()
  @StateObject private var challengeService: ChallengeService

  init() {
    FirebaseApp.configure()

    // Configure Google Sign-In
    guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
      let plist = NSDictionary(contentsOfFile: path),
      let clientId = plist["CLIENT_ID"] as? String
    else {
      fatalError("GoogleService-Info.plist not found or CLIENT_ID missing")
    }
    GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)

    // Initialize services with authService
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
