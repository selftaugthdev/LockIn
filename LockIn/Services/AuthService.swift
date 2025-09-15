import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation

@MainActor
class AuthService: ObservableObject {
  @Published var currentUser: User?
  @Published var isAuthenticated = false
  @Published var isLoading = false
  @Published var uid: String?

  // Temporary flag to force onboarding for testing
  @Published var forceOnboarding = false

  private let db = Firestore.firestore()
  private var authStateListener: AuthStateDidChangeListenerHandle?

  init() {
    setupAuthStateListener()
  }

  deinit {
    if let listener = authStateListener {
      Auth.auth().removeStateDidChangeListener(listener)
    }
  }

  private func setupAuthStateListener() {
    authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
      Task { @MainActor in
        self?.uid = firebaseUser?.uid
        if let firebaseUser = firebaseUser {
          // Only load user data if we're not forcing onboarding
          if !(self?.forceOnboarding ?? false) {
            await self?.loadUserData(uid: firebaseUser.uid)
          } else {
            // If we're forcing onboarding, don't set authenticated state
            self?.currentUser = nil
            self?.isAuthenticated = false
          }
        } else {
          self?.currentUser = nil
          self?.isAuthenticated = false
        }
      }
    }
  }

  func signInAnonymously() async throws {
    isLoading = true
    defer { isLoading = false }

    do {
      let result = try await Auth.auth().signInAnonymously()
      let uid = result.user.uid

      // Ensure user document has required fields for leaderboard
      try await db.collection("users").document(uid).setData(
        [
          "createdAt": FieldValue.serverTimestamp(),
          "streakCount": 0,
          "premium": false,
          "friendCode": UUID().uuidString.prefix(8).uppercased(),
        ], merge: true)

      // Don't call loadUserData here - let the auth state listener handle it
      // after completeOnboarding() is called
    } catch {
      print("Error signing in anonymously: \(error)")
      throw error
    }
  }

  func signOut() throws {
    try Auth.auth().signOut()
  }

  /// Ensure we have an authenticated user and a user doc.
  func ensureSignedIn() async throws -> String {
    if let uid = Auth.auth().currentUser?.uid {
      return uid
    }

    // No current user, sign in anonymously
    let result = try await Auth.auth().signInAnonymously()
    let uid = result.user.uid

    // Bootstrap user doc
    try await db.collection("users").document(uid).setData(
      [
        "createdAt": FieldValue.serverTimestamp(),
        "streakCount": 0,
        "premium": false,
        "friendCode": UUID().uuidString.prefix(8).uppercased(),
      ], merge: true)

    return uid
  }

  // Temporary function to reset onboarding for testing
  func resetForTesting() {
    Task {
      do {
        // Set force onboarding first to prevent auto-restoration
        self.forceOnboarding = true
        self.currentUser = nil
        self.isAuthenticated = false

        // Then sign out
        try await signOut()

        print("Successfully reset authentication state and forced onboarding")
      } catch {
        print("Error resetting authentication: \(error)")
        // Even if sign out fails, we still want to force onboarding
        self.forceOnboarding = true
        self.currentUser = nil
        self.isAuthenticated = false
      }
    }
  }

  // Function to complete onboarding and clear the force flag
  func completeOnboarding() {
    forceOnboarding = false
    // If user is authenticated, load their data
    if let firebaseUser = Auth.auth().currentUser {
      Task {
        await loadUserData(uid: firebaseUser.uid)
      }
    }
  }

  func loadUserData(uid: String) async {
    do {
      let document = try await db.collection("users").document(uid).getDocument()

      if document.exists {
        // Try to decode the user, but fallback to a minimal user if decode fails
        if let user = try? document.data(as: User.self) {
          self.currentUser = user
          self.isAuthenticated = true
        } else {
          // Decode failed, create a fallback user
          print("Failed to decode user document, creating fallback user")
          let fallbackUser = User(
            id: uid,
            displayName: nil,
            createdAt: Date(),
            streakCount: 0,
            totalAura: 0,
            premium: false,
            lastCompleted: nil,
            friendCode: generateFriendCode()
          )
          self.currentUser = fallbackUser
          self.isAuthenticated = true
        }
      } else {
        // User document doesn't exist, create it
        let newUser = User(
          id: uid,
          displayName: nil,
          createdAt: Date(),
          streakCount: 0,
          totalAura: 0,
          premium: false,
          lastCompleted: nil,
          friendCode: generateFriendCode()
        )

        try await db.collection("users").document(uid).setData(from: newUser)
        self.currentUser = newUser
        self.isAuthenticated = true
      }
    } catch {
      print("Error loading user data: \(error)")
      // Even if there's an error, create a fallback user to prevent bouncing back to onboarding
      let fallbackUser = User(
        id: uid,
        displayName: nil,
        createdAt: Date(),
        streakCount: 0,
        totalAura: 0,
        premium: false,
        lastCompleted: nil,
        friendCode: generateFriendCode()
      )
      self.currentUser = fallbackUser
      self.isAuthenticated = true
    }
  }

  func updateUser(_ user: User) async throws {
    guard let uid = user.id else { return }

    do {
      // Only update fields that clients are allowed to modify
      // Counter fields (streakCount, totalCount, totalAura, lastCompleted) are handled by Cloud Functions
      var updateData: [String: Any] = [:]

      if let displayName = user.displayName {
        updateData["displayName"] = displayName
      }
      updateData["premium"] = user.premium
      if let friendCode = user.friendCode {
        updateData["friendCode"] = friendCode
      }

      try await db.collection("users").document(uid).updateData(updateData)

      // Update local user object
      self.currentUser = user
    } catch {
      print("Error updating user: \(error)")
      throw error
    }
  }

  private func generateFriendCode() -> String {
    let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0..<8).map { _ in characters.randomElement()! })
  }
}
