import FirebaseFirestore
import Foundation
import UserNotifications

@MainActor
class ProgramService: ObservableObject {
  @Published var availablePrograms: [Program] = []
  @Published var activeProgram: UserProgram?
  @Published var todaysProgramDay: ProgramDay?
  @Published var recoveryBonusDay: ProgramDay?   // only set on recovery days
  @Published var isLoading = false
  @Published var hasFetchedActiveProgram = false
  @Published var errorMessage: String?

  private let db = Firestore.firestore()
  private let auth: AuthService

  init(auth: AuthService) {
    self.auth = auth
    loadAvailablePrograms()
  }

  // MARK: - Program Library (bundled JSON)

  func loadAvailablePrograms() {
    let programFiles = ["foundation_30"]

    availablePrograms = programFiles.compactMap { name in
      guard
        let url = Bundle.main.url(forResource: name, withExtension: "json"),
        let data = try? Data(contentsOf: url)
      else {
        print("ProgramService: Could not find \(name).json in bundle")
        return nil
      }

      do {
        let decoder = JSONDecoder()
        return try decoder.decode(Program.self, from: data)
      } catch {
        print("ProgramService: Failed to decode \(name).json — \(error)")
        return nil
      }
    }
  }

  // MARK: - Load Active Program

  func loadActiveProgram() async {
    guard let uid = auth.uid else {
      print("ProgramService: loadActiveProgram — uid is nil, skipping")
      return
    }
    isLoading = true
    defer {
      isLoading = false
      hasFetchedActiveProgram = true
    }

    print("ProgramService: loading active program for uid \(uid)")

    do {
      let snapshot = try await db.collection("userPrograms")
        .whereField("userId", isEqualTo: uid)
        .whereField("status", isEqualTo: ProgramStatus.active.rawValue)
        .getDocuments()

      print("ProgramService: found \(snapshot.documents.count) raw docs, \(snapshot.documents.map { $0.documentID })")

      let allActive = snapshot.documents.compactMap { doc -> UserProgram? in
        do {
          return try doc.data(as: UserProgram.self)
        } catch {
          print("ProgramService: failed to decode doc \(doc.documentID) — \(error)")
          return nil
        }
      }

      print("ProgramService: decoded \(allActive.count) active program(s)")

      guard !allActive.isEmpty else {
        activeProgram = nil
        todaysProgramDay = nil
        recoveryBonusDay = nil
        return
      }

      // Pick the program with the most progress (most completed days),
      // falling back to the most recently started if tied.
      let best = allActive.sorted {
        if $0.completedDays.count != $1.completedDays.count {
          return $0.completedDays.count > $1.completedDays.count
        }
        return $0.startDate > $1.startDate
      }.first!

      // Abandon duplicates silently
      for duplicate in allActive where duplicate.id != best.id {
        try? await abandonProgram(duplicate)
      }

      var userProgram = best
      userProgram = await advanceDayIfNeeded(userProgram)

      activeProgram = userProgram
      resolveTodaysDay(for: userProgram)

    } catch {
      print("ProgramService: Error loading active program — \(error)")
      errorMessage = "Failed to load your program."
    }
  }

  // MARK: - Enrollment

  func enrollInProgram(_ program: Program) async throws {
    guard let uid = auth.uid else { throw ProgramError.invalidUser }

    // Abandon any existing active program first
    if let existing = activeProgram {
      try await abandonProgram(existing)
    }

    let userProgram = UserProgram(
      userId: uid,
      programId: program.id,
      programTitle: program.title,
      programDurationDays: program.durationDays
    )

    let docRef = db.collection("userPrograms").document(userProgram.id)
    
    try docRef.setData(from: userProgram)

    activeProgram = userProgram
    resolveTodaysDay(for: userProgram)
  }

  // MARK: - Complete Today's Day

