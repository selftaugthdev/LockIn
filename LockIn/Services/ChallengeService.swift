import Combine
import FirebaseFirestore
import Foundation

@MainActor
class ChallengeService: ObservableObject {
  @Published var todaysChallenge: Challenge?
  @Published var availableChallenges: [Challenge] = []
  @Published var selectedChallenges: [Challenge] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let db = Firestore.firestore()
  private let auth: AuthService
  private var preloadedChallenges: [Challenge] = []

  init(auth: AuthService) {
    self.auth = auth
    loadPreloadedChallenges()
  }

  // MARK: - Challenge Loading

  func loadTodaysChallenge() async {
    isLoading = true
    errorMessage = nil

    do {
      // Load available challenges (preloaded + custom)
      await loadAvailableChallenges()

      // Load user's selected challenges for today
      await loadSelectedChallenges()

      // Set today's challenge (first selected or default)
      if let firstSelected = selectedChallenges.first {
        todaysChallenge = firstSelected
      } else {
        // For free users, show a default challenge
        todaysChallenge = availableChallenges.first
      }
    } catch {
      print("Error loading today's challenge: \(error)")
      errorMessage = "Failed to load today's challenge"
      // Fallback to preloaded
      todaysChallenge = preloadedChallenges.first
    }

    isLoading = false
  }

  func loadAvailableChallenges() async {
    // Load preloaded challenges
    availableChallenges = preloadedChallenges

    // Load custom challenges for Pro users
    if let uid = auth.uid {
      do {
        let customQuery = db.collection("customChallenges")
          .whereField("userId", isEqualTo: uid)
          .whereField("isActive", isEqualTo: true)

        let snapshot = try await customQuery.getDocuments()
        let customChallenges = try snapshot.documents.compactMap { document in
          try document.data(as: Challenge.self)
        }

        availableChallenges.append(contentsOf: customChallenges)
      } catch {
        print("Error loading custom challenges: \(error)")
      }
    }
  }

  func loadSelectedChallenges() async {
    guard let uid = auth.uid else { return }

    do {
      let today = getTodayString()
      let query = db.collection("selectedChallenges")
        .whereField("userId", isEqualTo: uid)
        .whereField("date", isEqualTo: today)

      let snapshot = try await query.getDocuments()
      let selectedIds = snapshot.documents.compactMap { $0.data()["challengeId"] as? String }

      selectedChallenges = availableChallenges.filter { challenge in
        selectedIds.contains(challenge.id ?? "")
      }
    } catch {
      print("Error loading selected challenges: \(error)")
      selectedChallenges = []
    }
  }

  // MARK: - Challenge Selection

  func selectChallenge(_ challenge: Challenge, isPro: Bool) async throws {
    guard let uid = auth.uid else { throw ChallengeError.invalidUser }

    // Check if user can select more challenges
    if !isPro && selectedChallenges.count >= 1 {
      throw ChallengeError.limitReached
    }

    // Add to selected challenges
    if !selectedChallenges.contains(where: { $0.id == challenge.id }) {
      selectedChallenges.append(challenge)

      // Save to Firestore
      let today = getTodayString()
      let docId = "\(uid)_\(today)_\(challenge.id ?? UUID().uuidString)"

      try await db.collection("selectedChallenges").document(docId).setData([
        "userId": uid,
        "challengeId": challenge.id ?? "",
        "date": today,
        "selectedAt": FieldValue.serverTimestamp(),
      ])

      // Update today's challenge if it's the first one
      if selectedChallenges.count == 1 {
        todaysChallenge = challenge
      }
    }
  }

  func deselectChallenge(_ challenge: Challenge) async throws {
    guard let uid = auth.uid else { throw ChallengeError.invalidUser }

    // Remove from selected challenges
    selectedChallenges.removeAll { $0.id == challenge.id }

    // Remove from Firestore
    let today = getTodayString()
    let docId = "\(uid)_\(today)_\(challenge.id ?? UUID().uuidString)"

    try await db.collection("selectedChallenges").document(docId).delete()

    // Update today's challenge if needed
    if todaysChallenge?.id == challenge.id {
      todaysChallenge = selectedChallenges.first
    }
  }

  func createCustomChallenge(title: String, type: ChallengeType, difficulty: Int) async throws
    -> Challenge
  {
    guard let uid = auth.uid else { throw ChallengeError.invalidUser }

    let challenge = Challenge(
      title: title,
      type: type,
      difficulty: difficulty,
      dayIndex: 0,  // Custom challenges don't have dayIndex
      isActive: true
    )

    // Save to Firestore
    let docRef = db.collection("customChallenges").document()
    try await docRef.setData([
      "id": docRef.documentID,
      "title": challenge.title,
      "type": challenge.type.rawValue,
      "difficulty": challenge.difficulty,
      "dayIndex": challenge.dayIndex,
      "isActive": challenge.isActive,
      "userId": uid,
      "createdAt": FieldValue.serverTimestamp(),
    ])

    // Add to available challenges
    var updatedChallenge = challenge
    updatedChallenge.id = docRef.documentID
    availableChallenges.append(updatedChallenge)

    return updatedChallenge
  }

