import Combine
import FirebaseAuth
import FirebaseFirestore
import Foundation
import RevenueCat

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
            // Add a small delay to allow auth state to stabilize during linking
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
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

  /// Check if current user is anonymous
  var isAnonymous: Bool {
    return Auth.auth().currentUser?.isAnonymous ?? false
  }

  /// Link anonymous user to Apple credential
  func linkWithApple(credential: AuthCredential) async throws {
    guard let currentUser = Auth.auth().currentUser, currentUser.isAnonymous else {
      throw NSError(
        domain: "AuthService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
    }

    do {
      let result = try await currentUser.link(with: credential)
      print("Successfully linked anonymous user to Apple account")

      // Sync RevenueCat with the new user ID
      await syncRevenueCat()

      // User data is preserved since UID stays the same
    } catch let error as NSError {
      if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
        // User already has an account with this credential - need to merge
        if let existingCredential = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey]
          as? AuthCredential
        {
          try await mergeWithExistingAccount(
            existingCredential: existingCredential, currentUID: currentUser.uid)
        }
      } else {
        throw error
      }
    }
  }

  /// Link anonymous user to Google credential
  func linkWithGoogle(credential: AuthCredential) async throws {
    guard let currentUser = Auth.auth().currentUser else {
      throw NSError(
        domain: "AuthService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No current user"])
    }

    print("AuthService: Current user UID: \(currentUser.uid)")
    print("AuthService: User is anonymous: \(currentUser.isAnonymous)")

    // If user is not anonymous, sign them in directly instead of linking
    if !currentUser.isAnonymous {
      print("AuthService: User is not anonymous, signing in directly with Google credential")
      let result = try await Auth.auth().signIn(with: credential)
      print("AuthService: Successfully signed in with Google account")

      // Wait a moment for auth state to stabilize
      try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

      // Sync RevenueCat with the new user ID
      await syncRevenueCat()
      return
    }

    do {
      let result = try await currentUser.link(with: credential)
      print("Successfully linked anonymous user to Google account")

      // Sync RevenueCat with the new user ID
      await syncRevenueCat()

      // User data is preserved since UID stays the same
    } catch let error as NSError {
      if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
        // User already has an account with this credential - need to merge
        if let existingCredential = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey]
          as? AuthCredential
        {
          try await mergeWithExistingAccount(
            existingCredential: existingCredential, currentUID: currentUser.uid)
        }
      } else {
        throw error
      }
    }
  }

  /// Merge anonymous user data with existing account
  private func mergeWithExistingAccount(existingCredential: AuthCredential, currentUID: String)
    async throws
  {
    // Sign in with the existing credential to get the permanent UID
    let result = try await Auth.auth().signIn(with: existingCredential)
    let permanentUID = result.user.uid

    // Merge data from anonymous UID to permanent UID
    try await mergeUserData(fromUID: currentUID, toUID: permanentUID)

    // Delete the anonymous user
    try await Auth.auth().currentUser?.delete()
  }

  /// Merge user data from one UID to another
  func mergeUserData(fromUID: String, toUID: String) async throws {
    let fromDoc = db.collection("users").document(fromUID)
    let toDoc = db.collection("users").document(toUID)

    // Get both user documents
    let fromData = try await fromDoc.getDocument()
    let toData = try await toDoc.getDocument()

    var mergedData: [String: Any] = [:]

    if fromData.exists, let fromDict = fromData.data() {
      mergedData = fromDict
    }

    if toData.exists, let toDict = toData.data() {
      // Merge with preference for higher values (better streaks, etc.)
      for (key, value) in toDict {
        if let fromValue = mergedData[key] {
          // Keep the better value for numeric fields
          if key == "streakCount" || key == "totalAura" || key == "bestStreak" {
            if let fromNum = fromValue as? Int, let toNum = value as? Int {
              mergedData[key] = max(fromNum, toNum)
            }
          } else if key == "lastCompleted" {
            // Keep the more recent completion
            if let fromDate = fromValue as? Timestamp, let toDate = value as? Timestamp {
              mergedData[key] = fromDate.dateValue() > toDate.dateValue() ? fromValue : value
            }
          } else {
            // For other fields, prefer the existing account's data
            mergedData[key] = value
          }
        } else {
          mergedData[key] = value
        }
      }
    }

    // Add migration flag
    mergedData["migratedFrom"] = fromUID
    mergedData["migratedAt"] = FieldValue.serverTimestamp()

    // Update the permanent user document
    try await toDoc.setData(mergedData, merge: true)

    // Copy subcollections (completions, selectedChallenges, customChallenges)
    try await copySubcollection(fromUID: fromUID, toUID: toUID, collection: "completions")
    try await copySubcollection(fromUID: fromUID, toUID: toUID, collection: "selectedChallenges")
    try await copySubcollection(fromUID: fromUID, toUID: toUID, collection: "customChallenges")

    // Delete the anonymous user document
    try await fromDoc.delete()
  }

  /// Copy a subcollection from one user to another
  private func copySubcollection(fromUID: String, toUID: String, collection: String) async throws {
    let fromCollection = db.collection("users").document(fromUID).collection(collection)
    let toCollection = db.collection("users").document(toUID).collection(collection)

    let documents = try await fromCollection.getDocuments()

    for document in documents.documents {
      let data = document.data()
      try await toCollection.document(document.documentID).setData(data)
    }
  }

  /// Reset local data for anonymous users
  func resetLocalData() async throws {
    guard let currentUser = Auth.auth().currentUser, currentUser.isAnonymous else {
      throw NSError(
        domain: "AuthService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
    }

    // Delete user document and subcollections
    let userDoc = db.collection("users").document(currentUser.uid)
    try await userDoc.delete()

    // Delete subcollections
    let collections = ["completions", "selectedChallenges", "customChallenges"]
    for collection in collections {
      let subcollection = userDoc.collection(collection)
      let documents = try await subcollection.getDocuments()
      for document in documents.documents {
        try await document.reference.delete()
      }
    }

    // Sign out and sign back in anonymously to get a fresh start
    try Auth.auth().signOut()
    try await signInAnonymously()
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
        try signOut()

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

        try db.collection("users").document(uid).setData(from: newUser)
        self.currentUser = newUser
        self.isAuthenticated = true
      }
    } catch {
      print("Error loading user data: \(error)")
      // Check if this is a permission error during linking process
      if let firestoreError = error as? NSError,
        firestoreError.domain == "FIRFirestoreErrorDomain" && firestoreError.code == 7
      {
        print(
          "Firestore permission error during linking - this is expected, will retry after linking completes"
        )
        // Don't create fallback user during linking process
        return
      }

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

  /// Sync RevenueCat with current user ID
  private func syncRevenueCat() async {
    guard let uid = Auth.auth().currentUser?.uid else { return }

    do {
      let (customerInfo, _) = try await Purchases.shared.logIn(uid)
      print("RevenueCat synced successfully for user: \(uid)")

      // Update premium status based on RevenueCat
      if let currentUser = self.currentUser {
        var updatedUser = currentUser
        updatedUser.premium = customerInfo.entitlements.all["pro"]?.isActive == true
        self.currentUser = updatedUser
      }
    } catch {
      print("Failed to sync RevenueCat: \(error)")
    }
  }
}
