import SwiftUI

struct ReminderSettingsView: View {
  @StateObject private var reminderService = ReminderService()
  @State private var reminderState: ChallengeReminderState
  @State private var showingTimePicker = false
  @State private var showingEveningTimePicker = false
  @State private var showingWeekdayPicker = false
  @State private var showingPermissionAlert = false

  let challenge: Challenge
  let onSave: (ChallengeReminderState) -> Void
  let onCancel: () -> Void

  init(
    challenge: Challenge, onSave: @escaping (ChallengeReminderState) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.challenge = challenge
    self.onSave = onSave
    self.onCancel = onCancel
    self._reminderState = State(
      initialValue: ChallengeReminderState(challengeId: challenge.id ?? ""))
  }

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 24) {
            // Header
            headerSection

            // Reminder Mode Selection
            reminderModeSection

            // Time Configuration (when applicable)
            if reminderState.config.mode != .off {
              timeConfigurationSection
            }

            // Weekly Quota Configuration (for quota-based challenges)
            if challenge.type == .fitness || challenge.type == .productivity {
              weeklyQuotaSection
            }

            // Evening Nudge Configuration
            if reminderState.config.mode != .off {
              eveningNudgeSection
            }

            // Smart Features Info
            if reminderState.config.mode == .smart {
              smartFeaturesSection
            }

            Spacer(minLength: 100)
          }
          .padding()
        }
      }
      .navigationTitle("Reminder Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            onCancel()
          }
          .foregroundColor(.brandYellow)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Save") {
            saveReminderSettings()
          }
          .foregroundColor(.brandYellow)
          .fontWeight(.semibold)
        }
      }
      .preferredColorScheme(.dark)
    }
    .sheet(isPresented: $showingTimePicker) {
      timePickerSheet
    }
    .sheet(isPresented: $showingEveningTimePicker) {
      eveningTimePickerSheet
    }
    .sheet(isPresented: $showingWeekdayPicker) {
      weekdayPickerSheet
    }
    .alert("Notifications Required", isPresented: $showingPermissionAlert) {
      Button("Enable Notifications") {
        Task {
          await requestNotificationPermission()
        }
      }
      Button("Cancel", role: .cancel) {
        reminderState.config.mode = .off
      }
    } message: {
      Text("To set up reminders, please enable notifications in Settings.")
    }
    .onAppear {
      loadReminderState()
    }
  }

  private var headerSection: some View {
    VStack(spacing: 16) {
      // Challenge Icon and Title
      HStack(spacing: 16) {
        Text(challenge.type.emoji)
          .font(.system(size: 40))

        VStack(alignment: .leading, spacing: 4) {
          Text(challenge.title)
            .title2Style()
            .foregroundColor(.white)

          Text(challenge.type.displayName)
            .bodyStyle()
            .foregroundColor(.brandYellow)
        }

        Spacer()
      }

      // Current Status
      HStack {
        Image(systemName: reminderState.config.mode == .off ? "bell.slash" : "bell")
          .foregroundColor(reminderState.config.mode == .off ? .secondary : .brandYellow)

        Text(reminderState.config.mode == .off ? "Reminders Off" : "Reminders On")
          .bodyStyle()
          .foregroundColor(reminderState.config.mode == .off ? .secondary : .white)

        Spacer()
      }
    }
    .padding()
    .background(Color.brandGray)
    .cornerRadius(12)
  }

  private var reminderModeSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Reminder Mode")
        .headlineStyle()
        .foregroundColor(.white)

      VStack(spacing: 12) {
        ForEach(ReminderMode.allCases, id: \.self) { mode in
          reminderModeRow(mode)
        }
      }
    }
  }

  private func reminderModeRow(_ mode: ReminderMode) -> some View {
    Button(action: {
      if mode != .off && !reminderService.isNotificationAuthorized {
        showingPermissionAlert = true
      } else {
        reminderState.config.mode = mode
      }
    }) {
      HStack(spacing: 16) {
        Image(systemName: reminderState.config.mode == mode ? "checkmark.circle.fill" : "circle")
          .foregroundColor(reminderState.config.mode == mode ? .brandYellow : .secondary)
          .font(.title3)

        VStack(alignment: .leading, spacing: 4) {
          Text(mode.displayName)
            .headlineStyle()
            .foregroundColor(.white)

          Text(mode.description)
            .bodyStyle()
            .foregroundColor(.secondary)
        }

        Spacer()
      }
      .padding()
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(
            reminderState.config.mode == mode ? Color.brandYellow.opacity(0.1) : Color.brandGray
          )
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(
                reminderState.config.mode == mode ? Color.brandYellow : Color.clear, lineWidth: 1)
          )
      )
    }
  }

  private var timeConfigurationSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Reminder Time")
        .headlineStyle()
        .foregroundColor(.white)

      if reminderState.config.mode == .selectedDays {
        // Weekday Selection
        Button(action: {
          showingWeekdayPicker = true
        }) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Selected Days")
                .bodyStyle()
                .foregroundColor(.white)

              if let weekdays = reminderState.config.selectedWeekdays, !weekdays.isEmpty {
                Text(weekdayNames(from: weekdays))
                  .captionStyle()
                  .foregroundColor(.brandYellow)
              } else {
                Text("Tap to select days")
                  .captionStyle()
                  .foregroundColor(.secondary)
              }
            }

            Spacer()

            Image(systemName: "chevron.right")
              .foregroundColor(.secondary)
          }
          .padding()
          .background(Color.brandGray)
          .cornerRadius(12)
        }
      }

      // Time Picker
      Button(action: {
        showingTimePicker = true
      }) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Reminder Time")
              .bodyStyle()
              .foregroundColor(.white)

            if let time = reminderState.config.time {
              Text(timeString(from: time))
                .captionStyle()
                .foregroundColor(.brandYellow)
            } else {
              Text("Tap to set time")
                .captionStyle()
                .foregroundColor(.secondary)
            }
          }

          Spacer()

          Image(systemName: "chevron.right")
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.brandGray)
        .cornerRadius(12)
      }
    }
  }

  private var weeklyQuotaSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Weekly Quota")
        .headlineStyle()
        .foregroundColor(.white)

      HStack {
        Text("Times per week:")
          .bodyStyle()
          .foregroundColor(.white)

        Spacer()

        Picker("Weekly Quota", selection: $reminderState.weeklyQuota) {
          ForEach(1...7, id: \.self) { count in
            Text("\(count)")
              .tag(Optional(count))
          }
        }
        .pickerStyle(MenuPickerStyle())
        .foregroundColor(.brandYellow)
      }
      .padding()
      .background(Color.brandGray)
      .cornerRadius(12)

      // Auto-spread Toggle
      Toggle("Auto-spread across week", isOn: $reminderState.autoSpread)
        .toggleStyle(SwitchToggleStyle(tint: .brandYellow))
        .foregroundColor(.white)
    }
  }

  private var eveningNudgeSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Evening Safety Nudge")
        .headlineStyle()
        .foregroundColor(.white)

      Toggle("Send reminder if not completed", isOn: $reminderState.config.enableEveningNudge)
        .toggleStyle(SwitchToggleStyle(tint: .brandYellow))
        .foregroundColor(.white)

      if reminderState.config.enableEveningNudge {
        Button(action: {
          showingEveningTimePicker = true
        }) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Evening Time")
                .bodyStyle()
                .foregroundColor(.white)

              if let eveningTime = reminderState.config.eveningAnchor {
                Text(timeString(from: eveningTime))
                  .captionStyle()
                  .foregroundColor(.brandYellow)
              } else {
                Text("Tap to set time")
                  .captionStyle()
                  .foregroundColor(.secondary)
              }
            }

            Spacer()

            Image(systemName: "chevron.right")
              .foregroundColor(.secondary)
          }
          .padding()
          .background(Color.brandGray)
          .cornerRadius(12)
        }
      }
    }
  }

  private var smartFeaturesSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Smart Features")
        .headlineStyle()
        .foregroundColor(.white)

      VStack(alignment: .leading, spacing: 12) {
        smartFeatureRow(
          icon: "clock.arrow.circlepath",
          title: "Adaptive Timing",
          description: "Learns your completion patterns and suggests optimal reminder times"
        )

        smartFeatureRow(
          icon: "brain.head.profile",
          title: "Behavioral Insights",
          description: "Tracks your habits to provide personalized recommendations"
        )

        smartFeatureRow(
          icon: "hand.raised.slash",
          title: "Respectful Pausing",
          description: "Automatically pauses reminders if you consistently ignore them"
        )
      }
    }
    .padding()
    .background(Color.brandGray)
    .cornerRadius(12)
  }

  private func smartFeatureRow(icon: String, title: String, description: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .foregroundColor(.brandYellow)
        .font(.title3)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .bodyStyle()
          .foregroundColor(.white)

        Text(description)
          .captionStyle()
          .foregroundColor(.secondary)
      }

      Spacer()
    }
  }

  // MARK: - Sheet Views

  private var timePickerSheet: some View {
    NavigationView {
      VStack {
        DatePicker(
          "Reminder Time",
          selection: Binding(
            get: {
              let time = reminderState.config.time ?? DateComponents(hour: 8, minute: 0)
              let calendar = Calendar.current
              let now = Date()
              return calendar.date(
                bySettingHour: time.hour ?? 8,
                minute: time.minute ?? 0,
                second: 0,
                of: now
              ) ?? now
            },
            set: { date in
              let calendar = Calendar.current
              let components = calendar.dateComponents([.hour, .minute], from: date)
              reminderState.config.time = components
            }
          ),
          displayedComponents: .hourAndMinute
        )
        .datePickerStyle(WheelDatePickerStyle())
        .labelsHidden()
        .padding()

        Spacer()
      }
      .navigationTitle("Set Reminder Time")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            showingTimePicker = false
          }
          .foregroundColor(.brandYellow)
        }
      }
      .preferredColorScheme(.dark)
    }
  }

  private var eveningTimePickerSheet: some View {
    NavigationView {
      VStack {
        DatePicker(
          "Evening Time",
          selection: Binding(
            get: {
              let time = reminderState.config.eveningAnchor ?? DateComponents(hour: 20, minute: 30)
              let calendar = Calendar.current
              let now = Date()
              return calendar.date(
                bySettingHour: time.hour ?? 20,
                minute: time.minute ?? 30,
                second: 0,
                of: now
              ) ?? now
            },
            set: { date in
              let calendar = Calendar.current
              let components = calendar.dateComponents([.hour, .minute], from: date)
              reminderState.config.eveningAnchor = components
            }
          ),
          displayedComponents: .hourAndMinute
        )
        .datePickerStyle(WheelDatePickerStyle())
        .labelsHidden()
        .padding()

        Spacer()
      }
      .navigationTitle("Set Evening Time")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            showingEveningTimePicker = false
          }
          .foregroundColor(.brandYellow)
        }
      }
      .preferredColorScheme(.dark)
    }
  }

  private var weekdayPickerSheet: some View {
    NavigationView {
      List {
        ForEach(1...7, id: \.self) { day in
          Button(action: {
            toggleWeekday(day)
          }) {
            HStack {
              Text(weekdayName(for: day))
                .foregroundColor(.white)

              Spacer()

              if reminderState.config.selectedWeekdays?.contains(day) == true {
                Image(systemName: "checkmark")
                  .foregroundColor(.brandYellow)
              }
            }
          }
        }
      }
      .navigationTitle("Select Days")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            showingWeekdayPicker = false
          }
          .foregroundColor(.brandYellow)
        }
      }
      .preferredColorScheme(.dark)
    }
  }

  // MARK: - Helper Functions

  private func loadReminderState() {
    reminderState = reminderService.getReminderState(for: challenge.id ?? "")
  }

  private func saveReminderSettings() {
    reminderService.updateReminderState(reminderState)
    onSave(reminderState)
  }

  private func requestNotificationPermission() async {
    let granted = await reminderService.requestNotificationPermission()
    if granted {
      // Permission granted, user can now set reminders
    } else {
      // Permission denied, reset to off
      reminderState.config.mode = .off
    }
  }

  private func toggleWeekday(_ day: Int) {
    if reminderState.config.selectedWeekdays == nil {
      reminderState.config.selectedWeekdays = Set<Int>()
    }

    if reminderState.config.selectedWeekdays?.contains(day) == true {
      reminderState.config.selectedWeekdays?.remove(day)
    } else {
      reminderState.config.selectedWeekdays?.insert(day)
    }
  }

  private func timeString(from components: DateComponents) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short

    let calendar = Calendar.current
    let now = Date()
    let date =
      calendar.date(
        bySettingHour: components.hour ?? 0,
        minute: components.minute ?? 0,
        second: 0,
        of: now
      ) ?? now

    return formatter.string(from: date)
  }

  private func weekdayName(for day: Int) -> String {
    let formatter = DateFormatter()
    return formatter.weekdaySymbols[day - 1]
  }

  private func weekdayNames(from days: Set<Int>) -> String {
    let names = days.sorted().map { weekdayName(for: $0) }
    return names.joined(separator: ", ")
  }
}

// MARK: - Preview
struct ReminderSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    ReminderSettingsView(
      challenge: Challenge(
        title: "10 Push-ups",
        type: .fitness,
        difficulty: 2,
        dayIndex: 1
      ),
      onSave: { _ in },
      onCancel: {}
    )
  }
}
