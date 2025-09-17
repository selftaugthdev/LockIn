import Foundation

// MARK: - Reminder Mode
enum ReminderMode: String, Codable, CaseIterable {
  case off = "off"
  case daily = "daily"
  case selectedDays = "selectedDays"
  case smart = "smart"

  var displayName: String {
    switch self {
    case .off: return "Off"
    case .daily: return "Daily"
    case .selectedDays: return "Selected Days"
    case .smart: return "Smart (Recommended)"
    }
  }

  var description: String {
    switch self {
    case .off: return "No reminders"
    case .daily: return "Remind every day at the same time"
    case .selectedDays: return "Remind only on selected weekdays"
    case .smart: return "Smart reminders that adapt to your habits"
    }
  }
}

// MARK: - Reminder Configuration
struct ReminderConfig: Codable {
  var mode: ReminderMode
  var time: DateComponents?  // hour/minute for daily reminders
  var selectedWeekdays: Set<Int>?  // 1=Sun...7=Sat (Calendar standard)
  var eveningAnchor: DateComponents?  // for smart nudge (e.g., 20:30)
  var enableEveningNudge: Bool

  init(
    mode: ReminderMode = .off,
    time: DateComponents? = nil,
    selectedWeekdays: Set<Int>? = nil,
    eveningAnchor: DateComponents? = nil,
    enableEveningNudge: Bool = true
  ) {
    self.mode = mode
    self.time = time
    self.selectedWeekdays = selectedWeekdays
    self.eveningAnchor = eveningAnchor
    self.enableEveningNudge = enableEveningNudge
  }
}

// MARK: - Per-Challenge Reminder Override
struct ReminderOverride: Codable {
  var useDefaultSettings: Bool  // true = use global defaults, false = use custom settings
  var customConfig: ReminderConfig?  // custom settings when useDefaultSettings is false
  var multiPingConfig: MultiPingConfig?  // for edge cases like water drinking

  init(
    useDefaultSettings: Bool = true,
    customConfig: ReminderConfig? = nil,
    multiPingConfig: MultiPingConfig? = nil
  ) {
    self.useDefaultSettings = useDefaultSettings
    self.customConfig = customConfig
    self.multiPingConfig = multiPingConfig
  }
}

// MARK: - Multi-Ping Configuration (for edge cases like water drinking)
struct MultiPingConfig: Codable {
  var timesPerDay: Int  // 2-6 reminders per day
  var startHour: Int  // e.g., 9 for 9:00 AM
  var endHour: Int  // e.g., 21 for 9:00 PM

  init(timesPerDay: Int = 3, startHour: Int = 9, endHour: Int = 21) {
    self.timesPerDay = max(2, min(6, timesPerDay))  // Clamp between 2-6
    self.startHour = max(0, min(23, startHour))  // Clamp between 0-23
    self.endHour = max(0, min(23, endHour))  // Clamp between 0-23
  }

  /// Calculate evenly spaced reminder times between startHour and endHour
  var reminderTimes: [DateComponents] {
    guard timesPerDay > 1, endHour > startHour else {
      return [DateComponents(hour: startHour, minute: 0)]
    }

    let totalMinutes = (endHour - startHour) * 60
    let intervalMinutes = totalMinutes / (timesPerDay - 1)

    var times: [DateComponents] = []
    for i in 0..<timesPerDay {
      let minutesFromStart = i * intervalMinutes
      let hour = startHour + (minutesFromStart / 60)
      let minute = minutesFromStart % 60
      times.append(DateComponents(hour: hour, minute: minute))
    }

    return times
  }
}

// MARK: - Challenge Reminder State
struct ChallengeReminderState: Codable {
  var challengeId: String
  var config: ReminderConfig
  var weeklyQuota: Int?  // e.g., 5 for "Gym 5×/week"
  var autoSpread: Bool  // for quota-based challenges
  var completionsThisWeek: Int
  var lastCompletionAt: Date?
  var ignoredRemindersCount: Int  // track ignored reminders for smart behavior
  var lastIgnoredAt: Date?
  var isPaused: Bool  // if user paused reminders due to too many ignores

  init(
    challengeId: String,
    config: ReminderConfig = ReminderConfig(),
    weeklyQuota: Int? = nil,
    autoSpread: Bool = false,
    completionsThisWeek: Int = 0,
    lastCompletionAt: Date? = nil,
    ignoredRemindersCount: Int = 0,
    lastIgnoredAt: Date? = nil,
    isPaused: Bool = false
  ) {
    self.challengeId = challengeId
    self.config = config
    self.weeklyQuota = weeklyQuota
    self.autoSpread = autoSpread
    self.completionsThisWeek = completionsThisWeek
    self.lastCompletionAt = lastCompletionAt
    self.ignoredRemindersCount = ignoredRemindersCount
    self.lastIgnoredAt = lastIgnoredAt
    self.isPaused = isPaused
  }
}

// MARK: - Smart Reminder Analytics
struct ReminderAnalytics: Codable {
  var challengeId: String
  var completionTimes: [Date]  // track completion timestamps for pattern analysis
  var averageCompletionHour: Double?  // computed average hour of completion
  var reminderEffectiveness: Double  // percentage of reminders that led to completion
  var lastAnalyzedAt: Date?

