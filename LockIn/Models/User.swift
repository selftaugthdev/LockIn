import FirebaseFirestore
import Foundation

struct User: Codable, Identifiable {
  var id: String?
  let displayName: String?
  let createdAt: Date
  var streakCount: Int
  var totalCount: Int
  var totalAura: Int?
  var premium: Bool
  var lastCompleted: Date?
  let friendCode: String?

  init(
    id: String? = nil,
    displayName: String? = nil,
    createdAt: Date = Date(),
    streakCount: Int = 0,
    totalCount: Int = 0,
    totalAura: Int? = 0,
    premium: Bool = false,
    lastCompleted: Date? = nil,
    friendCode: String? = UUID().uuidString.prefix(8).uppercased()
  ) {
    // Don't set @DocumentID manually - let Firestore handle it
    self.displayName = displayName
    self.createdAt = createdAt
    self.streakCount = streakCount
    self.totalCount = totalCount
    self.totalAura = totalAura
    self.premium = premium
    self.lastCompleted = lastCompleted
    self.friendCode = friendCode
  }

  // Custom decoder to handle missing fields gracefully
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    id = try? container.decodeIfPresent(String.self, forKey: .id)
    displayName = try? container.decodeIfPresent(String.self, forKey: .displayName)
    createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
    streakCount = (try? container.decode(Int.self, forKey: .streakCount)) ?? 0
    totalCount = (try? container.decode(Int.self, forKey: .totalCount)) ?? 0
    totalAura = try? container.decodeIfPresent(Int.self, forKey: .totalAura)
    premium = (try? container.decode(Bool.self, forKey: .premium)) ?? false
    lastCompleted = try? container.decodeIfPresent(Date.self, forKey: .lastCompleted)
    friendCode = try? container.decodeIfPresent(String.self, forKey: .friendCode)
  }
}

// MARK: - Computed Properties
extension User {
  var isStreakActive: Bool {
    guard let lastCompleted = lastCompleted else { return false }
    let calendar = Calendar.current
    let today = Date()

    // Check if last completion was today or yesterday
    if calendar.isDate(lastCompleted, inSameDayAs: today) {
      return true
    }

    if calendar.isDate(
      lastCompleted, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today) ?? today)
    {
      return true
    }

    return false
  }

  var streakStatus: StreakStatus {
    if streakCount == 0 {
      return .none
    } else if isStreakActive {
      return .active
    } else {
      return .broken
    }
  }
}

enum StreakStatus {
  case none
  case active
  case broken
}
