import FirebaseFirestore
import Foundation

struct Completion: Codable, Identifiable {
  @DocumentID var id: String?
  let userId: String
  let challengeId: String
  let completedAt: Timestamp

  init(
    id: String? = nil,
    userId: String,
    challengeId: String,
    completedAt: Timestamp = Timestamp()
  ) {
    // Don't set @DocumentID manually - let Firestore handle it
    self.userId = userId
    self.challengeId = challengeId
    self.completedAt = completedAt
  }
}

// MARK: - Leaderboard Entry
struct LeaderboardEntry: Codable, Identifiable {
  let userId: String
  let displayName: String
  let streakWeekly: Int
  let totalAura: Int

  var id: String { userId }
}

// MARK: - Weekly Leaderboard
struct WeeklyLeaderboard: Codable, Identifiable {
  @DocumentID var id: String?
  let weekKey: String  // Format: "2024-W01"
  let entries: [LeaderboardEntry]
  let generatedAt: Date

  init(
    id: String? = nil,
    weekKey: String,
    entries: [LeaderboardEntry],
    generatedAt: Date = Date()
  ) {
    // Don't set @DocumentID manually - let Firestore handle it
    self.weekKey = weekKey
    self.entries = entries
    self.generatedAt = generatedAt
  }
}

// MARK: - Helper Extensions
extension WeeklyLeaderboard {
  static func currentWeekKey() -> String {
    let calendar = Calendar.current
    let now = Date()
    let year = calendar.component(.year, from: now)
    let weekOfYear = calendar.component(.weekOfYear, from: now)
    return "\(year)-W\(String(format: "%02d", weekOfYear))"
  }

  var topEntries: [LeaderboardEntry] {
    return Array(entries.prefix(50))  // Top 50 as per PRD
  }
}
