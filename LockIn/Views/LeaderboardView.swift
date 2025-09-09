import SwiftUI

struct LeaderboardView: View {
  @EnvironmentObject var authService: AuthService
  @StateObject private var leaderboardService = LeaderboardService()
  @State private var selectedTab = 0

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
              Text("Global Leaderboard")
                .titleStyle()
                .foregroundColor(.brandYellow)

              Text("Top performers")
                .bodyStyle()
                .foregroundColor(.secondary)
            }

            // Tab Selector
            Picker("Leaderboard Type", selection: $selectedTab) {
              Text("Daily").tag(0)
              Text("Weekly").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            // Leaderboard
            if leaderboardService.isLoading {
              loadingView
            } else if currentLeaderboard.isEmpty {
              emptyView
            } else {
              leaderboardList
            }

            Spacer(minLength: 100)
          }
          .padding()
        }
      }
      .navigationTitle("Leaderboard")
      .navigationBarTitleDisplayMode(.large)
      .preferredColorScheme(.dark)
    }
    .task {
      await leaderboardService.loadLeaderboards()
    }
    .refreshable {
      await leaderboardService.refreshLeaderboards()
    }
    .onChange(of: selectedTab) { _ in
      logAnalytics()
    }
  }

  private var currentLeaderboard: [UserRow] {
    selectedTab == 0 ? leaderboardService.dailyTop50 : leaderboardService.weeklyTop50
  }

  private var leaderboardList: some View {
    VStack(spacing: 12) {
      ForEach(Array(currentLeaderboard.enumerated()), id: \.element.id) { index, user in
        leaderboardRow(user, rank: index + 1)
      }
    }
    .padding(20)
    .background(Color.brandGray)
    .cornerRadius(20)
  }

  private func leaderboardRow(_ user: UserRow, rank: Int) -> some View {
    HStack(spacing: 16) {
      // Rank
      ZStack {
        Circle()
          .fill(rankColor(rank))
          .frame(width: 32, height: 32)
        Text("\(rank)")
          .headlineStyle()
          .foregroundColor(.white)
      }

      // User Info
      VStack(alignment: .leading, spacing: 4) {
        Text(user.displayName?.isEmpty == false ? user.displayName! : "Anonymous")
          .headlineStyle()
          .foregroundColor(.white)
        Text(selectedTab == 0 ? "Daily" : "Weekly")
          .captionStyle()
          .foregroundColor(.secondary)
      }

      Spacer()

      // Count
      VStack(alignment: .trailing, spacing: 4) {
        Text("\(selectedTab == 0 ? user.dailyCount : user.weeklyCount)")
          .headlineStyle()
          .foregroundColor(.brandYellow)
        Text("completions")
          .captionStyle()
          .foregroundColor(.secondary)
      }
    }
    .padding(.vertical, 8)
  }

  private func rankColor(_ rank: Int) -> Color {
    switch rank {
    case 1: return .brandYellow
    case 2: return Color.gray.opacity(0.7)
    case 3: return Color.orange.opacity(0.7)
    default: return Color.brandGray
    }
  }

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: .brandYellow))
        .scaleEffect(1.5)
      Text("Loading leaderboard...")
        .bodyStyle()
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 200)
    .background(Color.brandGray)
    .cornerRadius(20)
  }

  private var emptyView: some View {
    VStack(spacing: 16) {
      Image(systemName: "trophy")
        .font(.largeTitle)
        .foregroundColor(.brandYellow)
      Text("No Data Yet")
        .headlineStyle()
        .foregroundColor(.white)
      Text("Complete challenges to see your rank!")
        .bodyStyle()
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 200)
    .padding(24)
    .background(Color.brandGray)
    .cornerRadius(20)
  }

  private func logAnalytics() {
    let scope = selectedTab == 0 ? "daily" : "weekly"
    AnalyticsService.shared.logLeaderboardView(scope: scope)
  }
}

#Preview {
  LeaderboardView()
    .environmentObject(AuthService())
}
