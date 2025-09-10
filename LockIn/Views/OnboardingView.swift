import SwiftUI

struct OnboardingView: View {
  @EnvironmentObject var authService: AuthService
  @State private var currentPage = 0

  private let pages = [
    OnboardingPage(
      title: "Welcome to Lock In",
      subtitle: "Build your streak with daily challenges",
      image: "target",
      description: "Complete one Lock In challenge each day to build your streak and earn points."
    ),
    OnboardingPage(
      title: "Track Your Progress",
      subtitle: "See your growth over time",
      image: "chart.line.uptrend.xyaxis",
      description: "Monitor your streak, view your progress, and celebrate your achievements."
    ),
    OnboardingPage(
      title: "Compete Globally",
      subtitle: "Climb the leaderboard",
      image: "trophy",
      description: "See how you rank against other users in the weekly leaderboard."
    ),
    OnboardingPage(
      title: "How 'The Great Lock In' Works",
      subtitle: "The ultimate self-improvement challenge",
      image: "book.closed",
      description:
        "The Great Lock In is a personal development challenge where you commit to consistent daily actions in areas you want to improve. Choose your focus areas, set your own rules, and track your progress as you build lasting habits and achieve your goals."
    ),
  ]

  var body: some View {
    ZStack {
      Color.brandInk
        .ignoresSafeArea()

      VStack(spacing: 0) {
        // Page Content
        TabView(selection: $currentPage) {
          ForEach(0..<pages.count, id: \.self) { index in
            onboardingPage(pages[index])
              .tag(index)
          }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .animation(.easeInOut, value: currentPage)

        // Bottom Section
        VStack(spacing: 24) {
          // Page Indicators
          HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
              Circle()
                .fill(index == currentPage ? Color.brandYellow : Color.brandGray)
                .frame(width: 8, height: 8)
                .animation(.easeInOut, value: currentPage)
            }
          }

          // Action Button
          Button(action: {
            if currentPage < pages.count - 1 {
              withAnimation {
                currentPage += 1
              }
            } else {
              Task {
                do {
                  try await authService.signInAnonymously()
                  authService.completeOnboarding()
                } catch {
                  print("Failed to sign in: \(error)")
                }
              }
            }
          }) {
            HStack {
              if authService.isLoading {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
                  .scaleEffect(0.8)
              } else {
                Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                  .headlineStyle()
                  .foregroundColor(.brandInk)
              }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brandYellow)
            .cornerRadius(16)
          }
          .disabled(authService.isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 50)
      }
    }
    .preferredColorScheme(.dark)
  }

  private func onboardingPage(_ page: OnboardingPage) -> some View {
    VStack(spacing: 40) {
      Spacer()

      // Image
      Image(systemName: page.image)
        .font(.system(size: 80))
        .foregroundColor(.brandYellow)

      // Content
      VStack(spacing: 16) {
        Text(page.title)
          .titleStyle()
          .foregroundColor(.white)
          .multilineTextAlignment(.center)

        Text(page.subtitle)
          .title2Style()
          .foregroundColor(.brandYellow)
          .multilineTextAlignment(.center)

        if currentPage == 3 {
          // Special detailed content for the 4th page
          detailedLockInExplanation()
        } else {
          Text(page.description)
            .bodyStyle()
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
      }

      Spacer()
    }
    .padding(.horizontal, 24)
  }

  private func detailedLockInExplanation() -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // How it works section
        VStack(alignment: .leading, spacing: 12) {
          Text("How It Works:")
            .headlineStyle()
            .foregroundColor(.brandYellow)

          VStack(alignment: .leading, spacing: 8) {
            explanationPoint(
              "Timeframe: The challenge runs for a set duration, like fall through end of year")
            explanationPoint(
              "Personal Goals: You choose what to focus on - fitness, learning, habits")
            explanationPoint("Rules & Tracking: Create your own rules and track daily progress")
            explanationPoint("Consistency: Show up regularly for your chosen activities")
            explanationPoint("Social Aspect: Share your journey and inspire others")
          }
        }

        // Common themes section
        VStack(alignment: .leading, spacing: 12) {
          Text("Common Focus Areas:")
            .headlineStyle()
            .foregroundColor(.brandYellow)

          VStack(alignment: .leading, spacing: 8) {
            explanationPoint("Physical Health: Exercise, healthy eating, fitness goals")
            explanationPoint("Mental Wellness: Meditation, self-care, positive habits")
            explanationPoint(
              "Skill Development: Learning languages, instruments, professional skills")
          }
        }

        // How to participate section
        VStack(alignment: .leading, spacing: 12) {
          Text("How to Participate:")
            .headlineStyle()
            .foregroundColor(.brandYellow)

          VStack(alignment: .leading, spacing: 8) {
            explanationPoint("1. Choose 1-5 areas of your life to improve")
            explanationPoint("2. Set specific rules and actions for each goal")
            explanationPoint("3. Commit to your chosen timeframe")
            explanationPoint("4. Track your wins and learn from any slips")
            explanationPoint("5. Share your journey to stay motivated")
          }
        }
      }
      .padding(.horizontal, 16)
    }
    .frame(maxHeight: 300)
  }

  private func explanationPoint(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
      Circle()
        .fill(Color.brandYellow)
        .frame(width: 6, height: 6)
        .padding(.top, 6)

      Text(text)
        .bodyStyle()
        .foregroundColor(.secondary)
        .multilineTextAlignment(.leading)
    }
  }
}

struct OnboardingPage {
  let title: String
  let subtitle: String
  let image: String
  let description: String
}

#Preview {
  OnboardingView()
    .environmentObject(AuthService())
}
