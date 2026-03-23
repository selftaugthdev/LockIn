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

// MARK: - Mental Edge (philosopher insight for each day)

struct MentalEdge: Codable {
  let figure: String
  let sourceWork: String
  let year: String
  let content: String
}

// MARK: - Program Day (self-contained challenge content)

struct ProgramDay: Codable, Identifiable {
  let dayNumber: Int
  let challengeTitle: String
  let challengeDescription: String
  let dailyAction: String
  let nightlyReflection: String
  let mentalEdge: MentalEdge
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
  case wakeUp = "wake_up"
  case armorUp = "armor_up"
  case sharpen = "sharpen"
  case operate = "operate"

  var displayName: String {
    switch self {
    case .wakeUp: return "WAKE UP"
    case .armorUp: return "ARMOR UP"
    case .sharpen: return "SHARPEN"
    case .operate: return "OPERATE"
    }
  }

  var tagline: String {
    switch self {
    case .wakeUp: return "See what's been happening to you"
    case .armorUp: return "Build your psychological defenses"
    case .sharpen: return "Develop strategic intelligence"
    case .operate: return "Become the man who can't be played"
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
  var weekNumber: Int {
    ((dayNumber - 1) / 7) + 1
  }
}
