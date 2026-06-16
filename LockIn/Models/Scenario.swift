import Foundation

struct Scenario: Codable, Identifiable {
  let id: String
  let title: String
  let hook: String
  let category: ScenarioCategory
  let philosopherId: String
  let openingPrompt: String

  var philosopher: AdvisorFigure {
    AdvisorFigure(rawValue: philosopherId) ?? .machiavelli
  }
}

enum ScenarioCategory: String, Codable, CaseIterable {
  case work = "Work"
  case relationships = "Relationships"
  case identity = "Identity"
  case pressure = "Pressure"
  case power = "Power"
}

extension Scenario {
  static func loadAll() -> [Scenario] {
    guard let url = Bundle.main.url(forResource: "scenarios", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let decoded = try? JSONDecoder().decode([Scenario].self, from: data)
    else { return [] }
    return decoded
  }
}
