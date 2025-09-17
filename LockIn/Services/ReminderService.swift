import Combine
import Foundation
import UserNotifications

@MainActor
class ReminderService: NSObject, ObservableObject {
  @Published var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
  @Published var isRequestingPermission = false
  @Published var globalSettings = GlobalReminderSettings()

  private let notificationCenter = UNUserNotificationCenter.current()
  private var reminderStates: [String: ChallengeReminderState] = [:]
  private var reminderAnalytics: [String: ReminderAnalytics] = [:]

  override init() {
    super.init()
    notificationCenter.delegate = self
    checkNotificationPermission()
    loadGlobalSettings()
    registerNotificationActions()
  }

  // MARK: - Permission Management

  /// Check current notification permission status
  func checkNotificationPermission() {
    Task {
      let settings = await notificationCenter.notificationSettings()
      await MainActor.run {
        self.notificationPermissionStatus = settings.authorizationStatus
      }
    }
  }

  /// Request notification permission with a pre-permission explanation
  func requestNotificationPermission() async -> Bool {
    await MainActor.run {
      isRequestingPermission = true
    }

    defer {
      Task { @MainActor in
        isRequestingPermission = false
      }
    }

    let settings = await notificationCenter.notificationSettings()

    if settings.authorizationStatus == .notDetermined {
      do {
        let granted = try await notificationCenter.requestAuthorization(
          options: [.alert, .sound, .badge]
        )
        await MainActor.run {
          self.notificationPermissionStatus = granted ? .authorized : .denied
        }
        return granted
      } catch {
        print("Error requesting notification permission: \(error)")
        await MainActor.run {
          self.notificationPermissionStatus = .denied
        }
        return false
      }
    }

    await MainActor.run {
      self.notificationPermissionStatus = settings.authorizationStatus
    }
    return settings.authorizationStatus == .authorized
  }

  /// Check if notifications are authorized
  var isNotificationAuthorized: Bool {
    return notificationPermissionStatus == .authorized
  }

  // MARK: - Reminder State Management

  /// Get reminder state for a challenge
  func getReminderState(for challengeId: String) -> ChallengeReminderState {
    return reminderStates[challengeId] ?? ChallengeReminderState(challengeId: challengeId)
  }

  /// Update reminder state for a challenge
  func updateReminderState(_ state: ChallengeReminderState) {
    reminderStates[state.challengeId] = state
    saveReminderStates()
  }

  /// Get analytics for a challenge
  func getAnalytics(for challengeId: String) -> ReminderAnalytics {
    return reminderAnalytics[challengeId] ?? ReminderAnalytics(challengeId: challengeId)
  }

  /// Update analytics for a challenge
  func updateAnalytics(_ analytics: ReminderAnalytics) {
    reminderAnalytics[analytics.challengeId] = analytics
    saveAnalytics()
  }

  // MARK: - Reminder Scheduling

