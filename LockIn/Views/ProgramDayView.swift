import SwiftUI

struct ProgramDayView: View {
  @EnvironmentObject var moduleService: ModuleService
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var paywallService: PaywallService
  @State private var isCompleting = false
  @State private var showConfetti = false
  @State private var showCompletionModal = false
  @State private var completedDay: Int = 0
  @State private var completedXP: Int = 0
  @State private var reflectionText: String = ""
  @State private var isSavingReflection = false
  @State private var reflectionSaved = false

  private var isNightlyReflectionUnlocked: Bool {
    Calendar.current.component(.hour, from: Date()) >= 19
  }

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk.ignoresSafeArea()

        ScrollView {
          VStack(spacing: 20) {
            if moduleService.isLoading {
              loadingView
            } else if let userModule = moduleService.activeModule,
              let day = moduleService.todaysModuleDay
            {
              greetingCard
              moduleHeader(userModule)
              mainChallengeCard(day: day, userModule: userModule)
              if moduleService.isTodayCompleted {
                completedState(userModule)
              } else {
                completeButton(userModule: userModule, day: day)
              }
              mentalEdgeCard(day: day)
              if isNightlyReflectionUnlocked || moduleService.isTodayCompleted {
                nightlyReflectionCard(day: day)
              }
              statsCard(userModule)
            } else if let userModule = moduleService.activeModule, userModule.isComplete {
              greetingCard
              moduleCompleteState(userModule)
            } else {
              errorView
            }

            Spacer(minLength: 80)
          }
          .padding(.horizontal, 20)
          .padding(.top, 8)
        }

