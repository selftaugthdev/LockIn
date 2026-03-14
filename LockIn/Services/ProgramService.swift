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
    guard let uid = auth.uid else { return }
    isLoading = true
    defer { isLoading = false }

    do {
      let snapshot = try await db.collection("userPrograms")
        .whereField("userId", isEqualTo: uid)
        .whereField("status", isEqualTo: ProgramStatus.active.rawValue)
        .limit(to: 1)
        .getDocuments()

      guard let doc = snapshot.documents.first else {
        activeProgram = nil
        todaysProgramDay = nil
        recoveryBonusDay = nil
        return
      }

      var userProgram = try doc.data(as: UserProgram.self)

      // Check if the day needs advancing before presenting today's challenge
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

    // Also update user's total XP in Firestore
    try await db.collection("users").document(uid).updateData([
      "totalXP": FieldValue.increment(Int64(xpEarned))
    ])
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
    // Short physical/mental challenges used as the "tax" for missing a day
    let challenges: [ProgramDay] = [
      ProgramDay(dayNumber: 0, challengeTitle: "Do 20 pushups — right now", challengeDescription: "No equipment, no excuses. Drop and do 20. This is your recovery tax.", category: .fitness, xpReward: 0, phase: .foundation),
      ProgramDay(dayNumber: 0, challengeTitle: "Write one honest sentence about why you missed yesterday", challengeDescription: "Not a paragraph. One sentence. Own it.", category: .mindfulness, xpReward: 0, phase: .foundation),
      ProgramDay(dayNumber: 0, challengeTitle: "Take a 5-minute cold shower", challengeDescription: "Uncomfortable on purpose. Welcome back.", category: .wellness, xpReward: 0, phase: .foundation),
      ProgramDay(dayNumber: 0, challengeTitle: "Do 30 bodyweight squats", challengeDescription: "Slow and controlled. Your body remembers what you owe it.", category: .fitness, xpReward: 0, phase: .foundation),
      ProgramDay(dayNumber: 0, challengeTitle: "Put your phone in another room for 30 minutes", challengeDescription: "Sit with your thoughts. No distraction. This is the work.", category: .productivity, xpReward: 0, phase: .foundation),
    ]

    // Rotate based on how many missed days there are — keeps it varied
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