  func completeProgramDay() async throws {
    guard let uid = auth.uid else { throw ProgramError.invalidUser }
    guard var userProgram = activeProgram else { throw ProgramError.noProgramActive }
    guard let day = todaysProgramDay else { throw ProgramError.noProgramActive }

    let xpEarned = day.xpReward
    userProgram.markDayCompleted(day: userProgram.currentDay, xpEarned: xpEarned)

    // Cancel any recovery reminders since the day is done
    cancelRecoveryReminders(for: userProgram.id)

    // Clear recovery state
    userProgram.recoveryReminderState = nil

    // Save to Firestore
    let docRef = db.collection("userPrograms").document(userProgram.id)
    
    try docRef.setData(from: userProgram)

    // If program is now complete, save the completion record
    if userProgram.status == .completed {
      if let program = availablePrograms.first(where: { $0.id == userProgram.programId }) {
        try await saveProgramCompletion(userProgram: userProgram, program: program)
      }
    }

    activeProgram = userProgram
    recoveryBonusDay = nil

    // Update user XP and streak
    let today = Date()
    let calendar = Calendar.current
    var newStreakCount = 1

    if let user = auth.currentUser, let lastCompleted = user.lastCompleted {
      if calendar.isDate(lastCompleted, inSameDayAs: today) {
        // Already completed something today — preserve streak
        newStreakCount = user.streakCount
      } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                calendar.isDate(lastCompleted, inSameDayAs: yesterday) {
        // Completed yesterday — extend streak
        newStreakCount = user.streakCount + 1
      }
      // else: gap of 2+ days — reset to 1
    }

    try await db.collection("users").document(uid).updateData([
      "totalXP": FieldValue.increment(Int64(xpEarned)),
      "streakCount": newStreakCount,
      "lastCompleted": Timestamp(date: today)
    ])

    // Reflect streak update locally
    if var user = auth.currentUser {
      user.streakCount = newStreakCount
      user.lastCompleted = today
      auth.currentUser = user
    }
  }

  // MARK: - Day Advancement

