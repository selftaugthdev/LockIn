import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var paywallService: PaywallService
  @State private var showingSignOutAlert = false
  @State private var showingCustomChallengeEditor = false
  @State private var showingPaywall = false

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
              Text("Settings")
                .titleStyle()
                .foregroundColor(.brandYellow)

              Text("Manage your account and preferences")
                .bodyStyle()
                .foregroundColor(.secondary)
            }

            // User Info
            if let user = authService.currentUser {
              userInfoCard(user)
            }

            // Settings Options
            settingsOptions

            // Premium Section
            premiumSection

            // Developer Options
            developerSection

            Spacer(minLength: 100)
          }
          .padding()
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.large)
      .preferredColorScheme(.dark)
    }
    .alert("Sign Out", isPresented: $showingSignOutAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Sign Out", role: .destructive) {
        do {
          try authService.signOut()
        } catch {
          print("Error signing out: \(error)")
        }
      }
    }
    .sheet(isPresented: $showingCustomChallengeEditor) {
      CustomChallengeEditor()
    }
    .sheet(isPresented: $showingPaywall) {
      PaywallView()
    }
  }

  private func userInfoCard(_ user: User) -> some View {
    VStack(spacing: 16) {
      HStack {
        Text("Account")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
      }

      HStack {
        Text("Friend Code")
          .bodyStyle()
          .foregroundColor(.secondary)
        Spacer()
        Text(user.friendCode ?? "N/A")
          .headlineStyle()
          .foregroundColor(.brandYellow)
      }

      HStack {
        Text("Member Since")
          .bodyStyle()
          .foregroundColor(.secondary)
        Spacer()
        Text(user.createdAt, style: .date)
          .bodyStyle()
          .foregroundColor(.white)
      }

      HStack {
        Text("Current Streak")
          .bodyStyle()
          .foregroundColor(.secondary)
        Spacer()
        Text("\(user.streakCount) days")
          .headlineStyle()
          .foregroundColor(.brandYellow)
      }
    }
    .padding(20)
    .background(Color.brandGray)
    .cornerRadius(16)
  }

  private var settingsOptions: some View {
    VStack(spacing: 12) {
      settingsRow(
        icon: "person.circle",
        title: "Profile",
        subtitle: "Update your display name",
        action: { /* TODO: Implement profile editing */  }
      )

      settingsRow(
        icon: "bell",
        title: "Notifications",
        subtitle: "Daily reminders and updates",
        action: { /* TODO: Implement notifications */  }
      )

      settingsRow(
        icon: "shield",
        title: "Privacy",
        subtitle: "Data and privacy settings",
        action: { /* TODO: Implement privacy settings */  }
      )

      settingsRow(
        icon: "questionmark.circle",
        title: "Help & Support",
        subtitle: "Get help and contact us",
        action: { /* TODO: Implement help */  }
      )
    }
    .padding(20)
    .background(Color.brandGray)
    .cornerRadius(16)
  }

  private var premiumSection: some View {
    VStack(spacing: 16) {
      HStack {
        Image(systemName: "crown")
          .foregroundColor(.brandYellow)
        Text("Premium")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
      }

      Text("Unlock custom challenges, advanced analytics, and premium themes")
        .bodyStyle()
        .foregroundColor(.secondary)
        .multilineTextAlignment(.leading)

      Button("Upgrade to Pro") {
        AnalyticsService.shared.logPremiumView()
        print("DEBUG: Upgrade to Pro button tapped")
        showingPaywall = true
      }
      .frame(maxWidth: .infinity)
      .padding()
      .background(Color.brandYellow)
      .foregroundColor(.brandInk)
      .cornerRadius(12)
    }
    .padding(20)
    .background(Color.brandGray)
    .cornerRadius(16)
  }

  private var developerSection: some View {
    VStack(spacing: 12) {
      HStack {
        Text("Developer")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
      }

      settingsRow(
        icon: "arrow.clockwise",
        title: "Reset Data",
        subtitle: "Clear all progress (dev only)",
        action: { /* TODO: Implement data reset */  }
      )

      settingsRow(
        icon: "square.and.arrow.up",
        title: "Export Data",
        subtitle: "Download your data",
        action: { /* TODO: Implement data export */  }
      )

      settingsRow(
        icon: "play.circle",
        title: "Reset Onboarding",
        subtitle: "Show onboarding again (dev only)",
        action: {
          authService.resetForTesting()
        }
      )

      Button("Sign Out") {
        showingSignOutAlert = true
      }
      .frame(maxWidth: .infinity)
      .padding()
      .background(Color.brandRed)
      .foregroundColor(.white)
      .cornerRadius(12)
    }
    .padding(20)
    .background(Color.brandGray)
    .cornerRadius(16)
  }

  private func settingsRow(
    icon: String, title: String, subtitle: String, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 16) {
        Image(systemName: icon)
          .foregroundColor(.brandYellow)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .headlineStyle()
            .foregroundColor(.white)
          Text(subtitle)
            .captionStyle()
            .foregroundColor(.secondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)
          .font(.caption)
      }
      .padding(.vertical, 8)
    }
  }

  // MARK: - Pro Feature Button
  private func ProFeatureButton(
    icon: String,
    title: String,
    description: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .foregroundColor(.brandYellow)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .fontWeight(.semibold)
            .foregroundColor(.white)

          Text(description)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)
          .font(.caption)
      }
      .padding()
      .background(Color.brandInk)
      .cornerRadius(12)
    }
  }
}

#Preview {
  SettingsView()
    .environmentObject(AuthService())
}
