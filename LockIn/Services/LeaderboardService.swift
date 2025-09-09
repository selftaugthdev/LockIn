import FirebaseFirestore
import Foundation

@MainActor
class LeaderboardService: ObservableObject {
  @Published var weeklyTop50: [UserRow] = []
  @Published var dailyTop50: [UserRow] = []
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let db = Firestore.firestore()

  // Fetch top 50 users for weekly leaderboard
  func fetchWeeklyTop50() async throws -> [UserRow] {
    let snap = try await db.collection("users")
      .order(by: "weeklyCount", descending: true)
      .limit(to: 50)
      .getDocuments()
    return snap.documents.compactMap { doc in
      var userRow = try? doc.data(as: UserRow.self)
      userRow?.id = doc.documentID
      return userRow
    }
  }

  // Fetch top 50 users for daily leaderboard
  func fetchDailyTop50() async throws -> [UserRow] {
    let snap = try await db.collection("users")
      .order(by: "dailyCount", descending: true)
      .limit(to: 50)
      .getDocuments()
    return snap.documents.compactMap { doc in
      var userRow = try? doc.data(as: UserRow.self)
      userRow?.id = doc.documentID
      return userRow
    }
  }

  // Load both leaderboards
  func loadLeaderboards() async {
    isLoading = true
    errorMessage = nil
    
    do {
      async let weekly = fetchWeeklyTop50()
      async let daily = fetchDailyTop50()
      
      let (weeklyResults, dailyResults) = try await (weekly, daily)
      
      self.weeklyTop50 = weeklyResults
      self.dailyTop50 = dailyResults
    } catch {
      self.errorMessage = "Failed to load leaderboards: \(error.localizedDescription)"
      print("Error loading leaderboards: \(error)")
    }
    
    isLoading = false
  }

  // Refresh leaderboards
  func refreshLeaderboards() async {
    await loadLeaderboards()
  }
}