  /// Schedule daily or weekday reminder for a challenge
  func scheduleDailyReminder(
    challengeId: String,
    title: String,
    time: DateComponents,
    weekdays: Set<Int>? = nil
  ) async throws {
    guard isNotificationAuthorized else {
      throw ReminderError.notificationNotAuthorized
    }

    // Cancel existing reminders for this challenge
    await cancelReminders(for: challengeId)

    let content = UNMutableNotificationContent()
    content.title = "Lock In"
    content.body = title
    content.sound = .default
    content.threadIdentifier = "lockin.challenge.\(challengeId)"
    content.categoryIdentifier = "LOCKIN_ACTIONS"

    if let days = weekdays, !days.isEmpty {
      // Schedule for specific weekdays
      for day in days {
        var comps = time
        comps.weekday = day
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
          identifier: "\(challengeId)-\(day)",
          content: content,
          trigger: trigger
        )
        try await notificationCenter.add(request)
      }
    } else {
      // Schedule daily
      let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
      let request = UNNotificationRequest(
        identifier: challengeId,
        content: content,
        trigger: trigger
      )
      try await notificationCenter.add(request)
    }
  }

  /// Schedule evening safety nudge for incomplete challenges
  func scheduleEveningNudgeIfNeeded(
    challengeId: String,
    title: String,
    evening: DateComponents,
    completedToday: Bool
  ) async throws {
    guard isNotificationAuthorized else { return }

    let nudgeId = "\(challengeId)-nudge"
    await notificationCenter.removePendingNotificationRequests(withIdentifiers: [nudgeId])

    guard !completedToday else { return }

    let content = UNMutableNotificationContent()
    content.title = "Still time to Lock In"
    content.body = "\(title) — a tiny action counts."
    content.sound = .default
    content.threadIdentifier = "lockin.nudges"
    content.categoryIdentifier = "LOCKIN_ACTIONS"

    let trigger = UNCalendarNotificationTrigger(dateMatching: evening, repeats: true)
    let request = UNNotificationRequest(
      identifier: nudgeId,
      content: content,
      trigger: trigger
    )

    try await notificationCenter.add(request)
  }

  /// Schedule weekly quota reminders with auto-spread
  func scheduleWeeklyQuotaReminders(
    challengeId: String,
    title: String,
    quota: Int,
    time: DateComponents,
    autoSpread: Bool
  ) async throws {
    guard isNotificationAuthorized else {
      throw ReminderError.notificationNotAuthorized
    }

    await cancelReminders(for: challengeId)

    let weekdays: Set<Int>
    if autoSpread {
      weekdays = autoSpreadDays(for: quota)
    } else {
      // Use manually selected days from reminder state
      let state = getReminderState(for: challengeId)
      weekdays = state.config.selectedWeekdays ?? Set(2...6)  // Default to weekdays
    }

    try await scheduleDailyReminder(
      challengeId: challengeId,
      title: title,
      time: time,
      weekdays: weekdays
    )
  }

  /// Cancel all reminders for a challenge
  func cancelReminders(for challengeId: String) async {
    var identifiers = [
      challengeId,
      "\(challengeId)-nudge",
    ]

    // Add weekday-specific identifiers
    for day in 1...7 {
      identifiers.append("\(challengeId)-\(day)")
    }

    await notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
  }

  /// Cancel today's reminder/nudge for a challenge
  func cancelTodaysReminder(for challengeId: String) async {
    let today = Calendar.current.component(.weekday, from: Date())
    let identifiers = [
      challengeId,
      "\(challengeId)-nudge",
      "\(challengeId)-\(today)",
    ]

    await notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
  }

  /// Debug method to list all pending notifications (useful for simulator testing)
  func listPendingNotifications() async {
    let pendingRequests = await notificationCenter.pendingNotificationRequests()
    print("🔔 Pending notifications count: \(pendingRequests.count)")

    for request in pendingRequests {
      let content = request.content
      let trigger = request.trigger
      print("🔔 Notification: \(content.title) - \(content.body)")
      print("   ID: \(request.identifier)")
      print("   Thread: \(content.threadIdentifier)")

      if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
        print("   Trigger: \(calendarTrigger.dateComponents)")
        print("   Repeats: \(calendarTrigger.repeats)")
      }
      print("---")
    }
  }

  // MARK: - Smart Reminder Features

  /// Handle challenge completion - cancel today's reminders and update analytics
  func handleChallengeCompletion(challengeId: String) async {
    await cancelTodaysReminder(for: challengeId)

    // Update reminder state
    var state = getReminderState(for: challengeId)
    state.recordCompletion()
    updateReminderState(state)

    // Update analytics
    var analytics = getAnalytics(for: challengeId)
    analytics.recordCompletion()
    updateAnalytics(analytics)
  }

  /// Handle ignored reminder - update state and potentially pause reminders
  func handleIgnoredReminder(challengeId: String) async {
    var state = getReminderState(for: challengeId)
    state.recordIgnoredReminder()
    updateReminderState(state)

    // If reminders are now paused, cancel future reminders
    if state.isPaused {
      await cancelReminders(for: challengeId)
    }
  }

  /// Get suggested reminder time based on completion patterns
  func getSuggestedReminderTime(for challengeId: String) -> DateComponents? {
    let analytics = getAnalytics(for: challengeId)
    return analytics.suggestedReminderTime
  }

  // MARK: - Notification Actions

  /// Register notification action categories
  private func registerNotificationActions() {
    let snoozeAction = UNNotificationAction(
      identifier: "SNOOZE_15",
      title: "Snooze 15m",
      options: []
    )

    let tonightAction = UNNotificationAction(
      identifier: "REMIND_TONIGHT",
      title: "Remind tonight",
      options: []
    )

    let skipAction = UNNotificationAction(
      identifier: "SKIP_TODAY",
      title: "Skip today",
      options: [.destructive]
    )

    let category = UNNotificationCategory(
      identifier: "LOCKIN_ACTIONS",
      actions: [snoozeAction, tonightAction, skipAction],
      intentIdentifiers: [],
      options: []
    )

    notificationCenter.setNotificationCategories([category])
  }

  /// Handle snooze action
  private func handleSnoozeAction(challengeId: String) async {
    let content = UNMutableNotificationContent()
    content.title = "Lock In"
    content.body = "Time to complete your challenge!"
    content.sound = .default
    content.categoryIdentifier = "LOCKIN_ACTIONS"

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 900, repeats: false)  // 15 minutes
    let request = UNNotificationRequest(
      identifier: "\(challengeId)-snooze-\(UUID().uuidString)",
      content: content,
      trigger: trigger
    )

    do {
      try await notificationCenter.add(request)
    } catch {
      print("Error scheduling snooze notification: \(error)")
    }
  }

  /// Handle remind tonight action
  private func handleRemindTonightAction(challengeId: String) async {
    let state = getReminderState(for: challengeId)
    let eveningTime = state.config.effectiveEveningAnchor(globalSettings: globalSettings)

    let content = UNMutableNotificationContent()
    content.title = "Lock In"
    content.body = "Don't forget your challenge!"
    content.sound = .default
    content.categoryIdentifier = "LOCKIN_ACTIONS"

    // Schedule for today at evening time
    var triggerDate = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    triggerDate.hour = eveningTime.hour
    triggerDate.minute = eveningTime.minute

    let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
    let request = UNNotificationRequest(
      identifier: "\(challengeId)-tonight-\(UUID().uuidString)",
      content: content,
      trigger: trigger
    )

    do {
      try await notificationCenter.add(request)
    } catch {
      print("Error scheduling tonight reminder: \(error)")
    }
  }

  /// Handle skip today action
  private func handleSkipTodayAction(challengeId: String) async {
    await cancelTodaysReminder(for: challengeId)
    await handleIgnoredReminder(challengeId: challengeId)
  }

  // MARK: - Auto-spread Algorithm

  /// Calculate auto-spread days for weekly quota
  private func autoSpreadDays(for quota: Int, weekStart: Int = 2) -> Set<Int> {
    let weekdays = [2, 3, 4, 5, 6, 7, 1]  // Mon-Sun
    guard quota > 0 else { return [] }

    let step = Double(weekdays.count) / Double(quota)
    let selectedDays = (0..<quota).map { i in
      let index = Int(round(Double(i) * step)) % weekdays.count
      return weekdays[index]
    }

    return Set(selectedDays)
  }

  // MARK: - Default Reminder Templates

  /// Get default reminder configuration for a challenge type
  func getDefaultReminderConfig(for challengeType: ChallengeType) -> ReminderConfig {
    switch challengeType {
    case .fitness:
      return ReminderConfig(
        mode: .smart,
        time: DateComponents(hour: 7, minute: 0),  // 7:00 AM
        selectedWeekdays: nil,
        eveningAnchor: DateComponents(hour: 18, minute: 30),  // 6:30 PM
        enableEveningNudge: true
      )
    case .mindfulness:
      return ReminderConfig(
        mode: .smart,
        time: DateComponents(hour: 8, minute: 0),  // 8:00 AM
        selectedWeekdays: nil,
        eveningAnchor: DateComponents(hour: 21, minute: 0),  // 9:00 PM
        enableEveningNudge: true
      )
    case .learning:
      return ReminderConfig(
        mode: .smart,
        time: DateComponents(hour: 8, minute: 30),  // 8:30 AM (work start)
        selectedWeekdays: Set(2...6),  // Weekdays only
        eveningAnchor: DateComponents(hour: 19, minute: 0),  // 7:00 PM
        enableEveningNudge: true
      )
    case .productivity:
      return ReminderConfig(
        mode: .smart,
        time: DateComponents(hour: 8, minute: 30),  // 8:30 AM (work start)
        selectedWeekdays: Set(2...6),  // Weekdays only
        eveningAnchor: DateComponents(hour: 17, minute: 0),  // 5:00 PM
        enableEveningNudge: true
      )
    case .wellness:
      return ReminderConfig(
        mode: .smart,
        time: DateComponents(hour: 7, minute: 30),  // 7:30 AM
        selectedWeekdays: nil,
        eveningAnchor: DateComponents(hour: 20, minute: 0),  // 8:00 PM
        enableEveningNudge: true
      )
    case .creativity:
      return ReminderConfig(
        mode: .smart,
        time: DateComponents(hour: 19, minute: 0),  // 7:00 PM (evening creative time)
        selectedWeekdays: nil,
        eveningAnchor: DateComponents(hour: 21, minute: 30),  // 9:30 PM
        enableEveningNudge: true
      )
    case .social:
      return ReminderConfig(
        mode: .smart,
        time: DateComponents(hour: 18, minute: 0),  // 6:00 PM (after work)
        selectedWeekdays: Set([1, 6, 7]),  // Weekends + Sunday
        eveningAnchor: DateComponents(hour: 20, minute: 0),  // 8:00 PM
        enableEveningNudge: true
      )
    case .gratitude:
      return ReminderConfig(
        mode: .smart,
        time: DateComponents(hour: 21, minute: 0),  // 9:00 PM (bedtime routine)
        selectedWeekdays: nil,
        eveningAnchor: DateComponents(hour: 22, minute: 0),  // 10:00 PM
        enableEveningNudge: true
      )
    }
  }

  /// Get default weekly quota for a challenge type
  func getDefaultWeeklyQuota(for challengeType: ChallengeType) -> Int? {
    switch challengeType {
    case .fitness:
      return 5  // 5x per week for fitness
    case .productivity:
      return 5  // 5x per week for productivity (weekdays)
    case .social:
      return 3  // 3x per week for social
    case .learning:
      return 5  // 5x per week for learning (weekdays)
    default:
      return nil  // Daily challenges don't need quotas
    }
  }

  /// Initialize reminder state with defaults for a new challenge
  func initializeReminderState(for challenge: Challenge) -> ChallengeReminderState {
    let defaultConfig = getDefaultReminderConfig(for: challenge.type)
    let weeklyQuota = getDefaultWeeklyQuota(for: challenge.type)

    return ChallengeReminderState(
      challengeId: challenge.id ?? "",
      config: defaultConfig,
      weeklyQuota: weeklyQuota,
      autoSpread: weeklyQuota != nil,  // Auto-spread for quota-based challenges
      completionsThisWeek: 0,
      lastCompletionAt: nil,
      ignoredRemindersCount: 0,
      lastIgnoredAt: nil,
      isPaused: false
    )
  }

  /// Apply reminder override to a challenge and schedule notifications
  func applyReminderOverride(for challenge: Challenge) async {
    guard let reminderOverride = challenge.reminderOverride else {
      print("🔔 No reminder override for challenge: \(challenge.title)")
      return
    }

    print("🔔 Applying reminder override for challenge: \(challenge.title)")
    print("🔔 Use default settings: \(reminderOverride.useDefaultSettings)")

    // If using default settings, don't override anything
    if reminderOverride.useDefaultSettings {
      print("🔔 Using default reminder settings for challenge: \(challenge.title)")
      return
    }

    // Use custom configuration
    guard let customConfig = reminderOverride.customConfig else {
      print("🔔 No custom config provided for challenge: \(challenge.title)")
      return
    }

    print("🔔 Custom config mode: \(customConfig.mode)")
    print("🔔 Custom config time: \(customConfig.time?.description ?? "nil")")
    print("🔔 Evening nudge: \(customConfig.enableEveningNudge)")

    // Create a reminder state with the custom configuration
    let reminderState = ChallengeReminderState(
      challengeId: challenge.id ?? "",
      config: customConfig,
      weeklyQuota: nil,  // Custom challenges don't use quotas by default
      autoSpread: false,
      completionsThisWeek: 0,
      lastCompletionAt: nil,
      ignoredRemindersCount: 0,
      lastIgnoredAt: nil,
      isPaused: false
    )

    // Update the reminder state
    updateReminderState(reminderState)

    // Schedule the reminders based on the override
    do {
      try await scheduleRemindersForChallenge(challenge, with: reminderState)
      print("✅ Successfully scheduled reminders for challenge: \(challenge.title)")

      // Debug: List all pending notifications
      await listPendingNotifications()
    } catch {
      print("❌ Failed to schedule reminders for challenge: \(challenge.title), error: \(error)")
    }
  }

  /// Schedule reminders for a challenge based on its reminder state
  private func scheduleRemindersForChallenge(
    _ challenge: Challenge, with state: ChallengeReminderState
  ) async throws {
    guard isNotificationAuthorized else {
      print("🔔 Notifications not authorized, skipping reminder scheduling")
      return
    }

    let challengeId = challenge.id ?? ""
    let title = challenge.title

    switch state.config.mode {
    case .off:
      print("🔔 Reminder mode is OFF for challenge: \(title)")
      await cancelReminders(for: challengeId)

    case .daily:
      guard let time = state.config.time else {
        print("❌ Daily reminder mode requires a time")
        return
      }
      print("🔔 Scheduling daily reminder for \(title) at \(time)")
      try await scheduleDailyReminder(
        challengeId: challengeId,
        title: title,
        time: time
      )

    case .selectedDays:
      guard let time = state.config.time, let weekdays = state.config.selectedWeekdays else {
        print("❌ Selected days reminder mode requires time and weekdays")
        return
      }
      print("🔔 Scheduling selected days reminder for \(title) at \(time) on days: \(weekdays)")
      try await scheduleDailyReminder(
        challengeId: challengeId,
        title: title,
        time: time,
        weekdays: weekdays
      )

    case .smart:
      guard let time = state.config.time else {
        print("❌ Smart reminder mode requires a time")
        return
      }
      print("🔔 Scheduling smart reminder for \(title) at \(time)")
      try await scheduleDailyReminder(
        challengeId: challengeId,
        title: title,
        time: time
      )
    }

    // Schedule evening nudge if enabled
    if state.config.enableEveningNudge, let eveningTime = state.config.eveningAnchor {
      print("🔔 Scheduling evening nudge for \(title) at \(eveningTime)")
      try await scheduleEveningNudgeIfNeeded(
        challengeId: challengeId,
        title: title,
        evening: eveningTime,
        completedToday: false
      )
    }
  }

  // MARK: - Persistence

  /// Save reminder states to UserDefaults
  private func saveReminderStates() {
    if let data = try? JSONEncoder().encode(reminderStates) {
      UserDefaults.standard.set(data, forKey: "reminderStates")
    }
  }

  /// Load reminder states from UserDefaults
  private func loadReminderStates() {
    if let data = UserDefaults.standard.data(forKey: "reminderStates"),
      let states = try? JSONDecoder().decode([String: ChallengeReminderState].self, from: data)
    {
      reminderStates = states
    }
  }

  /// Save analytics to UserDefaults
  private func saveAnalytics() {
    if let data = try? JSONEncoder().encode(reminderAnalytics) {
      UserDefaults.standard.set(data, forKey: "reminderAnalytics")
    }
  }

  /// Load analytics from UserDefaults
  private func loadAnalytics() {
    if let data = UserDefaults.standard.data(forKey: "reminderAnalytics"),
      let analytics = try? JSONDecoder().decode([String: ReminderAnalytics].self, from: data)
    {
      reminderAnalytics = analytics
    }
  }

  /// Save global settings to UserDefaults
  private func saveGlobalSettings() {
    if let data = try? JSONEncoder().encode(globalSettings) {
      UserDefaults.standard.set(data, forKey: "globalReminderSettings")
    }
  }

  /// Load global settings from UserDefaults
  private func loadGlobalSettings() {
    if let data = UserDefaults.standard.data(forKey: "globalReminderSettings"),
      let settings = try? JSONDecoder().decode(GlobalReminderSettings.self, from: data)
    {
      globalSettings = settings
    }
  }

  /// Update global settings
  func updateGlobalSettings(_ settings: GlobalReminderSettings) {
    globalSettings = settings
    saveGlobalSettings()
  }
}

