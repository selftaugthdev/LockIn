import FirebaseFirestore
import Foundation

@MainActor
class ModuleService: ObservableObject {
  @Published var availableModules: [Module] = []
  @Published var currentPath: ModulePath?
  @Published var activeModule: UserModule?
  @Published var todaysModuleDay: ModuleDay?
  @Published var completedModuleIds: [String] = []
  @Published var isLoading = false
  @Published var hasFetchedActiveModule = false
  @Published var errorMessage: String?

  private let db = Firestore.firestore()
  private let auth: AuthService

  init(auth: AuthService) {
    self.auth = auth
    loadBundledContent()
  }

  // MARK: - Bundle Loading

  func loadBundledContent() {
    let moduleFiles = ["module_wake_up", "module_armor_up", "module_sharpen", "module_operate"]
    let decoder = JSONDecoder()

    availableModules = moduleFiles.compactMap { name in
      // Try with Modules/ subdirectory first, fall back to bundle root
      let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Modules")
        ?? Bundle.main.url(forResource: name, withExtension: "json")
      guard let url, let data = try? Data(contentsOf: url) else {
        print("ModuleService: Could not find \(name).json")
        return nil
      }
      do {
        return try decoder.decode(Module.self, from: data)
      } catch {
        print("ModuleService: Failed to decode \(name).json — \(error)")
        return nil
      }
    }

    let pathUrl = Bundle.main.url(forResource: "path_foundation", withExtension: "json", subdirectory: "Modules")
      ?? Bundle.main.url(forResource: "path_foundation", withExtension: "json")
    if let pathUrl, let data = try? Data(contentsOf: pathUrl) {
      currentPath = try? decoder.decode(ModulePath.self, from: data)
    }

    print("ModuleService: loaded \(availableModules.count) modules, path: \(currentPath?.id ?? "none")")
  }

  // MARK: - Load Active Module

  func loadActiveModule() async {
    guard let uid = auth.uid else { return }
    isLoading = true
    defer {
      isLoading = false
      hasFetchedActiveModule = true
    }

    do {
      async let activeSnap = db.collection("userModules")
        .whereField("userId", isEqualTo: uid)
        .whereField("status", isEqualTo: ModuleStatus.active.rawValue)
        .getDocuments()

      async let completedSnap = db.collection("userModules")
        .whereField("userId", isEqualTo: uid)
        .whereField("status", isEqualTo: ModuleStatus.completed.rawValue)
        .getDocuments()

      let (activeResult, completedResult) = try await (activeSnap, completedSnap)

      completedModuleIds = completedResult.documents.compactMap { doc -> String? in
        (try? doc.data(as: UserModule.self))?.moduleId
      }

      let allActive = activeResult.documents.compactMap { doc -> UserModule? in
        do {
          return try doc.data(as: UserModule.self)
        } catch {
          print("ModuleService: failed to decode doc \(doc.documentID) — \(error)")
          return nil
        }
      }

      guard !allActive.isEmpty else {
        activeModule = nil
        todaysModuleDay = nil
        return
      }

      let best = allActive.sorted { $0.completedDays.count > $1.completedDays.count }.first!

      for dup in allActive where dup.id != best.id {
        try? await abandonModule(dup)
      }

      var userModule = best
      userModule = await advanceDayIfNeeded(userModule)
      activeModule = userModule
      resolveTodaysDay(for: userModule)

    } catch {
      print("ModuleService: Error loading active module — \(error)")
      errorMessage = "Failed to load your module."
    }
  }

  // MARK: - Enrollment

  func enrollInModule(_ module: Module, pathId: String? = nil) async throws {
    guard let uid = auth.uid else { throw ModuleError.invalidUser }

    if let existing = activeModule {
      try await abandonModule(existing)
    }

    let userModule = UserModule(
      userId: uid,
      moduleId: module.id,
      moduleTitle: module.title,
      pathId: pathId
    )

    let docRef = db.collection("userModules").document(userModule.id)
    try docRef.setData(from: userModule)

    activeModule = userModule
    resolveTodaysDay(for: userModule)
  }

  // MARK: - Complete Today's Day

