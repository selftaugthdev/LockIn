import FirebaseFirestore
import SwiftUI

struct CustomChallengeEditor: View {
  @EnvironmentObject var challengeService: ChallengeService
  @Environment(\.dismiss) private var dismiss
  @State private var challengeTitle = ""
  @State private var selectedType: ChallengeType = .wellness
  @State private var selectedDifficulty: Int = 1
  @State private var customAura: String = ""
  @State private var selectedDuration: Int = 0  // 0 = permanent, 7 = 1 week, 30 = 1 month, etc.
  @State private var isCreating = false
  @State private var showSuccess = false
  @State private var showSuccessMessage = false

  // Reminder settings
  @State private var useDefaultReminders = true
  @State private var customReminderMode: ReminderMode = .smart
  @State private var customReminderTime = Date()
  @State private var enableEveningNudge = true
  @State private var eveningNudgeTime = Date()
  @State private var selectedWeekdays: Set<Int> = Set(1...7)  // All days by default
  @State private var showAdvancedReminders = false
  @State private var useMultiPing = false
  @State private var multiPingTimes = 3
  @State private var multiPingStartHour = 9
  @State private var multiPingEndHour = 21

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk
          .ignoresSafeArea()

        VStack(spacing: 0) {
          ScrollView {
            VStack(spacing: 24) {
              headerView
              formView
            }
            .padding()
          }

          createButtonView
        }
      }
      .navigationTitle("Custom Challenge")
      .navigationBarTitleDisplayMode(.inline)
      .preferredColorScheme(.dark)
      .alert("Challenge Created!", isPresented: $showSuccessMessage) {
        Button("OK") {
          dismiss()
        }
      } message: {
        Text("Your custom challenge has been added to the home page under \"Custom Challenges\"")
      }
    }
  }

  private var headerView: some View {
    VStack(spacing: 8) {
      Text("Create Custom Challenge")
        .titleStyle()
        .foregroundColor(.brandYellow)

      Text("Design your own daily challenge")
        .bodyStyle()
        .foregroundColor(.secondary)
    }
  }

  private var formView: some View {
    VStack(spacing: 20) {
      challengeTitleSection
      challengeTypeSection
      difficultySection
      auraSection
      durationSection
      reminderSection
      previewSection
    }
    .padding()
    .background(Color.brandGray)
    .cornerRadius(20)
  }

  private var challengeTitleSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Challenge Title")
        .headlineStyle()
        .foregroundColor(.white)

      TextField("Enter your challenge...", text: $challengeTitle)
        .textFieldStyle(CustomTextFieldStyle())
    }
  }

  private var challengeTypeSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Type")
        .headlineStyle()
        .foregroundColor(.white)

      HStack(spacing: 8) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(ChallengeType.allCases, id: \.self) { type in
              typeButton(for: type)
            }
          }
          .padding(.horizontal, 4)
        }

        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundColor(.secondary)
          .opacity(0.7)
      }
    }
  }

  private var difficultySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Difficulty")
        .headlineStyle()
        .foregroundColor(.white)

      HStack {
        ForEach(1...3, id: \.self) { level in
          Button(action: {
            selectedDifficulty = level
          }) {
            Text("\(level)")
              .fontWeight(.semibold)
              .foregroundColor(selectedDifficulty == level ? .brandInk : .white)
              .frame(width: 40, height: 40)
              .background(
                Circle()
                  .fill(selectedDifficulty == level ? Color.brandYellow : Color.brandGray)
              )
          }
        }

        Spacer()

        Text(difficultyText)
          .bodyStyle()
          .foregroundColor(.secondary)
      }
    }
  }

  private var auraSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Aura")
        .headlineStyle()
        .foregroundColor(.white)

      VStack(alignment: .leading, spacing: 8) {
        TextField("Enter Aura (10-50)", text: $customAura)
          .textFieldStyle(CustomTextFieldStyle())
          .keyboardType(.numberPad)

        Text("Choose Aura between 10-50 for fair friend comparisons")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }

  private var durationSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Duration")
        .headlineStyle()
        .foregroundColor(.white)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(durationOptions, id: \.value) { option in
            Button(action: {
              selectedDuration = option.value
            }) {
              Text(option.label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(selectedDuration == option.value ? .brandInk : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                  RoundedRectangle(cornerRadius: 16)
                    .fill(
                      selectedDuration == option.value ? Color.brandYellow : Color.brandGray
                    )
                )
            }
          }
        }
        .padding(.horizontal, 4)
      }
    }
  }

  private var reminderSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Reminder Settings")
        .headlineStyle()
        .foregroundColor(.white)

      // Toggle for using default vs custom reminders
      VStack(alignment: .leading, spacing: 12) {
        Toggle("Use default reminder settings", isOn: $useDefaultReminders)
          .foregroundColor(.white)
          .toggleStyle(SwitchToggleStyle(tint: .brandYellow))

        if !useDefaultReminders {
          VStack(alignment: .leading, spacing: 12) {
            // Reminder mode selection
            VStack(alignment: .leading, spacing: 8) {
              Text("Reminder Mode")
                .bodyStyle()
                .foregroundColor(.white)

              Picker("Mode", selection: $customReminderMode) {
                ForEach(ReminderMode.allCases, id: \.self) { mode in
                  Text(mode.displayName).tag(mode)
                }
              }
              .pickerStyle(SegmentedPickerStyle())
            }

            // Time picker (only for daily/selectedDays modes)
            if customReminderMode != .off {
              VStack(alignment: .leading, spacing: 8) {
                Text("Reminder Time")
                  .bodyStyle()
                  .foregroundColor(.white)

                DatePicker(
                  "Time", selection: $customReminderTime, displayedComponents: .hourAndMinute
                )
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .colorScheme(.dark)
              }
            }

            // Weekday selection (only for selectedDays mode)
            if customReminderMode == .selectedDays {
              VStack(alignment: .leading, spacing: 8) {
                Text("Days")
                  .bodyStyle()
                  .foregroundColor(.white)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                  ForEach(1...7, id: \.self) { day in
                    let dayName = Calendar.current.shortWeekdaySymbols[day - 1]
                    Button(action: {
                      if selectedWeekdays.contains(day) {
                        selectedWeekdays.remove(day)
                      } else {
                        selectedWeekdays.insert(day)
                      }
                    }) {
                      Text(dayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(selectedWeekdays.contains(day) ? .brandInk : .white)
                        .frame(width: 32, height: 32)
                        .background(
                          RoundedRectangle(cornerRadius: 8)
                            .fill(
                              selectedWeekdays.contains(day) ? Color.brandYellow : Color.brandGray)
                        )
                    }
                  }
                }
              }
            }

            // Evening nudge toggle
            VStack(alignment: .leading, spacing: 8) {
              Toggle("Evening nudge", isOn: $enableEveningNudge)
                .foregroundColor(.white)
                .toggleStyle(SwitchToggleStyle(tint: .brandYellow))

              if enableEveningNudge {
                DatePicker(
                  "Nudge Time", selection: $eveningNudgeTime, displayedComponents: .hourAndMinute
                )
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .colorScheme(.dark)
              }
            }

            // Advanced options for edge cases
            VStack(alignment: .leading, spacing: 8) {
              Button(action: {
                showAdvancedReminders.toggle()
              }) {
                HStack {
                  Text("Advanced Options")
                    .bodyStyle()
                    .foregroundColor(.brandYellow)
                  Spacer()
                  Image(systemName: showAdvancedReminders ? "chevron.up" : "chevron.down")
                    .foregroundColor(.brandYellow)
                }
              }

              if showAdvancedReminders {
                VStack(alignment: .leading, spacing: 12) {
                  Toggle("Multiple reminders per day", isOn: $useMultiPing)
                    .foregroundColor(.white)
                    .toggleStyle(SwitchToggleStyle(tint: .brandYellow))

                  if useMultiPing {
                    VStack(alignment: .leading, spacing: 8) {
                      Text("Reminders per day: \(multiPingTimes)")
                        .bodyStyle()
                        .foregroundColor(.white)

                      Slider(
                        value: Binding(
                          get: { Double(multiPingTimes) },
                          set: { multiPingTimes = Int($0) }
                        ), in: 2...6, step: 1
                      )
                      .accentColor(.brandYellow)

                      HStack {
                        Text("Start: \(multiPingStartHour):00")
                          .captionStyle()
                          .foregroundColor(.secondary)
                        Spacer()
                        Text("End: \(multiPingEndHour):00")
                          .captionStyle()
                          .foregroundColor(.secondary)
                      }

                      HStack {
                        Text("Start Hour")
                          .captionStyle()
                          .foregroundColor(.white)
                        Slider(
                          value: Binding(
                            get: { Double(multiPingStartHour) },
                            set: { multiPingStartHour = Int($0) }
                          ), in: 0...23, step: 1
                        )
                        .accentColor(.brandYellow)
                      }

                      HStack {
                        Text("End Hour")
                          .captionStyle()
                          .foregroundColor(.white)
                        Slider(
                          value: Binding(
                            get: { Double(multiPingEndHour) },
                            set: { multiPingEndHour = Int($0) }
                          ), in: 0...23, step: 1
                        )
                        .accentColor(.brandYellow)
                      }
                    }
                  }
                }
                .padding()
                .background(Color.brandInk.opacity(0.3))
                .cornerRadius(12)
              }
            }
          }
          .padding()
          .background(Color.brandInk.opacity(0.2))
          .cornerRadius(12)
        }
      }
    }
  }

  private var previewSection: some View {
    Group {
      if !challengeTitle.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Preview")
            .headlineStyle()
            .foregroundColor(.white)

          ChallengePreviewCard(
            title: challengeTitle,
            type: selectedType,
            difficulty: selectedDifficulty
          )
        }
      }
    }
  }

  private var createButtonView: some View {
    VStack {
      Button(action: createChallenge) {
        HStack {
          if isCreating {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
              .scaleEffect(0.8)
          } else if showSuccess {
            Image(systemName: "checkmark.circle.fill")
          } else {
            Image(systemName: "plus.circle.fill")
          }

          Text(
            showSuccess ? "Challenge Created!" : isCreating ? "Creating..." : "Create Challenge"
          )
        }
        .foregroundColor(.brandInk)
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity)
        .padding()
        .background(showSuccess ? Color.green : Color.brandYellow)
        .cornerRadius(16)
      }
      .disabled(challengeTitle.isEmpty || isCreating || showSuccess)
      .opacity(challengeTitle.isEmpty ? 0.6 : 1.0)
      .padding(.horizontal)
      .padding(.bottom, 20)
    }
  }

  private func typeButton(for type: ChallengeType) -> some View {
    Button(action: {
      selectedType = type
    }) {
      HStack(spacing: 6) {
        Text(type.emoji)
          .font(.caption)
        Text(type.displayName)
          .font(.caption)
          .fontWeight(.medium)
      }
      .foregroundColor(selectedType == type ? .brandInk : .white)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(selectedType == type ? Color.brandYellow : Color.brandGray)
      )
    }
  }

  private var difficultyText: String {
    switch selectedDifficulty {
    case 1: return "Easy"
    case 2: return "Medium"
    case 3: return "Hard"
    default: return ""
    }
  }

  private var durationOptions: [(label: String, value: Int)] {
    [
      ("Permanent", 0),
      ("1 Week", 7),
      ("2 Weeks", 14),
      ("1 Month", 30),
      ("2 Months", 60),
      ("3 Months", 90),
      ("6 Months", 180),
      ("1 Year", 365),
    ]
  }

  private func createChallenge() {
    guard !challengeTitle.isEmpty else { return }

    // Validate Aura input
    let auraPoints: Int?
    if !customAura.isEmpty {
      guard let aura = Int(customAura), aura >= 10 && aura <= 50 else {
        // Show error for invalid Aura
        return
      }
      auraPoints = aura
    } else {
      auraPoints = nil
    }

    // Create reminder override if custom settings are used
    let reminderOverride: ReminderOverride?
    if !useDefaultReminders {
      let calendar = Calendar.current
      let reminderTimeComponents = calendar.dateComponents(
        [.hour, .minute], from: customReminderTime)
      let eveningTimeComponents = calendar.dateComponents([.hour, .minute], from: eveningNudgeTime)

      let customConfig = ReminderConfig(
        mode: customReminderMode,
        time: customReminderMode != .off ? reminderTimeComponents : nil,
        selectedWeekdays: customReminderMode == .selectedDays ? selectedWeekdays : nil,
        eveningAnchor: enableEveningNudge ? eveningTimeComponents : nil,
        enableEveningNudge: enableEveningNudge
      )

      let multiPingConfig: MultiPingConfig? =
        useMultiPing
        ? MultiPingConfig(
          timesPerDay: multiPingTimes,
          startHour: multiPingStartHour,
          endHour: multiPingEndHour
        ) : nil

      reminderOverride = ReminderOverride(
        useDefaultSettings: false,
        customConfig: customConfig,
        multiPingConfig: multiPingConfig
      )
    } else {
      reminderOverride = nil
    }

    isCreating = true

    Task {
      do {
        let _ = try await challengeService.createCustomChallenge(
          title: challengeTitle,
          type: selectedType,
          difficulty: selectedDifficulty,
          customAura: auraPoints,
          durationDays: selectedDuration == 0 ? nil : selectedDuration,
          reminderOverride: reminderOverride
        )

        await MainActor.run {
          isCreating = false
          showSuccessMessage = true
        }
      } catch {
        await MainActor.run {
          isCreating = false
          print("Error creating custom challenge: \(error)")
        }
      }
    }
  }
}

