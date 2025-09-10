import SwiftUI

struct DailyChallengeView: View {
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var challengeService: ChallengeService
  @EnvironmentObject var paywallService: PaywallService
  @State private var isCompleting = false
  @State private var showCompletionAnimation = false
  @State private var showingCustomEditor = false

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 24) {
            // Header
            headerSection

            // Challenge Card
            if let challenge = challengeService.todaysChallenge {
              challengeCard(challenge)

              // Pro Card (only show to free users)
              if !paywallService.isPro {
                ProCard()
              }
            } else if challengeService.isLoading {
              loadingView
            } else {
              errorView
            }

            // Streak Info
            if let user = authService.currentUser {
              streakSection(user)
              totalAuraSection(user)
            }

            Spacer(minLength: 100)
          }
          .padding()
        }
      }
      .navigationTitle("Today's Challenge")
      .navigationBarTitleDisplayMode(.large)
      .preferredColorScheme(.dark)
    }
    .task {
      await challengeService.loadTodaysChallenge()
    }
    .sheet(isPresented: $showingCustomEditor) {
      CustomChallengeEditor()
    }
    .fullScreenCover(isPresented: $paywallService.shouldShowPaywall) {
      PaywallView()
    }
    .onChange(of: paywallService.shouldShowPaywall) { _, newValue in
      if !newValue {
        paywallService.isPresentingPaywall = false
        paywallService.presentationReady = true
      }
    }
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 8) {
      Text("Lock In")
        .titleStyle()
        .foregroundColor(.brandYellow)

      Text("Complete today's challenge to build your streak")
        .bodyStyle()
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  // MARK: - Challenge Card

  private func challengeCard(_ challenge: Challenge) -> some View {
    VStack(spacing: 20) {
      // Challenge Type Badge
      HStack {
        Text(challenge.type.emoji)
          .font(.title2)
        Text(challenge.type.displayName)
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
        Text(challenge.difficultyText)
          .captionStyle()
          .padding(.horizontal, 12)
          .padding(.vertical, 4)
          .background(Color.brandGray)
          .cornerRadius(12)
      }

      // Challenge Title
      Text(challenge.title)
        .title2Style()
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal)

      // Aura Points
      HStack {
        Image(systemName: "sparkles")
          .foregroundColor(.brandYellow)
        Text("+ \(challenge.auraPoints) Aura")
          .headlineStyle()
          .foregroundColor(.brandYellow)
      }

      // Complete Button
      Button(action: {
        Task {
          await completeChallenge(challenge)
        }
      }) {
        HStack {
          if isCompleting {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
              .scaleEffect(0.8)
          } else {
            Image(systemName: "checkmark.circle.fill")
          }
          Text(isCompleting ? "Completing..." : "Complete Challenge")
            .headlineStyle()
            .foregroundColor(.brandInk)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.brandYellow)
        .cornerRadius(16)
      }
      .disabled(isCompleting || isChallengeCompleted(challenge))
      .opacity(isChallengeCompleted(challenge) ? 0.6 : 1.0)

      // Create Custom Challenge Button
      Button(action: {
        if paywallService.isPro {
          showingCustomEditor = true
        } else {
          paywallService.safeShowPaywall()
        }
      }) {
        HStack {
          Image(systemName: "plus.circle.fill")
          Text("Create Custom Challenge")
            .headlineStyle()
            .foregroundColor(.brandYellow)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.clear)
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color.brandYellow, lineWidth: 1)
        )
      }
    }
    .padding(24)
    .background(Color.brandGray)
    .cornerRadius(20)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(Color.brandYellow.opacity(0.3), lineWidth: 1)
    )
  }

  // MARK: - Streak Section

  private func streakSection(_ user: User) -> some View {
    VStack(spacing: 16) {
      HStack {
        Image(systemName: "flame.fill")
          .foregroundColor(.brandYellow)
        Text("Current Streak")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
        Text("\(user.streakCount)")
          .titleStyle()
          .foregroundColor(.brandYellow)
      }

      // Streak Status
      HStack {
        Circle()
          .fill(user.streakStatus == .active ? Color.brandGreen : Color.brandRed)
          .frame(width: 8, height: 8)
        Text(user.streakStatus == .active ? "Streak Active" : "Streak Broken")
          .captionStyle()
          .foregroundColor(.secondary)
        Spacer()

        if user.streakCount > 0 {
          Button(action: {
            ShareService.shared.shareStreak(user.streakCount, from: UIView())
          }) {
            Image(systemName: "square.and.arrow.up")
              .foregroundColor(.brandYellow)
          }
        }
      }
    }
    .padding(20)
    .background(Color.brandGray)
    .cornerRadius(16)
  }

  // MARK: - Total Aura Section

  private func totalAuraSection(_ user: User) -> some View {
    VStack(spacing: 16) {
      HStack {
        Image(systemName: "sparkles")
          .foregroundColor(.brandYellow)
        Text("Your Total Aura")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
      }

      HStack(spacing: 20) {
        // Circular Progress Chart
        ZStack {
          // Background circle
          Circle()
            .stroke(Color.brandGrayLight.opacity(0.3), lineWidth: 8)
            .frame(width: 80, height: 80)

          // Progress circle with gradient
          Circle()
            .trim(from: 0, to: min(CGFloat(user.totalAura ?? 0) / 1000.0, 1.0))
            .stroke(
              LinearGradient(
                colors: [.brandYellow, .brandGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .frame(width: 80, height: 80)
            .rotationEffect(.degrees(-90))
            .animation(.easeInOut(duration: 1.0), value: user.totalAura ?? 0)

          // Center text
          VStack(spacing: 2) {
            Text("\(user.totalAura ?? 0)")
              .title2Style()
              .foregroundColor(.brandYellow)
            Text("Total")
              .captionStyle()
              .foregroundColor(.secondary)
          }
        }

        // Aura breakdown
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Circle()
              .fill(Color.brandYellow)
              .frame(width: 8, height: 8)
            Text("Today: +\(challengeService.todaysChallenge?.auraPoints ?? 0)")
              .bodyStyle()
              .foregroundColor(.white)
          }

          HStack {
            Circle()
              .fill(Color.brandGreen)
              .frame(width: 8, height: 8)
            Text("Total: \(user.totalAura ?? 0)")
              .bodyStyle()
              .foregroundColor(.white)
          }

          if (user.totalAura ?? 0) < 1000 {
            Text("Next milestone: \(1000 - (user.totalAura ?? 0)) to go")
              .captionStyle()
              .foregroundColor(.secondary)
          } else {
            Text("🎉 Milestone reached!")
              .captionStyle()
              .foregroundColor(.brandGreen)
          }
        }

        Spacer()
      }
    }
    .padding(20)
    .background(Color.brandGray)
    .cornerRadius(16)
  }

  // MARK: - Loading View

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: .brandYellow))
        .scaleEffect(1.5)
      Text("Loading today's challenge...")
        .bodyStyle()
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 200)
    .background(Color.brandGray)
    .cornerRadius(20)
  }

  // MARK: - Error View

  private var errorView: some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundColor(.brandRed)
      Text("Failed to load challenge")
        .headlineStyle()
        .foregroundColor(.white)
      Text(challengeService.errorMessage ?? "Please try again")
        .bodyStyle()
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      Button("Retry") {
        Task {
          await challengeService.loadTodaysChallenge()
        }
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 12)
      .background(Color.brandYellow)
      .foregroundColor(.brandInk)
      .cornerRadius(12)
    }
    .frame(maxWidth: .infinity, minHeight: 200)
    .padding(24)
    .background(Color.brandGray)
    .cornerRadius(20)
  }

  // MARK: - Helper Methods

  private func isChallengeCompleted(_ challenge: Challenge) -> Bool {
    guard let user = authService.currentUser,
      let lastCompleted = user.lastCompleted
    else {
      return false
    }

    let calendar = Calendar.current
    return calendar.isDate(lastCompleted, inSameDayAs: Date())
  }

  private func completeChallenge(_ challenge: Challenge) async {
    isCompleting = true

    do {
      let _ = try await challengeService.completeChallenge(challenge)

      // The Cloud Function will handle updating user counters
      // We can refresh the user data to get the updated values
      if let uid = authService.uid {
        await authService.loadUserData(uid: uid)
      }

      // Log analytics
      AnalyticsService.shared.logChallengeComplete(
        challengeId: challenge.id ?? "",
        type: challenge.type.rawValue,
        difficulty: challenge.difficulty
      )

      // Use current user for analytics after refresh
      if let user = authService.currentUser {
        AnalyticsService.shared.logStreakIncremented(streakCount: user.streakCount)
        AnalyticsService.shared.setUserProperties(user: user)
      }

      // Show completion animation
      withAnimation(.spring()) {
        showCompletionAnimation = true
      }

      // Hide animation after delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        withAnimation {
          showCompletionAnimation = false
        }
      }

      // Show subtle upsell after completion (only for free users)
      if !paywallService.isPro {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
          paywallService.showPaywallIfEligible()
        }
      }

    } catch {
      print("Error completing challenge: \(error)")
    }

    isCompleting = false
  }
}

#Preview {
  DailyChallengeView()
    .environmentObject(AuthService())
    .environmentObject(ChallengeService(auth: AuthService()))
}
