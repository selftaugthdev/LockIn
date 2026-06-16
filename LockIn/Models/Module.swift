import Foundation

// MARK: - Mental Edge (philosopher insight, shared across Module and legacy Program)

struct MentalEdge: Codable {
  let figure: String
  let sourceWork: String
  let year: String
  let content: String
}

// MARK: - Module (a 7-day standalone content unit)

struct Module: Codable, Identifiable {
  let id: String            // e.g. "wake_up", "machiavelli_protocol"
  let title: String         // e.g. "Wake Up"
  let tagline: String       // e.g. "See what's been happening to you"
  let philosopher: String   // primary philosopher for this module
  let order: Int            // position within its path (1-based); 0 if standalone
  let isPremium: Bool
  let days: [ModuleDay]
}

// MARK: - Module Day (7 per module)

struct ModuleDay: Codable, Identifiable {
  let dayNumber: Int        // 1–7
  let challengeTitle: String
  let challengeDescription: String
  let dailyAction: String
  let nightlyReflection: String
  let mentalEdge: MentalEdge
  let xpReward: Int

  var id: Int { dayNumber }
}

// MARK: - Module Path (an ordered sequence of modules, e.g. Foundation)

struct ModulePath: Codable, Identifiable {
  let id: String            // e.g. "foundation"
  let title: String         // e.g. "Foundation"
  let subtitle: String      // e.g. "4 modules · 28 days"
  let moduleIds: [String]   // ordered module IDs
}

// MARK: - Computed Properties

extension Module {
  var durationDays: Int { days.count }

  var totalXP: Int {
    days.reduce(0) { $0 + $1.xpReward }
  }
}
