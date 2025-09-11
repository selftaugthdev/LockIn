import SwiftUI

struct ProgressView: View {
  @EnvironmentObject var authService: AuthService

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
              Text("Your Progress")
                .titleStyle()
                .foregroundColor(.brandYellow)

              Text("Track your streak and aura journey")
                .bodyStyle()
                .foregroundColor(.secondary)
            }

            // Streak Stats
            if let user = authService.currentUser {
              streakStatsCard(user)
            }

            // Progress Graph
            if let user = authService.currentUser {
              progressGraphCard(user)
            }

            Spacer(minLength: 100)
          }
          .padding()
        }
      }
      .navigationTitle("Progress")
      .navigationBarTitleDisplayMode(.large)
      .preferredColorScheme(.dark)
    }
  }

  private func streakStatsCard(_ user: User) -> some View {
    VStack(spacing: 20) {
      HStack {
        Text("Current Streak")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
        Text("\(user.streakCount) days")
          .titleStyle()
          .foregroundColor(.brandYellow)
      }

      HStack {
        Text("Status")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
        HStack {
          Circle()
            .fill(user.streakStatus == .active ? Color.brandGreen : Color.brandRed)
            .frame(width: 8, height: 8)
          Text(user.streakStatus == .active ? "Active" : "Broken")
            .bodyStyle()
            .foregroundColor(.secondary)
        }
      }

      if let lastCompleted = user.lastCompleted {
        HStack {
          Text("Last Completed")
            .headlineStyle()
            .foregroundColor(.white)
          Spacer()
          Text(lastCompleted, style: .date)
            .bodyStyle()
            .foregroundColor(.secondary)
        }
      }
    }
    .padding(24)
    .background(Color.brandGray)
    .cornerRadius(20)
  }

  private func progressGraphCard(_ user: User) -> some View {
    VStack(spacing: 20) {
      // Header
      HStack {
        Text("Progress Overview")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
        Image(systemName: "chart.line.uptrend.xyaxis")
          .foregroundColor(.brandYellow)
      }

      // Simple Progress Bars
      VStack(spacing: 16) {
        // Days Locked In
        progressBar(
          title: "Days Locked In",
          value: user.totalCount,
          maxValue: max(user.totalCount, 30),
          color: .brandBlue,
          icon: "calendar"
        )

        // Current Streak
        progressBar(
          title: "Current Streak",
          value: user.streakCount,
          maxValue: max(user.streakCount, 7),
          color: .brandGreen,
          icon: "flame"
        )

        // Aura Points (estimated: 10 points per completion)
        let auraPoints = user.totalCount * 10
        progressBar(
          title: "Earned Aura",
          value: auraPoints,
          maxValue: max(auraPoints, 100),
          color: .brandYellow,
          icon: "sparkles"
        )
      }

      // Motivational Message
      if user.streakCount > 0 {
        Text(motivationalMessage(for: user.streakCount))
          .bodyStyle()
          .foregroundColor(.brandYellow)
          .multilineTextAlignment(.center)
          .padding(.top, 8)
      }
    }
    .padding(24)
    .background(Color.brandGray)
    .cornerRadius(20)
  }

  private func progressBar(title: String, value: Int, maxValue: Int, color: Color, icon: String)
    -> some View
  {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: icon)
          .foregroundColor(color)
          .frame(width: 16)
        Text(title)
          .bodyStyle()
          .foregroundColor(.white)
        Spacer()
        Text("\(value)")
          .bodyStyle()
          .foregroundColor(color)
      }

      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          // Background
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.black.opacity(0.3))
            .frame(height: 8)

          // Progress
          RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: geometry.size.width * CGFloat(value) / CGFloat(maxValue), height: 8)
        }
      }
      .frame(height: 8)
    }
  }

  private func motivationalMessage(for streak: Int) -> String {
    switch streak {
    case 1...2:
      return "Great start! Keep the momentum going! 🔥"
    case 3...6:
      return "You're building a solid habit! 💪"
    case 7...13:
      return "One week strong! You're on fire! 🚀"
    case 14...29:
      return "Two weeks! You're unstoppable! ⭐"
    case 30...:
      return "A full month! You're a habit master! 🏆"
    default:
      return "Every day counts! Keep going! 💫"
    }
  }
}

#Preview {
  ProgressView()
    .environmentObject(AuthService())
}