        if showConfetti {
          ConfettiOverlay()
            .onAppear {
              DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showConfetti = false
              }
            }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Forge")
            .font(Typography.headline)
            .foregroundColor(.brandYellow)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          NavigationLink(destination: SettingsView()) {
            Image(systemName: "gear")
              .foregroundColor(.white.opacity(0.5))
          }
        }
      }
      .preferredColorScheme(.dark)
      .sheet(isPresented: $showCompletionModal) {
        DayCompletionSheet(
          dayNumber: completedDay,
          xpEarned: completedXP
        )
      }
    }
  }

  // MARK: - Greeting Card

  private var greetingCard: some View {
    let user = authService.currentUser
    let name = user?.displayName.flatMap { $0.isEmpty ? nil : $0 }
    let areas = user?.onboardingWhatFellApart ?? []

    return VStack(alignment: .leading, spacing: 6) {
      Text(greetingLine(name: name))
        .font(Typography.title2)
        .foregroundColor(.white)

      if !areas.isEmpty {
        Text("You're here to rebuild your \(areas.formatted(.list(type: .and))).")
          .font(Typography.subheadline)
          .foregroundColor(.white.opacity(0.4))
          .lineSpacing(2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 4)
    .padding(.bottom, 4)
  }

  private func greetingLine(name: String?) -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    let timeOfDay: String
    switch hour {
    case 5..<12:  timeOfDay = "Morning"
    case 12..<17: timeOfDay = "Afternoon"
    default:      timeOfDay = "Evening"
    }
    if let name { return "\(timeOfDay), \(name)." }
    return "\(timeOfDay)."
  }

  // MARK: - Module Header

  private func moduleHeader(_ userModule: UserModule) -> some View {
    let module = moduleService.activeModuleContent

    return VStack(spacing: 12) {
      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Day \(userModule.currentDay) of \(UserModule.durationDays)")
            .font(Typography.largeTitle)
            .foregroundColor(.white)
          Text(userModule.moduleTitle)
            .font(Typography.subheadline)
            .foregroundColor(.white.opacity(0.45))
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text("\(userModule.totalXPEarned) XP")
            .font(Typography.title3)
            .foregroundColor(.brandYellow)
          Text("earned")
            .font(Typography.caption)
            .foregroundColor(.white.opacity(0.35))
        }
      }

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.08))
            .frame(height: 4)
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.brandYellow)
            .frame(width: geo.size.width * userModule.progressPercentage, height: 4)
            .animation(.easeInOut(duration: 0.6), value: userModule.progressPercentage)
        }
      }
      .frame(height: 4)

      HStack {
        Text(module?.title.uppercased() ?? "")
          .font(Typography.caption2)
          .fontWeight(.semibold)
          .foregroundColor(.brandYellow.opacity(0.7))
          .tracking(1.5)
        Text("·")
          .foregroundColor(.white.opacity(0.2))
        Text(module?.tagline ?? "")
          .font(Typography.caption2)
          .foregroundColor(.white.opacity(0.35))
        Spacer()
        Text("\(userModule.daysRemaining) days left")
          .font(Typography.caption2)
          .foregroundColor(.white.opacity(0.3))
      }
    }
    .padding(20)
    .background(Color.brandGray)
    .cornerRadius(16)
  }

  // MARK: - Main Challenge Card

  private func mainChallengeCard(day: ModuleDay, userModule: UserModule) -> some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        Spacer()
        HStack(spacing: 4) {
          Image(systemName: "bolt.fill")
            .font(.caption)
            .foregroundColor(.brandYellow)
          Text("+\(day.xpReward) XP")
            .font(Typography.caption)
            .fontWeight(.semibold)
            .foregroundColor(.brandYellow)
        }
      }

      Text(day.challengeTitle)
        .font(Typography.title2)
        .foregroundColor(.white)
        .fixedSize(horizontal: false, vertical: true)

      Text(day.challengeDescription)
        .font(Typography.body)
        .foregroundColor(.white.opacity(0.55))
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)

      Divider()
        .background(Color.white.opacity(0.08))

      VStack(alignment: .leading, spacing: 8) {
        Text("TODAY'S ACTION")
          .font(Typography.caption2)
          .fontWeight(.semibold)
          .foregroundColor(.brandYellow.opacity(0.7))
          .tracking(1.5)

        Text(day.dailyAction)
          .font(Typography.subheadline)
          .foregroundColor(.white.opacity(0.75))
          .lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(24)
    .background(Color.brandGray)
    .cornerRadius(20)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(
          moduleService.isTodayCompleted
            ? Color.brandGreen.opacity(0.4)
            : Color.brandYellow.opacity(0.12),
          lineWidth: 1
        )
    )
  }

  // MARK: - Complete Button

  private func completeButton(userModule: UserModule, day: ModuleDay) -> some View {
    Button {
      Task { await complete() }
    } label: {
      HStack(spacing: 10) {
        if isCompleting {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
            .scaleEffect(0.85)
        } else {
          Image(systemName: "checkmark.circle.fill")
            .font(.title3)
        }
        Text(isCompleting ? "Completing..." : "Complete Day \(userModule.currentDay)")
          .font(Typography.headline)
          .foregroundColor(.brandInk)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 18)
      .background(Color.brandYellow)
      .cornerRadius(14)
    }
    .disabled(isCompleting)
  }

  // MARK: - Completed State

  private func completedState(_ userModule: UserModule) -> some View {
    HStack(spacing: 14) {
      Image(systemName: "checkmark.seal.fill")
        .font(.title2)
        .foregroundColor(.brandGreen)
      VStack(alignment: .leading, spacing: 3) {
        Text("Day \(userModule.currentDay) complete")
          .font(Typography.headline)
          .foregroundColor(.white)
        if userModule.currentDay < UserModule.durationDays {
          Text("Come back tomorrow for Day \(userModule.currentDay + 1).")
            .font(Typography.caption)
            .foregroundColor(.white.opacity(0.45))
        }
      }
      Spacer()
    }
    .padding(20)
    .background(Color.brandGreen.opacity(0.1))
    .cornerRadius(14)
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.brandGreen.opacity(0.3), lineWidth: 1)
    )
  }

  // MARK: - Module Complete State

  private func moduleCompleteState(_ userModule: UserModule) -> some View {
    let nextModule = moduleService.nextModule(after: userModule.moduleId)

    return VStack(spacing: 24) {
      VStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(Color.brandYellow.opacity(0.1))
            .frame(width: 72, height: 72)
          Image(systemName: "flame.fill")
            .font(.system(size: 32))
            .foregroundColor(.brandYellow)
        }

        Text("\(userModule.moduleTitle) complete.")
          .font(Typography.title2)
          .foregroundColor(.white)
          .multilineTextAlignment(.center)

        Text("7 days. \(userModule.totalXPEarned) XP earned.")
          .font(Typography.subheadline)
          .foregroundColor(.brandYellow)
      }

      if let next = nextModule {
        Button {
          Task {
            try? await moduleService.enrollInModule(next, pathId: userModule.pathId)
          }
        } label: {
          VStack(spacing: 4) {
            Text("Start Next Module")
              .font(Typography.headline)
              .foregroundColor(.brandInk)
            Text(next.title)
              .font(Typography.caption)
              .foregroundColor(.brandInk.opacity(0.6))
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 18)
          .background(Color.brandYellow)
          .cornerRadius(14)
        }
      } else {
        Text("You've completed the Foundation path.")
          .font(Typography.subheadline)
          .foregroundColor(.white.opacity(0.5))
          .multilineTextAlignment(.center)
      }
    }
    .padding(24)
    .background(Color.brandGray)
    .cornerRadius(20)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(Color.brandYellow.opacity(0.2), lineWidth: 1)
    )
  }

  // MARK: - Mental Edge Card

  private func mentalEdgeCard(day: ModuleDay) -> some View {
    let edge = day.mentalEdge
    let isPro = paywallService.isPro

    return VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 2) {
          Text("MENTAL EDGE")
            .font(Typography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.brandYellow.opacity(0.7))
            .tracking(1.5)
          HStack(spacing: 6) {
            Text(edge.figure)
              .font(Typography.headline)
              .foregroundColor(.white)
            Text("·")
              .foregroundColor(.white.opacity(0.25))
            Text(edge.sourceWork)
              .font(Typography.caption)
              .foregroundColor(.white.opacity(0.45))
            Text(edge.year)
              .font(Typography.caption)
              .foregroundColor(.white.opacity(0.3))
          }
        }
        Spacer()
        if !isPro {
          Image(systemName: "lock.fill")
            .font(.caption)
            .foregroundColor(.brandYellow.opacity(0.6))
        }
      }
      .padding(20)

      Divider()
        .background(Color.white.opacity(0.06))

      ZStack {
        Text(edge.content)
          .font(Typography.subheadline)
          .foregroundColor(.white.opacity(0.65))
          .lineSpacing(5)
          .fixedSize(horizontal: false, vertical: true)
          .padding(20)
          .blur(radius: isPro ? 0 : 6)

        if !isPro {
          VStack(spacing: 12) {
            Text("Unlock the Mental Edge")
              .font(Typography.headline)
              .foregroundColor(.white)
            Text("Philosophical insight from history's sharpest minds — every day.")
              .font(Typography.caption)
              .foregroundColor(.white.opacity(0.5))
              .multilineTextAlignment(.center)
            Button {
              paywallService.safeShowPaywall()
            } label: {
              Text("Go Pro")
                .font(Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.brandInk)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.brandYellow)
                .cornerRadius(10)
            }
          }
          .padding(20)
        }
      }
    }
    .background(Color.brandGray)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.brandYellow.opacity(isPro ? 0.15 : 0.08), lineWidth: 1)
    )
    .fullScreenCover(isPresented: $paywallService.shouldShowPaywall) {
      PaywallView()
    }
  }

  // MARK: - Nightly Reflection Card

  private func nightlyReflectionCard(day: ModuleDay) -> some View {
    let isPro = paywallService.isPro

    return VStack(alignment: .leading, spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("NIGHTLY REFLECTION")
            .font(Typography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white.opacity(0.4))
            .tracking(1.5)
          Text(day.nightlyReflection)
            .font(Typography.subheadline)
            .foregroundColor(.white.opacity(isPro ? 0.75 : 0.3))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        if !isPro {
          Image(systemName: "lock.fill")
            .font(.caption)
            .foregroundColor(.white.opacity(0.3))
        }
      }
      .padding(20)

      if isPro {
        Divider()
          .background(Color.white.opacity(0.06))

        if reflectionSaved {
          HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.brandGreen)
              .font(.caption)
            Text("Saved.")
              .font(Typography.caption)
              .foregroundColor(.brandGreen)
          }
          .padding(20)
        } else {
          VStack(spacing: 12) {
            TextEditor(text: $reflectionText)
              .font(Typography.body)
              .foregroundColor(.white)
              .scrollContentBackground(.hidden)
              .background(Color.clear)
              .frame(minHeight: 80)

            Button {
              Task { await saveReflection(day: day) }
            } label: {
              HStack(spacing: 6) {
                if isSavingReflection {
                  ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
                    .scaleEffect(0.7)
                }
                Text(isSavingReflection ? "Saving..." : "Save Reflection")
                  .font(Typography.subheadline)
                  .fontWeight(.semibold)
                  .foregroundColor(.brandInk)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(
                reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  ? Color.brandYellow.opacity(0.4)
                  : Color.brandYellow
              )
              .cornerRadius(10)
            }
            .disabled(
              reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || isSavingReflection
            )
          }
          .padding(20)
        }
      }
    }
    .background(Color.brandGray)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.06), lineWidth: 1)
    )
  }

  // MARK: - Stats Card

  private func statsCard(_ userModule: UserModule) -> some View {
    let streak = authService.currentUser?.streakCount ?? 0

    return HStack(spacing: 0) {
      statCell(label: "Day", value: "\(userModule.currentDay)/\(UserModule.durationDays)")
      Divider().background(Color.white.opacity(0.08)).frame(height: 40)
      statCell(label: "XP Earned", value: "\(userModule.totalXPEarned)")
      Divider().background(Color.white.opacity(0.08)).frame(height: 40)
      statCell(label: "Streak", value: "\(streak)")
    }
    .padding(.vertical, 16)
    .background(Color.brandGray)
    .cornerRadius(14)
  }

  private func statCell(label: String, value: String) -> some View {
    VStack(spacing: 4) {
      Text(value)
        .font(Typography.title3)
        .foregroundColor(.white)
      Text(label)
        .font(Typography.caption2)
        .foregroundColor(.white.opacity(0.35))
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Loading / Error

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: .brandYellow))
        .scaleEffect(1.2)
      Text("Loading your module...")
        .font(Typography.body)
        .foregroundColor(.white.opacity(0.4))
    }
    .frame(maxWidth: .infinity, minHeight: 200)
  }

  private var errorView: some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundColor(.brandRed)
      Text("Something went wrong")
        .font(Typography.headline)
        .foregroundColor(.white)
      if let msg = moduleService.errorMessage {
        Text(msg)
          .font(Typography.subheadline)
          .foregroundColor(.white.opacity(0.4))
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 200)
  }

  // MARK: - Actions

  private func complete() async {
    guard let userModule = moduleService.activeModule,
      let day = moduleService.todaysModuleDay
    else { return }

    let dayNumber = userModule.currentDay
    let xpEarned = day.xpReward

    isCompleting = true
    do {
      try await moduleService.completeModuleDay()
      completedDay = dayNumber
      completedXP = xpEarned
      showConfetti = true
      if let uid = authService.uid {
        await authService.loadUserData(uid: uid)
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
        showCompletionModal = true
      }
      if !paywallService.isPro {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
          paywallService.showPaywallIfEligible()
        }
      }
    } catch {
      print("ProgramDayView: completion failed — \(error)")
    }
    isCompleting = false
  }

  private func saveReflection(day: ModuleDay) async {
    guard let uid = authService.uid,
      let userModule = moduleService.activeModule
    else { return }
    let text = reflectionText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }

    isSavingReflection = true
    do {
      try await ReflectionService.shared.saveReflection(
        userId: uid,
        programId: userModule.moduleId,
        dayNumber: day.dayNumber,
        text: text
      )
      reflectionSaved = true
    } catch {
      print("ProgramDayView: failed to save reflection — \(error)")
    }
    isSavingReflection = false
  }
}