// MARK: - UNUserNotificationCenterDelegate

extension ReminderService: @preconcurrency UNUserNotificationCenterDelegate {
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo

    // Extract challenge ID from thread identifier or user info
    let challengeId: String
    let threadId = response.notification.request.content.threadIdentifier
    if threadId.hasPrefix("lockin.challenge.") {
      challengeId = String(threadId.dropFirst("lockin.challenge.".count))
    } else if let id = userInfo["challengeId"] as? String {
      challengeId = id
    } else {
      completionHandler()
      return
    }

    Task {
      switch response.actionIdentifier {
      case "SNOOZE_15":
        await handleSnoozeAction(challengeId: challengeId)
      case "REMIND_TONIGHT":
        await handleRemindTonightAction(challengeId: challengeId)
      case "SKIP_TODAY":
        await handleSkipTodayAction(challengeId: challengeId)
      default:
        break
      }
    }

    completionHandler()
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show notification even when app is in foreground
    completionHandler([.banner, .sound])
  }
}

// MARK: - Error Types

enum ReminderError: Error, LocalizedError {
  case notificationNotAuthorized
  case schedulingFailed
  case invalidConfiguration

  var errorDescription: String? {
    switch self {
    case .notificationNotAuthorized:
      return "Notification permission is required to set reminders"
    case .schedulingFailed:
      return "Failed to schedule reminder"
    case .invalidConfiguration:
      return "Invalid reminder configuration"
    }
  }
}
