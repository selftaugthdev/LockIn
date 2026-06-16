import Foundation

// MARK: - UserModule (a user's active or completed run of a module)

struct UserModule: Codable, Identifiable {
  var id: String
  let userId: String
  let moduleId: String
  let moduleTitle: String
  let pathId: String?       // nil if the module was started standalone
  let startDate: Date
  var currentDay: Int
  var completedDays: [Int]
  var missedDays: [Int]
  var totalXPEarned: Int
  var status: ModuleStatus

  init(
    id: String = UUID().uuidString,
    userId: String,
    moduleId: String,
    moduleTitle: String,
    pathId: String? = nil,
    startDate: Date = Date(),
    currentDay: Int = 1,
    completedDays: [Int] = [],
    missedDays: [Int] = [],
    totalXPEarned: Int = 0,
    status: ModuleStatus = .active
  ) {
    self.id = id
    self.userId = userId
    self.moduleId = moduleId
    self.moduleTitle = moduleTitle
    self.pathId = pathId
    self.startDate = startDate
    self.currentDay = currentDay
    self.completedDays = completedDays
    self.missedDays = missedDays
    self.totalXPEarned = totalXPEarned
    self.status = status
  }
}

// MARK: - Module Status

enum ModuleStatus: String, Codable {
  case active = "active"
  case completed = "completed"
  case abandoned = "abandoned"
}

// MARK: - Computed Properties

extension UserModule {
  static let durationDays = 7

  var progressPercentage: Double {
    Double(completedDays.count) / Double(UserModule.durationDays)
  }

  var daysRemaining: Int {
    max(0, UserModule.durationDays - completedDays.count)
  }

  var isComplete: Bool { status == .completed }

  mutating func markDayCompleted(day: Int, xpEarned: Int) {
    if !completedDays.contains(day) {
      completedDays.append(day)
    }
    totalXPEarned += xpEarned
    if completedDays.count >= UserModule.durationDays {
      status = .completed
    }
  }

  mutating func advanceDay() {
    let previous = currentDay
    if !completedDays.contains(previous) && !missedDays.contains(previous) {
      missedDays.append(previous)
    }
    currentDay = min(currentDay + 1, UserModule.durationDays)
  }
}
