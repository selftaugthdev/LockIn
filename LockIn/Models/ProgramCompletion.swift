import Foundation

// MARK: - ProgramCompletion (permanent record when a user finishes a program)

struct ProgramCompletion: Codable, Identifiable {
  let id: String
  let userId: String
  let programId: String
  let programTitle: String
  let programCategory: ProgramCategory
  let programDifficulty: ProgramDifficulty
  let startDate: Date
  let completionDate: Date
  let durationDays: Int
  let totalXPEarned: Int
  let challengesCompleted: Int
  let recoveryDaysOvercome: Int     // missed days they recovered from
  let longestStreak: Int
  let completedChallenges: [CompletedChallengeRecord]

  init(from userProgram: UserProgram, program: Program, completionDate: Date = Date()) {
    self.id = UUID().uuidString
    self.userId = userProgram.userId
    self.programId = program.id
    self.programTitle = program.title
    self.programCategory = program.category
    self.programDifficulty = program.difficulty
    self.startDate = userProgram.startDate
    self.completionDate = completionDate
    self.durationDays = program.durationDays
    self.totalXPEarned = userProgram.totalXPEarned
    self.challengesCompleted = userProgram.completedDays.count
    self.recoveryDaysOvercome = userProgram.missedDays.count
    self.longestStreak = userProgram.longestStreakInProgram
    self.completedChallenges = program.days.map { day in
      CompletedChallengeRecord(
        id: UUID().uuidString,
        dayNumber: day.dayNumber,
        challengeTitle: day.challengeTitle,
        xpEarned: userProgram.completedDays.contains(day.dayNumber) ? day.xpReward : 0,
        completedAt: completionDate,   // approximate — detailed timestamps can be added later
        wasRecoveryDay: userProgram.recoveryDays.contains(day.dayNumber),
        phase: day.phase
      )
    }
  }
}

// MARK: - Completed Challenge Record (one entry per day in the certificate)

struct CompletedChallengeRecord: Codable, Identifiable {
  let id: String
  let dayNumber: Int
  let challengeTitle: String
  let xpEarned: Int
  let completedAt: Date
  let wasRecoveryDay: Bool
  let phase: ProgramPhase
}

// MARK: - Computed Properties

extension ProgramCompletion {
  var durationFormatted: String {
    "\(durationDays)-Day"
  }

  var completionDateFormatted: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter.string(from: completionDate)
  }

  var startDateFormatted: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter.string(from: startDate)
  }

  // Summary stats for the certificate
  var perfectDays: Int {
    completedChallenges.filter { $0.xpEarned > 0 && !$0.wasRecoveryDay }.count
  }

  var recoveryDaysCompleted: Int {
    completedChallenges.filter { $0.wasRecoveryDay && $0.xpEarned > 0 }.count
  }
}
