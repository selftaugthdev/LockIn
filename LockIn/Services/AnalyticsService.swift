import FirebaseAnalytics
import Foundation

class AnalyticsService {
  static let shared = AnalyticsService()

  private init() {}

  // MARK: - Core Events

  func logAppOpen() {
    Analytics.logEvent("app_open", parameters: nil)
  }

  func logChallengeView(challengeId: String, type: String, difficulty: Int) {
    Analytics.logEvent(
      "challenge_view",
      parameters: [
        "challenge_id": challengeId,
        "type": type,
        "difficulty": difficulty,
      ])
  }

  func logChallengeComplete(challengeId: String, type: String, difficulty: Int) {
    Analytics.logEvent(
      "challenge_complete",
      parameters: [
        "challenge_id": challengeId,
        "type": type,
        "difficulty": difficulty,
      ])
  }

  func logStreakIncremented(streakCount: Int) {
    Analytics.logEvent(
      "streak_incremented",
      parameters: [
        "streak_count": streakCount
      ])
  }

  func logLeaderboardView(scope: String) {
    Analytics.logEvent(
      "leaderboard_view",
      parameters: [
        "scope": scope
      ])
  }

  // MARK: - Premium Events

  func logPremiumView() {
    Analytics.logEvent("premium_view", parameters: nil)
  }

  func logPremiumStartCheckout() {
    Analytics.logEvent("premium_start_checkout", parameters: nil)
  }

  func logPremiumPurchaseSuccess() {
    Analytics.logEvent("premium_purchase_success", parameters: nil)
  }

  // MARK: - Social Events

  func logShareAttempt(type: String) {
    Analytics.logEvent(
      "share_attempt",
      parameters: [
        "type": type
      ])
  }

  // MARK: - User Properties

  func setUserProperties(user: User) {
    Analytics.setUserProperty("\(user.streakCount)", forName: "streak_count")
    Analytics.setUserProperty("\(user.premium)", forName: "is_premium")
    Analytics.setUserProperty(user.friendCode, forName: "friend_code")

    if let lastCompleted = user.lastCompleted {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      Analytics.setUserProperty(formatter.string(from: lastCompleted), forName: "last_completed")
    }
  }

  // MARK: - Custom Events

  func logCustomEvent(_ eventName: String, parameters: [String: Any]? = nil) {
    Analytics.logEvent(eventName, parameters: parameters)
  }
}
