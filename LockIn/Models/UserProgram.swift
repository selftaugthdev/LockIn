import Foundation

// MARK: - UserProgram (a user's active enrollment in a program)

struct UserProgram: Codable, Identifiable {
  var id: String
  let userId: String
  let programId: String
  let programTitle: String
  let programDurationDays: Int
  let startDate: Date
  var currentDay: Int
  var completedDays: [Int]       // e.g. [1, 2, 3, 5] — day 4 was missed
  var missedDays: [Int]          // days not completed on time
  var recoveryDays: [Int]        // days marked as recovery (double challenge)
  var totalXPEarned: Int
  var status: ProgramStatus
  var recoveryReminderState: RecoveryReminderState?

  init(
    id: String = UUID().uuidString,
    userId: String,
    programId: String,
    programTitle: String,
    programDurationDays: Int,
    startDate: Date = Date(),
    currentDay: Int = 1,
    completedDays: [Int] = [],
    missedDays: [Int] = [],
    recoveryDays: [Int] = [],
    totalXPEarned: Int = 0,
    status: ProgramStatus = .active,
    recoveryReminderState: RecoveryReminderState? = nil
  ) {
    self.id = id
    self.userId = userId
    self.programId = programId
    self.programTitle = programTitle
    self.programDurationDays = programDurationDays
    self.startDate = startDate
    self.currentDay = currentDay
    self.completedDays = completedDays
    self.missedDays = missedDays
    self.recoveryDays = recoveryDays
    self.totalXPEarned = totalXPEarned
    self.status = status
    self.recoveryReminderState = recoveryReminderState
  }
}

// MARK: - Program Status

enum ProgramStatus: String, Codable {
  case active = "active"
  case completed = "completed"
  case abandoned = "abandoned"
}

// MARK: - Recovery Reminder State

struct RecoveryReminderState: Codable {
  let recoveryDate: Date
  var remindersFired: Int          // 0, 1, 2, or 3
  var lastReminderTime: Date?
  var completed: Bool
}

// MARK: - Computed Properties

extension UserProgram {
  var isRecoveryDay: Bool {
    recoveryDays.contains(currentDay)
  }

  var progressPercentage: Double {
    guard programDurationDays > 0 else { return 0 }
    return Double(completedDays.count) / Double(programDurationDays)
  }

  var daysRemaining: Int {
    max(0, programDurationDays - completedDays.count)
  }

  var longestStreakInProgram: Int {
    guard !completedDays.isEmpty else { return 0 }
    let sorted = completedDays.sorted()
    var longest = 1
    var current = 1

    for i in 1..<sorted.count {
      if sorted[i] == sorted[i - 1] + 1 {
        current += 1
        longest = max(longest, current)
      } else {
        current = 1
      }
    }
    return longest
  }

  // Advance to the next day, marking yesterday as missed if not completed
  mutating func advanceDay() {
    let previousDay = currentDay
    if !completedDays.contains(previousDay) && !missedDays.contains(previousDay) {
      missedDays.append(previousDay)
      // Next day becomes a recovery day
      recoveryDays.append(previousDay + 1)
    }
    currentDay += 1
  }

  mutating func markDayCompleted(day: Int, xpEarned: Int) {
    if !completedDays.contains(day) {
      completedDays.append(day)
    }
    totalXPEarned += xpEarned

    if currentDay >= programDurationDays && completedDays.count >= programDurationDays {
      status = .completed
    }
  }
}
