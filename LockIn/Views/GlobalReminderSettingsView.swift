import SwiftUI

struct GlobalReminderSettingsView: View {
  @ObservedObject var reminderService: ReminderService
  @Environment(\.dismiss) private var dismiss
  @State private var showingTimePicker = false
  @State private var showingEveningTimePicker = false
  @State private var showingPermissionAlert = false

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 24) {
            // Header
            headerSection

            // Permission Status
            permissionStatusSection

            // Global Settings
            globalSettingsSection

            // Smart Features
            smartFeaturesSection

            // Notification Limits
            notificationLimitsSection

            Spacer(minLength: 100)
          }
          .padding()
        }
      }
      .navigationTitle("Notification Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.brandYellow)
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
    .alert("Notifications Required", isPresented: $showingPermissionAlert) {
      Button("Enable Notifications") {
        Task {
          await requestNotificationPermission()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("To use reminder features, please enable notifications in Settings.")
    }
  }

  private var headerSection: some View {
    VStack(spacing: 16) {
      Image(systemName: "bell.badge")
        .font(.system(size: 60))
        .foregroundColor(.brandYellow)

      Text("Smart Reminders")
        .titleStyle()
        .foregroundColor(.white)

      Text("Configure your global reminder preferences and smart features")
        .bodyStyle()
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  private var permissionStatusSection: some View {
    VStack(spacing: 16) {
      HStack {
        Text("Permission Status")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
      }

      HStack {
        Image(
          systemName: reminderService.isNotificationAuthorized
            ? "checkmark.circle.fill" : "xmark.circle.fill"
        )
        .foregroundColor(reminderService.isNotificationAuthorized ? .brandGreen : .brandRed)
        .font(.title2)

        VStack(alignment: .leading, spacing: 4) {
          Text(
            reminderService.isNotificationAuthorized
              ? "Notifications Enabled" : "Notifications Disabled"
          )
          .bodyStyle()
          .foregroundColor(.white)

          Text(
            reminderService.isNotificationAuthorized
              ? "You'll receive reminder notifications" : "Enable to receive reminder notifications"
          )
          .captionStyle()
          .foregroundColor(.secondary)
        }

        Spacer()

        if !reminderService.isNotificationAuthorized {
          Button("Enable") {
            Task {
              await requestNotificationPermission()
            }
          }
          .foregroundColor(.brandYellow)
          .font(.caption)
        }
      }
    }
    .padding()
    .background(Color.brandGray)
    .cornerRadius(12)
  }

  private var globalSettingsSection: some View {
    VStack(spacing: 16) {
      HStack {
        Text("Default Settings")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
      }

      // Default Reminder Time
      Button(action: {
        if reminderService.isNotificationAuthorized {
          showingTimePicker = true
        } else {
          showingPermissionAlert = true
        }
      }) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Default Reminder Time")
              .bodyStyle()
              .foregroundColor(.white)

            Text(timeString(from: reminderService.globalSettings.defaultReminderTime))
              .captionStyle()
              .foregroundColor(.brandYellow)
          }

          Spacer()

          Image(systemName: "chevron.right")
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.brandGray)
        .cornerRadius(12)
      }

      // Default Evening Anchor
      Button(action: {
        if reminderService.isNotificationAuthorized {
          showingEveningTimePicker = true
        } else {
          showingPermissionAlert = true
        }
      }) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Default Evening Nudge Time")
              .bodyStyle()
              .foregroundColor(.white)

            Text(timeString(from: reminderService.globalSettings.defaultEveningAnchor))
              .captionStyle()
              .foregroundColor(.brandYellow)
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

  private var smartFeaturesSection: some View {
    VStack(spacing: 16) {
      HStack {
        Text("Smart Features")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
      }

      Toggle(
        "Enable Smart Reminders",
        isOn: Binding(
          get: { reminderService.globalSettings.enableSmartReminders },
          set: { newValue in
            var settings = reminderService.globalSettings
            settings.enableSmartReminders = newValue
            reminderService.updateGlobalSettings(settings)
          }
        )
      )
      .toggleStyle(SwitchToggleStyle(tint: .brandYellow))
      .foregroundColor(.white)

      Toggle(
        "Notification Summary",
        isOn: Binding(
          get: { reminderService.globalSettings.enableNotificationSummary },
          set: { newValue in
            var settings = reminderService.globalSettings
            settings.enableNotificationSummary = newValue
            reminderService.updateGlobalSettings(settings)
          }
        )
      )
      .toggleStyle(SwitchToggleStyle(tint: .brandYellow))
      .foregroundColor(.white)
    }
    .padding()
    .background(Color.brandGray)
    .cornerRadius(12)
  }

  private var notificationLimitsSection: some View {
    VStack(spacing: 16) {
      HStack {
        Text("Notification Limits")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
      }

      HStack {
        Text("Max Daily Notifications")
          .bodyStyle()
          .foregroundColor(.white)

        Spacer()

        Picker(
          "Max Daily Notifications",
          selection: Binding(
            get: { reminderService.globalSettings.maxDailyNotifications },
            set: { newValue in
              var settings = reminderService.globalSettings
              settings.maxDailyNotifications = newValue
              reminderService.updateGlobalSettings(settings)
            }
          )
        ) {
          ForEach(1...10, id: \.self) { count in
            Text("\(count)")
              .tag(count)
          }
        }
        .pickerStyle(MenuPickerStyle())
        .foregroundColor(.brandYellow)
      }
      .padding()
      .background(Color.brandGray)
      .cornerRadius(12)

      Text(
        "This prevents notification spam by limiting the number of reminders you receive per day"
      )
      .captionStyle()
      .foregroundColor(.secondary)
    }
  }

  // MARK: - Sheet Views

  private var timePickerSheet: some View {
    NavigationView {
      VStack {
        DatePicker(
          "Default Reminder Time",
          selection: Binding(
            get: {
              let time = reminderService.globalSettings.defaultReminderTime
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
              var settings = reminderService.globalSettings
              settings.defaultReminderTime = components
              reminderService.updateGlobalSettings(settings)
            }
          ),
          displayedComponents: .hourAndMinute
        )
        .datePickerStyle(WheelDatePickerStyle())
        .labelsHidden()
        .padding()

        Spacer()
      }
      .navigationTitle("Set Default Time")
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
          "Default Evening Time",
          selection: Binding(
            get: {
              let time = reminderService.globalSettings.defaultEveningAnchor
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
              var settings = reminderService.globalSettings
              settings.defaultEveningAnchor = components
              reminderService.updateGlobalSettings(settings)
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

  // MARK: - Helper Functions

  private func requestNotificationPermission() async {
    let granted = await reminderService.requestNotificationPermission()
    if !granted {
      // Permission denied, show alert
      await MainActor.run {
        showingPermissionAlert = true
      }
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
}

// MARK: - Preview
struct GlobalReminderSettingsView_Previews: PreviewProvider {
  static var previews: some View {
    GlobalReminderSettingsView(reminderService: ReminderService())
  }
}
