import Foundation

struct UserRow: Identifiable, Codable {
  var id: String?
  var displayName: String?
  var weeklyCount: Int
  var dailyCount: Int
  
  init(
    id: String? = nil,
    displayName: String? = nil,
    weeklyCount: Int = 0,
    dailyCount: Int = 0
  ) {
    self.id = id
    self.displayName = displayName
    self.weeklyCount = weeklyCount
    self.dailyCount = dailyCount
  }
}