  init(
    challengeId: String,
    completionTimes: [Date] = [],
    averageCompletionHour: Double? = nil,
    reminderEffectiveness: Double = 0.0,
    lastAnalyzedAt: Date? = nil
  ) {
    self.challengeId = challengeId
    self.completionTimes = completionTimes
    self.averageCompletionHour = averageCompletionHour
    self.reminderEffectiveness = reminderEffectiveness
    self.lastAnalyzedAt = lastAnalyzedAt
  }
}

// MARK: - Global Reminder Settings
struct GlobalReminderSettings: Codable {
  var defaultReminderTime: DateComponents
  var defaultEveningAnchor: DateComponents
  var enableSmartReminders: Bool
  var maxDailyNotifications: Int
  var enableNotificationSummary: Bool

  init(
    defaultReminderTime: DateComponents = DateComponents(hour: 8, minute: 0),
    defaultEveningAnchor: DateComponents = DateComponents(hour: 20, minute: 30),
    enableSmartReminders: Bool = true,
    maxDailyNotifications: Int = 6,
    enableNotificationSummary: Bool = true
  ) {
    self.defaultReminderTime = defaultReminderTime
    self.defaultEveningAnchor = defaultEveningAnchor
    self.enableSmartReminders = enableSmartReminders
    self.maxDailyNotifications = maxDailyNotifications
    self.enableNotificationSummary = enableNotificationSummary
  }
}

// MARK: - Helper Extensions
extension ReminderConfig {
  /// Returns the effective reminder time, using global defaults if not set
  func effectiveReminderTime(globalSettings: GlobalReminderSettings) -> DateComponents {
    return time ?? globalSettings.defaultReminderTime
  }

  /// Returns the effective evening anchor time, using global defaults if not set
  func effectiveEveningAnchor(globalSettings: GlobalReminderSettings) -> DateComponents {
    return eveningAnchor ?? globalSettings.defaultEveningAnchor
  }

  /// Checks if reminders are enabled (not off and not paused)
  var isEnabled: Bool {
    return mode != .off
  }
}

extension ChallengeReminderState {
  /// Checks if the challenge is completed today
  var isCompletedToday: Bool {
    guard let lastCompletion = lastCompletionAt else { return false }
    return Calendar.current.isDate(lastCompletion, inSameDayAs: Date())
  }

  /// Checks if the challenge needs a reminder today
  func needsReminderToday() -> Bool {
    guard !isPaused && config.isEnabled else { return false }
    guard !isCompletedToday else { return false }

    switch config.mode {
    case .off:
      return false
    case .daily:
      return true
    case .selectedDays:
      let today = Calendar.current.component(.weekday, from: Date())
      return config.selectedWeekdays?.contains(today) ?? false
    case .smart:
      // Smart mode logic will be implemented in the service layer
      return true
    }
  }

  /// Resets weekly tracking (call on Sunday or app start)
  mutating func resetWeeklyTracking() {
    completionsThisWeek = 0
  }

  /// Increments ignored reminders count and handles pause logic
  mutating func recordIgnoredReminder() {
    ignoredRemindersCount += 1
    lastIgnoredAt = Date()

    // Pause reminders if 3 ignored in a row
    if ignoredRemindersCount >= 3 {
      isPaused = true
    }
  }

  /// Resets ignored reminders when user completes challenge
  mutating func recordCompletion() {
    ignoredRemindersCount = 0
    lastIgnoredAt = nil
    isPaused = false
    lastCompletionAt = Date()
    completionsThisWeek += 1
  }
}

extension ReminderAnalytics {
  /// Updates analytics with a new completion time
  mutating func recordCompletion(at date: Date = Date()) {
    completionTimes.append(date)

    // Keep only last 30 completion times to avoid memory bloat
    if completionTimes.count > 30 {
      completionTimes.removeFirst(completionTimes.count - 30)
    }

    // Recalculate average completion hour
    updateAverageCompletionHour()
    lastAnalyzedAt = date
  }

  /// Calculates the average hour of completion
  private mutating func updateAverageCompletionHour() {
    guard !completionTimes.isEmpty else {
      averageCompletionHour = nil
      return
    }

    let calendar = Calendar.current
    let totalHours = completionTimes.reduce(0.0) { sum, date in
      let hour = calendar.component(.hour, from: date)
      let minute = calendar.component(.minute, from: date)
      return sum + Double(hour) + (Double(minute) / 60.0)
    }

    averageCompletionHour = totalHours / Double(completionTimes.count)
  }

  /// Suggests an optimal reminder time (15 minutes before average completion)
  var suggestedReminderTime: DateComponents? {
    guard let avgHour = averageCompletionHour else { return nil }

    let suggestedHour = Int(avgHour - 0.25)  // 15 minutes before
    let suggestedMinute = Int((avgHour - Double(suggestedHour)) * 60)

    return DateComponents(hour: suggestedHour, minute: suggestedMinute)
  }
}
