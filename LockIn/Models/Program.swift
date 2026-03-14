import Foundation

// MARK: - Program (template/blueprint, bundled as JSON)

struct Program: Codable, Identifiable {
  let id: String
  let title: String
  let subtitle: String
  let description: String
  let durationDays: Int
  let category: ProgramCategory
  let difficulty: ProgramDifficulty
  let isPremium: Bool
  let days: [ProgramDay]
}

// MARK: - Program Day (self-contained challenge content)

struct ProgramDay: Codable, Identifiable {
  let dayNumber: Int
  let challengeTitle: String
  let challengeDescription: String
  let category: ChallengeType
  let xpReward: Int
  let phase: ProgramPhase

  var id: Int { dayNumber }
}

// MARK: - Enums

enum ProgramCategory: String, Codable, CaseIterable {
  case discipline = "discipline"
  case fitness = "fitness"
  case mindfulness = "mindfulness"
  case productivity = "productivity"
  case rebuild = "rebuild"

  var displayName: String {
    switch self {
    case .discipline: return "Discipline"
    case .fitness: return "Fitness"
    case .mindfulness: return "Mindfulness"
    case .productivity: return "Productivity"
    case .rebuild: return "Rebuild"
    }
  }
}

enum ProgramDifficulty: String, Codable, CaseIterable {
  case beginner = "beginner"
  case intermediate = "intermediate"
  case hard = "hard"

  var displayName: String {
    switch self {
    case .beginner: return "Beginner"
    case .intermediate: return "Intermediate"
    case .hard: return "Hard"
    }
  }
}

enum ProgramPhase: String, Codable, CaseIterable {
  case foundation = "foundation"
  case build = "build"
  case push = "push"
  case peak = "peak"

  var displayName: String {
    switch self {
    case .foundation: return "Foundation"
    case .build: return "Build"
    case .push: return "Push"
    case .peak: return "Peak"
    }
  }

  var tagline: String {
    switch self {
    case .foundation: return "Build the habit"
    case .build: return "Add the pressure"
    case .push: return "Test your limits"
    case .peak: return "This is who you are now"
    }
  }
}

// MARK: - Computed Properties

extension Program {
  var totalXP: Int {
    days.reduce(0) { $0 + $1.xpReward }
  }
}

extension ProgramDay {
  // Which week this day falls in (1-indexed)
  var weekNumber: Int {
    ((dayNumber - 1) / 7) + 1
  }
}
