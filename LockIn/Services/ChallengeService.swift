import Combine
import FirebaseFirestore
import Foundation

@MainActor
class ChallengeService: ObservableObject {
  @Published var todaysChallenge: Challenge?
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
      let dayIndex = getCurrentDayIndex()

      // First try to get from Firestore
      let query = db.collection("challenges")
        .whereField("dayIndex", isEqualTo: dayIndex)
        .whereField("isActive", isEqualTo: true)
        .limit(to: 1)

      let snapshot = try await query.getDocuments()

      if let document = snapshot.documents.first {
        todaysChallenge = try document.data(as: Challenge.self)
      } else {
        // Fallback to preloaded challenges
        todaysChallenge = getPreloadedChallenge(for: dayIndex)
      }
    } catch {
      print("Error loading today's challenge: \(error)")
      errorMessage = "Failed to load today's challenge"
      // Fallback to preloaded
      let dayIndex = getCurrentDayIndex()
      todaysChallenge = getPreloadedChallenge(for: dayIndex)
    }

    isLoading = false
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
    return (daysSinceStart % 120) + 1  // Cycle through 120 challenges
  }

  private func loadPreloadedChallenges() {
    // This will be populated from PreloadedChallenges.json
    // For now, create some sample challenges
    preloadedChallenges = createSampleChallenges()
  }

  private func getPreloadedChallenge(for dayIndex: Int) -> Challenge? {
    let index = (dayIndex - 1) % preloadedChallenges.count
    return preloadedChallenges[index]
  }

  // MARK: - Sample Data (temporary)

  private func createSampleChallenges() -> [Challenge] {
    return [
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
  }

}

// MARK: - Errors

enum ChallengeError: Error, LocalizedError {
  case invalidUser
  case challengeNotFound
  case completionFailed

  var errorDescription: String? {
    switch self {
    case .invalidUser:
      return "Invalid user"
    case .challengeNotFound:
      return "Challenge not found"
    case .completionFailed:
      return "Failed to complete challenge"
    }
  }
}