  private func advanceDayIfNeeded(_ userProgram: UserProgram) async -> UserProgram {
    var program = userProgram
    let calendar = Calendar.current

    // Calculate what day of the program today is based on startDate
    let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: program.startDate), to: calendar.startOfDay(for: Date())).day ?? 0
    let expectedDay = min(daysSinceStart + 1, program.programDurationDays)

    // If we're behind, advance through missed days
    while program.currentDay < expectedDay {
      program.advanceDay()
    }

    // If anything changed, persist it
    if program.currentDay != userProgram.currentDay || program.missedDays != userProgram.missedDays {
      do {
        let docRef = db.collection("userPrograms").document(program.id)
        try docRef.setData(from: program)

        // Schedule recovery reminders if today is a recovery day
        if program.isRecoveryDay {
          scheduleRecoveryReminders(for: program)
        }
      } catch {
        print("ProgramService: Failed to persist day advancement — \(error)")
      }
    }

    return program
  }

  private func resolveTodaysDay(for userProgram: UserProgram) {
    guard let program = availablePrograms.first(where: { $0.id == userProgram.programId }) else {
      todaysProgramDay = nil
      recoveryBonusDay = nil
      return
    }

    let dayIndex = userProgram.currentDay - 1
    guard dayIndex >= 0 && dayIndex < program.days.count else {
      todaysProgramDay = nil
      return
    }

    todaysProgramDay = program.days[dayIndex]

    // If it's a recovery day, assign a bonus challenge
    if userProgram.isRecoveryDay {
      recoveryBonusDay = recoveryChallenge(for: program.category)
    } else {
      recoveryBonusDay = nil
    }
  }

  // MARK: - Recovery Challenges

  private func recoveryChallenge(for category: ProgramCategory) -> ProgramDay {
    let placeholder = MentalEdge(figure: "", sourceWork: "", year: "", content: "")
    let challenges: [ProgramDay] = [
      ProgramDay(dayNumber: 0, challengeTitle: "Do 20 pushups — right now", challengeDescription: "No equipment, no excuses. Drop and do 20. This is your recovery tax.", dailyAction: "Drop and do 20 pushups before you do anything else today.", nightlyReflection: "Did you do them immediately, or did you wait? What does that tell you?", mentalEdge: placeholder, category: .fitness, xpReward: 0, phase: .wakeUp),
      ProgramDay(dayNumber: 0, challengeTitle: "Write one honest sentence about why you missed yesterday", challengeDescription: "Not a paragraph. One sentence. Own it.", dailyAction: "Write the sentence. No justifications, no context. One sentence.", nightlyReflection: "Was the sentence honest, or was it still an excuse dressed up as honesty?", mentalEdge: placeholder, category: .mindfulness, xpReward: 0, phase: .wakeUp),
      ProgramDay(dayNumber: 0, challengeTitle: "Take a 5-minute cold shower", challengeDescription: "Uncomfortable on purpose. Welcome back.", dailyAction: "Turn it all the way cold. Stay for 5 minutes. No negotiating with yourself.", nightlyReflection: "How did it feel to do something hard first thing? Hold onto that.", mentalEdge: placeholder, category: .wellness, xpReward: 0, phase: .wakeUp),
      ProgramDay(dayNumber: 0, challengeTitle: "Do 30 bodyweight squats", challengeDescription: "Slow and controlled. Your body remembers what you owe it.", dailyAction: "30 squats. Slow on the way down. Full depth. Your body remembers what you owe it.", nightlyReflection: "Physical discomfort or mental resistance — which was harder today?", mentalEdge: placeholder, category: .fitness, xpReward: 0, phase: .wakeUp),
      ProgramDay(dayNumber: 0, challengeTitle: "Put your phone in another room for 30 minutes", challengeDescription: "Sit with your thoughts. No distraction. This is the work.", dailyAction: "Phone in another room. 30 minutes. No exceptions. Sit with whatever comes up.", nightlyReflection: "What did you think about when there was nothing to scroll through?", mentalEdge: placeholder, category: .productivity, xpReward: 0, phase: .wakeUp),
    ]

    let index = Int.random(in: 0..<challenges.count)
    return challenges[index]
  }

  // MARK: - Recovery Reminders

  func scheduleRecoveryReminders(for userProgram: UserProgram) {
    let center = UNUserNotificationCenter.current()
    let programId = userProgram.id

    let messages = [
      (hour: 9,  minute: 0,  body: "You've got a recovery day. Two challenges, same XP. Get it done."),
      (hour: 13, minute: 0,  body: "Still time to recover. Don't let one miss become two."),
      (hour: 20, minute: 0,  body: "Last chance today. Your program is waiting."),
    ]

    for (index, message) in messages.enumerated() {
      var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
      components.hour = message.hour
      components.minute = message.minute

      // Only schedule if the time hasn't passed yet
      guard let fireDate = Calendar.current.date(from: components), fireDate > Date() else { continue }

      let content = UNMutableNotificationContent()
      content.title = "Recovery Day"
      content.body = message.body
      content.sound = .default

      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      let requestId = "recovery_\(programId)_\(index)"
      let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)

      center.add(request) { error in
        if let error = error {
          print("ProgramService: Failed to schedule recovery reminder \(index) — \(error)")
        }
      }
    }
  }

  func cancelRecoveryReminders(for programId: String) {
    let center = UNUserNotificationCenter.current()
    let ids = (0..<3).map { "recovery_\(programId)_\($0)" }
    center.removePendingNotificationRequests(withIdentifiers: ids)
  }

  // MARK: - Program Completion

  private func saveProgramCompletion(userProgram: UserProgram, program: Program) async throws {
    guard let uid = auth.uid else { throw ProgramError.invalidUser }

    let completion = ProgramCompletion(from: userProgram, program: program)
    let docRef = db.collection("programCompletions").document(completion.id)
    try docRef.setData(from: completion)

    // Clear active program
    activeProgram = nil
    todaysProgramDay = nil
  }

  // MARK: - Abandon Program

  func abandonProgram(_ userProgram: UserProgram) async throws {
    var abandoned = userProgram
    abandoned.status = .abandoned

    let docRef = db.collection("userPrograms").document(abandoned.id)
    try docRef.setData(from: abandoned)

    cancelRecoveryReminders(for: abandoned.id)

    if activeProgram?.id == abandoned.id {
      activeProgram = nil
      todaysProgramDay = nil
      recoveryBonusDay = nil
    }
  }

  // MARK: - Helpers

  var isTodayCompleted: Bool {
    guard let program = activeProgram else { return false }
    return program.completedDays.contains(program.currentDay)
  }

  var program: Program? {
    guard let active = activeProgram else { return nil }
    return availablePrograms.first(where: { $0.id == active.programId })
  }
}

// MARK: - Errors

enum ProgramError: Error, LocalizedError {
  case invalidUser
  case noProgramActive
  case enrollmentFailed

  var errorDescription: String? {
    switch self {
    case .invalidUser: return "No signed-in user"
    case .noProgramActive: return "No active program"
    case .enrollmentFailed: return "Failed to enroll in program"
    }
  }
}
