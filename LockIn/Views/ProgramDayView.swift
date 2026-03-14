import SwiftUI

struct ProgramDayView: View {
  @EnvironmentObject var programService: ProgramService
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var paywallService: PaywallService
  @State private var isCompleting = false
  @State private var showConfetti = false

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk.ignoresSafeArea()

        ScrollView {
          VStack(spacing: 20) {
            if programService.isLoading {
              loadingView
            } else if let userProgram = programService.activeProgram,
              let day = programService.todaysProgramDay
            {
              programHeader(userProgram)
              if userProgram.isRecoveryDay {
                recoveryBanner
              }
              mainChallengeCard(day: day, userProgram: userProgram)
              if userProgram.isRecoveryDay, let bonus = programService.recoveryBonusDay {
                bonusChallengeCard(bonus)
              }
              if programService.isTodayCompleted {
                completedState(userProgram)
              } else {
                completeButton(userProgram: userProgram, day: day)
              }
              xpProgressCard(userProgram)
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
      }
      .preferredColorScheme(.dark)
    }
    .task {
      await programService.loadActiveProgram()
    }
  }

  // MARK: - Program Header

  private func programHeader(_ userProgram: UserProgram) -> some View {
    VStack(spacing: 12) {
      HStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Day \(userProgram.currentDay) of \(userProgram.programDurationDays)")
            .font(Typography.largeTitle)
            .foregroundColor(.white)
          Text(userProgram.programTitle)
            .font(Typography.subheadline)
            .foregroundColor(.white.opacity(0.45))
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text("\(userProgram.totalXPEarned) XP")
            .font(Typography.title3)
            .foregroundColor(.brandYellow)
          Text("earned")
            .font(Typography.caption)
            .foregroundColor(.white.opacity(0.35))
        }
      }

      // Progress bar
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.08))
            .frame(height: 4)
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.brandYellow)
            .frame(width: geo.size.width * userProgram.progressPercentage, height: 4)
            .animation(.easeInOut(duration: 0.6), value: userProgram.progressPercentage)
        }
      }
      .frame(height: 4)

      // Phase label
      if let program = programService.program,
        let day = programService.todaysProgramDay
      {
        HStack {
          Text(day.phase.displayName.uppercased())
            .font(Typography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.brandYellow.opacity(0.7))
            .tracking(1.5)
          Text("·")
            .foregroundColor(.white.opacity(0.2))
          Text(day.phase.tagline)
            .font(Typography.caption2)
            .foregroundColor(.white.opacity(0.35))
          Spacer()
          Text("\(userProgram.daysRemaining) days left")
            .font(Typography.caption2)
            .foregroundColor(.white.opacity(0.3))
        }
      }
    }
    .padding(20)
    .background(Color.brandGray)
    .cornerRadius(16)
  }

  // MARK: - Recovery Banner

  private var recoveryBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "arrow.counterclockwise.circle.fill")
        .font(.title3)
        .foregroundColor(.brandRed)
      VStack(alignment: .leading, spacing: 2) {
        Text("Recovery Day")
          .font(Typography.subheadline)
          .fontWeight(.semibold)
          .foregroundColor(.white)
        Text("You missed yesterday. Two challenges today — same XP. Earn it back.")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.5))
      }
      Spacer()
    }
    .padding(16)
    .background(Color.brandRed.opacity(0.1))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.brandRed.opacity(0.25), lineWidth: 1)
    )
  }

  // MARK: - Main Challenge Card

  private func mainChallengeCard(day: ProgramDay, userProgram: UserProgram) -> some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack {
        Badge(text: day.category.displayName, color: categoryColor(day.category))
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
    }
    .padding(24)
    .background(Color.brandGray)
    .cornerRadius(20)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(
          programService.isTodayCompleted
            ? Color.brandGreen.opacity(0.4)
            : Color.brandYellow.opacity(0.12),
          lineWidth: 1
        )
    )
  }

  // MARK: - Bonus Challenge Card (recovery days only)

  private func bonusChallengeCard(_ day: ProgramDay) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Recovery Challenge")
          .font(Typography.caption)
          .fontWeight(.semibold)
          .foregroundColor(.brandRed)
          .tracking(0.5)
        Spacer()
        Text("No bonus XP")
          .font(Typography.caption2)
          .foregroundColor(.white.opacity(0.3))
      }

      Text(day.challengeTitle)
        .font(Typography.headline)
        .foregroundColor(.white)

      Text(day.challengeDescription)
        .font(Typography.subheadline)
        .foregroundColor(.white.opacity(0.5))
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20)
    .background(Color.brandRed.opacity(0.07))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.brandRed.opacity(0.2), lineWidth: 1)
    )
  }

  // MARK: - Complete Button

  private func completeButton(userProgram: UserProgram, day: ProgramDay) -> some View {
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
        Text(isCompleting ? "Completing..." : completeButtonLabel(userProgram))
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

  private func completeButtonLabel(_ userProgram: UserProgram) -> String {
    userProgram.isRecoveryDay ? "Complete Both Challenges" : "Complete Day \(userProgram.currentDay)"
  }

  // MARK: - Completed State

  private func completedState(_ userProgram: UserProgram) -> some View {
    HStack(spacing: 14) {
      Image(systemName: "checkmark.seal.fill")
        .font(.title2)
        .foregroundColor(.brandGreen)
      VStack(alignment: .leading, spacing: 3) {
        Text("Day \(userProgram.currentDay) complete")
          .font(Typography.headline)
          .foregroundColor(.white)
        Text("Come back tomorrow for Day \(userProgram.currentDay + 1).")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.45))
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

  // MARK: - XP Progress Card

  private func xpProgressCard(_ userProgram: UserProgram) -> some View {
    HStack(spacing: 0) {
      statCell(
        label: "Day",
        value: "\(userProgram.currentDay)/\(userProgram.programDurationDays)"
      )
      Divider().background(Color.white.opacity(0.08)).frame(height: 40)
      statCell(label: "XP Earned", value: "\(userProgram.totalXPEarned)")
      Divider().background(Color.white.opacity(0.08)).frame(height: 40)
      statCell(label: "Streak", value: "\(userProgram.longestStreakInProgram)")
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
      Text("Loading your program...")
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
      if let msg = programService.errorMessage {
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
    isCompleting = true
    do {
      try await programService.completeProgramDay()
      showConfetti = true
      if let uid = authService.uid {
        await authService.loadUserData(uid: uid)
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

  // MARK: - Helpers

  private func categoryColor(_ type: ChallengeType) -> Color {
    Color(hex: type.color)
  }
}

#Preview {
  let auth = AuthService()
  ProgramDayView()
    .environmentObject(ProgramService(auth: auth))
    .environmentObject(auth)
    .environmentObject(PaywallService(authService: auth))
}