  // MARK: - Challenge Completion

  func completeChallenge(_ challenge: Challenge) async throws -> Completion {
    // Ensure we have a signed-in user
    let uid = try await auth.ensureSignedIn()

    print("UID before write:", uid)

    // Prefer a real challenge.id from Firestore; fall back to a slug
    let cid =
      (challenge.id?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
        $0.isEmpty ? nil : $0
      }
      ?? challenge.title
      .lowercased()
      .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

    // Guard against empty
    guard !cid.isEmpty else {
      print("❌ No challengeId; aborting write")
      throw ChallengeError.challengeNotFound
    }

    // Simple completion - just write to Firestore
    // Cloud Functions will handle counter increments
    // Use deterministic doc ID to prevent duplicate completions per day
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    let dateString = formatter.string(from: Date())
    let docId = "\(uid)_\(dateString)_UTC"
    let ref = db.collection("completions").document(docId)
    try await ref.setData([
      "userId": uid,
      "challengeId": cid,
      "challengeTitle": challenge.title,  // helpful for lists
      "completedAt": FieldValue.serverTimestamp(),
    ])

    print("✅ completion written with challengeId=\(cid)")

    // Create a simple completion object for return (not saved to Firestore)
    let completion = Completion(
      userId: uid,
      challengeId: cid,
      completedAt: Timestamp()
    )

    return completion
  }

  // MARK: - Private Methods

  private func getCurrentDayIndex() -> Int {
    let calendar = Calendar.current
    let startOfYear = calendar.dateInterval(of: .year, for: Date())?.start ?? Date()
    let daysSinceStart = calendar.dateComponents([.day], from: startOfYear, to: Date()).day ?? 0
    return (daysSinceStart % 90) + 1  // Cycle through 90 challenges
  }

  private func getTodayString() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter.string(from: Date())
  }

  private func loadPreloadedChallenges() {
    // Load from PreloadedChallenges.json
    if let url = Bundle.main.url(forResource: "PreloadedChallenges", withExtension: "json"),
      let data = try? Data(contentsOf: url)
    {
      do {
        let challenges = try JSONDecoder().decode([PreloadedChallenge].self, from: data)
        preloadedChallenges = challenges.enumerated().map { index, preloaded in
          var challenge = Challenge(
            title: preloaded.title,
            type: ChallengeType(rawValue: preloaded.type) ?? .wellness,
            difficulty: preloaded.difficulty,
            dayIndex: preloaded.dayIndex,
            isActive: true
          )
          // Generate a unique ID for preloaded challenges
          challenge.id = "preloaded_\(index)"
          return challenge
        }
      } catch {
        print("Error loading preloaded challenges: \(error)")
        preloadedChallenges = createSampleChallenges()
      }
    } else {
      preloadedChallenges = createSampleChallenges()
    }
  }

  // MARK: - Sample Data (temporary)

  private func createSampleChallenges() -> [Challenge] {
    let sampleData = [
      Challenge(title: "Take 5 deep breaths", type: .mindfulness, difficulty: 1, dayIndex: 1),
      Challenge(title: "Do 10 push-ups", type: .fitness, difficulty: 2, dayIndex: 2),
      Challenge(title: "Learn 3 new words", type: .learning, difficulty: 1, dayIndex: 3),
      Challenge(
        title: "Draw something for 5 minutes", type: .creativity, difficulty: 2, dayIndex: 4),
      Challenge(title: "Text someone you care about", type: .social, difficulty: 1, dayIndex: 5),
      Challenge(title: "Organize your workspace", type: .productivity, difficulty: 2, dayIndex: 6),
      Challenge(title: "Drink 8 glasses of water", type: .wellness, difficulty: 2, dayIndex: 7),
      Challenge(
        title: "Write down 3 things you're grateful for", type: .gratitude, difficulty: 1,
        dayIndex: 8),
    ]

    // Add unique IDs to sample challenges
    return sampleData.enumerated().map { index, challenge in
      var updatedChallenge = challenge
      updatedChallenge.id = "sample_\(index)"
      return updatedChallenge
    }
  }

}

// MARK: - Supporting Types

struct PreloadedChallenge: Codable {
  let title: String
  let type: String
  let difficulty: Int
  let dayIndex: Int
}

// MARK: - Errors

enum ChallengeError: Error, LocalizedError {
  case invalidUser
  case challengeNotFound
  case completionFailed
  case limitReached

  var errorDescription: String? {
    switch self {
    case .invalidUser:
      return "Invalid user"
    case .challengeNotFound:
      return "Challenge not found"
    case .completionFailed:
      return "Failed to complete challenge"
    case .limitReached:
      return "Challenge limit reached for free users"
    }
  }
}