// MARK: - Day Completion Sheet

struct DayCompletionSheet: View {
  @Environment(\.dismiss) private var dismiss
  let dayNumber: Int
  let xpEarned: Int

  var body: some View {
    ZStack {
      Color.brandInk.ignoresSafeArea()

      VStack(spacing: 0) {
        Spacer()

        ZStack {
          Circle()
            .fill(Color.brandYellow.opacity(0.1))
            .frame(width: 80, height: 80)
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 40))
            .foregroundColor(.brandYellow)
        }
        .padding(.bottom, 24)

        Text("Day \(dayNumber) done.")
          .font(Typography.largeTitle)
          .foregroundColor(.white)
          .padding(.bottom, 8)

        Text("+\(xpEarned) XP earned")
          .font(Typography.subheadline)
          .foregroundColor(.brandYellow)
          .padding(.bottom, 36)

        Text(encouragement)
          .font(Typography.body)
          .foregroundColor(.white.opacity(0.6))
          .multilineTextAlignment(.center)
          .lineSpacing(5)
          .padding(.horizontal, 32)
          .padding(.bottom, 32)

        VStack(alignment: .leading, spacing: 10) {
          Text("UNTIL TOMORROW")
            .font(Typography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.brandYellow.opacity(0.7))
            .tracking(1.5)

          Text(untilTomorrowTip)
            .font(Typography.subheadline)
            .foregroundColor(.white.opacity(0.55))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.brandGray)
        .cornerRadius(14)
        .padding(.horizontal, 24)

        Spacer()

        Button {
          dismiss()
        } label: {
          Text("Got it")
            .font(Typography.headline)
            .foregroundColor(.brandInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.brandYellow)
            .cornerRadius(14)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 44)
      }
    }
    .preferredColorScheme(.dark)
  }

  private var encouragement: String {
    switch dayNumber {
    case 1:
      return "Day 1 is the one most people never take. You took it."
    case 2...5:
      return "The middle is where most people fade. You're still here."
    case 6:
      return "One day left. Most people never make it this far."
    case 7:
      return "Seven days. You said you would. And you did."
    default:
      return "Every day you show up, it gets harder to quit. That is the point."
    }
  }

  private var untilTomorrowTip: String {
    let tips = [
      "Read tomorrow's challenge tonight so it is already in your head when you wake up.",
      "Stay off your phone for the next hour. Let the win land without distraction.",
      "Write one sentence about how today felt. You do not need an app for that.",
      "Tell no one about today. This one is for you.",
      "Use the rest of today to do one small thing you have been putting off.",
      "Sleep before midnight. Tomorrow starts tonight.",
      "Eat a real meal tonight. You earned it, and tomorrow deserves a clean start.",
    ]
    return tips[(dayNumber - 1) % tips.count]
  }
}

#Preview {
  let auth = AuthService()
  ProgramDayView()
    .environmentObject(ModuleService(auth: auth))
    .environmentObject(auth)
    .environmentObject(PaywallService(authService: auth))
}