struct ChallengePreviewCard: View {
  let title: String
  let type: ChallengeType
  let difficulty: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .title2Style()
        .foregroundColor(.white)

      HStack {
        Image(systemName: typeIcon)
          .foregroundColor(.brandYellow)

        Text(type.rawValue.capitalized)
          .headlineStyle()
          .foregroundColor(.brandYellow)

        Spacer()

        HStack(spacing: 4) {
          ForEach(1...3, id: \.self) { level in
            Image(systemName: "star.fill")
              .foregroundColor(level <= difficulty ? .brandYellow : .gray)
              .font(.caption)
          }
        }
      }
    }
    .padding()
    .background(Color.brandInk)
    .cornerRadius(12)
  }

  private var typeIcon: String {
    switch type {
    case .mindfulness: return "brain.head.profile"
    case .fitness: return "figure.run"
    case .learning: return "book"
    case .creativity: return "paintbrush"
    case .social: return "person.2"
    case .productivity: return "checkmark.circle"
    case .wellness: return "heart"
    case .gratitude: return "hands.sparkles"
    }
  }
}

struct CustomTextFieldStyle: TextFieldStyle {
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .padding()
      .background(Color.brandInk)
      .cornerRadius(12)
      .foregroundColor(.white)
  }
}

#Preview {
  CustomChallengeEditor()
    .environmentObject(PaywallService(authService: AuthService()))
}