  func completeModuleDay() async throws {
    guard let uid = auth.uid else { throw ModuleError.invalidUser }
    guard var userModule = activeModule else { throw ModuleError.noModuleActive }
    guard let day = todaysModuleDay else { throw ModuleError.noModuleActive }

    let xpEarned = day.xpReward
    userModule.markDayCompleted(day: userModule.currentDay, xpEarned: xpEarned)

    let docRef = db.collection("userModules").document(userModule.id)
    try docRef.setData(from: userModule)

    if userModule.isComplete {
      if !completedModuleIds.contains(userModule.moduleId) {
        completedModuleIds.append(userModule.moduleId)
      }
      activeModule = userModule   // keep briefly so completion screen can read it
      todaysModuleDay = nil
    } else {
      activeModule = userModule
    }

    // Update user XP and streak
    let today = Date()
    let calendar = Calendar.current
    var newStreakCount = 1

    if let user = auth.currentUser, let lastCompleted = user.lastCompleted {
      if calendar.isDate(lastCompleted, inSameDayAs: today) {
        newStreakCount = user.streakCount
      } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                calendar.isDate(lastCompleted, inSameDayAs: yesterday) {
        newStreakCount = user.streakCount + 1
      }
    }

    try await db.collection("users").document(uid).updateData([
      "totalXP": FieldValue.increment(Int64(xpEarned)),
      "streakCount": newStreakCount,
      "lastCompleted": Timestamp(date: today),
    ])

    if var user = auth.currentUser {
      user.streakCount = newStreakCount
      user.lastCompleted = today
      auth.currentUser = user
    }
  }

  // MARK: - Day Advancement

  private func advanceDayIfNeeded(_ userModule: UserModule) async -> UserModule {
    var module = userModule
    let calendar = Calendar.current
    let daysSinceStart = calendar.dateComponents(
      [.day],
      from: calendar.startOfDay(for: module.startDate),
      to: calendar.startOfDay(for: Date())
    ).day ?? 0
    let expectedDay = min(daysSinceStart + 1, UserModule.durationDays)

    while module.currentDay < expectedDay {
      module.advanceDay()
    }

    if module.currentDay != userModule.currentDay || module.missedDays != userModule.missedDays {
      do {
        let docRef = db.collection("userModules").document(module.id)
        try docRef.setData(from: module)
      } catch {
        print("ModuleService: Failed to persist day advancement — \(error)")
      }
    }

    return module
  }

  private func resolveTodaysDay(for userModule: UserModule) {
    guard let module = availableModules.first(where: { $0.id == userModule.moduleId }) else {
      todaysModuleDay = nil
      return
    }
    let dayIndex = userModule.currentDay - 1
    guard dayIndex >= 0 && dayIndex < module.days.count else {
      todaysModuleDay = nil
      return
    }
    todaysModuleDay = module.days[dayIndex]
  }

  // MARK: - Abandon

  func abandonModule(_ userModule: UserModule) async throws {
    var abandoned = userModule
    abandoned.status = .abandoned

    let docRef = db.collection("userModules").document(abandoned.id)
    try docRef.setData(from: abandoned)

    if activeModule?.id == abandoned.id {
      activeModule = nil
      todaysModuleDay = nil
    }
  }

  // MARK: - Path Helpers

  func nextModule(after moduleId: String) -> Module? {
    guard let path = currentPath,
          let idx = path.moduleIds.firstIndex(of: moduleId),
          idx + 1 < path.moduleIds.count
    else { return nil }
    return availableModules.first { $0.id == path.moduleIds[idx + 1] }
  }

  func isModuleLocked(_ module: Module) -> Bool {
    guard let path = currentPath,
          let idx = path.moduleIds.firstIndex(of: module.id),
          idx > 0
    else { return false }
    let previousId = path.moduleIds[idx - 1]
    return !completedModuleIds.contains(previousId)
  }

  // MARK: - Computed

  var isTodayCompleted: Bool {
    guard let m = activeModule else { return false }
    return m.completedDays.contains(m.currentDay)
  }

  var activeModuleContent: Module? {
    guard let active = activeModule else { return nil }
    return availableModules.first { $0.id == active.moduleId }
  }
}

// MARK: - Errors

enum ModuleError: Error, LocalizedError {
  case invalidUser
  case noModuleActive
  case enrollmentFailed

  var errorDescription: String? {
    switch self {
    case .invalidUser: return "No signed-in user"
    case .noModuleActive: return "No active module"
    case .enrollmentFailed: return "Failed to enroll in module"
    }
  }
}
