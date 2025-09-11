import FirebaseFirestore
import Foundation

struct Challenge: Codable, Identifiable {
  @DocumentID var id: String?
  let title: String
  let type: ChallengeType
  let difficulty: Int  // 1-5 scale
  let dayIndex: Int  // For daily challenges
  var isActive: Bool
  let customAura: Int?  // Custom Aura points for user-created challenges

  init(
    id: String? = nil,
    title: String,
    type: ChallengeType,
    difficulty: Int,
    dayIndex: Int,
    isActive: Bool = true,
    customAura: Int? = nil
  ) {
    // Don't set @DocumentID manually - let Firestore handle it
    self.title = title
    self.type = type
    self.difficulty = difficulty
    self.dayIndex = dayIndex
    self.isActive = isActive
    self.customAura = customAura
  }
}

enum ChallengeType: String, Codable, CaseIterable {
  case mindfulness = "mindfulness"
  case fitness = "fitness"
  case learning = "learning"
  case creativity = "creativity"
  case social = "social"
  case productivity = "productivity"
  case wellness = "wellness"
  case gratitude = "gratitude"

  var displayName: String {
    switch self {
    case .mindfulness: return "Mindfulness"
    case .fitness: return "Fitness"
    case .learning: return "Learning"
    case .creativity: return "Creativity"
    case .social: return "Social"
    case .productivity: return "Productivity"
    case .wellness: return "Wellness"
    case .gratitude: return "Gratitude"
    }
  }

  var emoji: String {
    switch self {
    case .mindfulness: return "🧘"
    case .fitness: return "💪"
    case .learning: return "📚"
    case .creativity: return "🎨"
    case .social: return "👥"
    case .productivity: return "⚡"
    case .wellness: return "🌱"
    case .gratitude: return "🙏"
    }
  }

  var color: String {
    switch self {
    case .mindfulness: return "#8B5CF6"  // Purple
    case .fitness: return "#EF4444"  // Red
    case .learning: return "#3B82F6"  // Blue
    case .creativity: return "#F59E0B"  // Orange
    case .social: return "#10B981"  // Green
    case .productivity: return "#6366F1"  // Indigo
    case .wellness: return "#22C55E"  // Green
    case .gratitude: return "#F97316"  // Orange
    }
  }
}

// MARK: - Difficulty Levels
extension Challenge {
  var difficultyText: String {
    switch difficulty {
    case 1: return "Easy"
    case 2: return "Light"
    case 3: return "Medium"
    case 4: return "Hard"
    case 5: return "Expert"
    default: return "Unknown"
    }
  }

  var auraPoints: Int {
    // Use custom Aura if provided, otherwise use difficulty-based calculation
    if let customAura = customAura {
      return customAura
    }
    return difficulty * 10  // 10, 20, 30, 40, 50 points for preloaded challenges
  }
}
