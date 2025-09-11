import SwiftUI
import UIKit

struct SettingsView: View {
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var paywallService: PaywallService
  @StateObject private var reminderService = ReminderService()
  @State private var showingSignOutAlert = false
  @State private var showingCustomChallengeEditor = false
  @State private var showingPaywall = false
  @State private var showingReminderSettings = false
  @State private var showingProfileEditor = false
  @State private var showingPrivacySettings = false
  @State private var showingHelpSupport = false

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

            // Legal Section
            legalSection

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
    .sheet(isPresented: $showingReminderSettings) {
      GlobalReminderSettingsView(reminderService: reminderService)
    }
    .sheet(isPresented: $showingProfileEditor) {
      ProfileEditorView()
    }
    .sheet(isPresented: $showingPrivacySettings) {
      PrivacySettingsView()
    }
    .sheet(isPresented: $showingHelpSupport) {
      HelpSupportView()
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
        action: { showingProfileEditor = true }
      )

      settingsRow(
        icon: "bell",
        title: "Notifications",
        subtitle: reminderService.isNotificationAuthorized ? "Enabled" : "Tap to enable",
        action: { showingReminderSettings = true }
      )

      settingsRow(
        icon: "shield",
        title: "Privacy",
        subtitle: "Data and privacy settings",
        action: { showingPrivacySettings = true }
      )

      settingsRow(
        icon: "questionmark.circle",
        title: "Help & Support",
        subtitle: "Get help and contact us",
        action: { showingHelpSupport = true }
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

  private var legalSection: some View {
    VStack(spacing: 12) {
      HStack {
        Text("Legal")
          .headlineStyle()
          .foregroundColor(.white)
        Spacer()
      }

      settingsRow(
        icon: "hand.raised.fill",
        title: "Privacy Policy",
        subtitle: "How we protect your data",
        action: openPrivacyPolicy
      )

      settingsRow(
        icon: "doc.text.fill",
        title: "Terms of Service",
        subtitle: "App usage terms and conditions",
        action: openTermsOfService
      )
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
    .buttonStyle(PlainButtonStyle())
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

  // MARK: - Helper Methods

  private func openPrivacyPolicy() {
    if let url = URL(
      string:
        "https://destiny-fender-4ad.notion.site/Privacy-Policy-LockIn-Challenge-26b77834762b80679bfdd2fa0695b057?pvs=73"
    ) {
      UIApplication.shared.open(url)
    }
  }

  private func openTermsOfService() {
    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
      UIApplication.shared.open(url)
    }
  }
}

// MARK: - Profile Editor View
struct ProfileEditorView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var authService: AuthService
  @State private var displayName: String = ""

  var body: some View {
    NavigationView {
      VStack(spacing: 24) {
        VStack(spacing: 16) {
          Text("Update Profile")
            .titleStyle()
            .foregroundColor(.brandYellow)

          Text("Customize your display name")
            .bodyStyle()
            .foregroundColor(.secondary)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Display Name")
            .headlineStyle()
            .foregroundColor(.white)

          TextField("Enter your name", text: $displayName)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .foregroundColor(.brandInk)
        }

        Spacer()

        Button("Save Changes") {
          // TODO: Implement save functionality
          dismiss()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.brandYellow)
        .foregroundColor(.brandInk)
        .cornerRadius(12)
      }
      .padding()
      .background(Color.brandInk)
      .navigationTitle("Profile")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(.brandYellow)
        }
      }
    }
    .preferredColorScheme(.dark)
    .onAppear {
      displayName = authService.currentUser?.displayName ?? ""
    }
  }
}

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      VStack(spacing: 24) {
        VStack(spacing: 16) {
          Text("Privacy Settings")
            .titleStyle()
            .foregroundColor(.brandYellow)

          Text("Manage your data and privacy preferences")
            .bodyStyle()
            .foregroundColor(.secondary)
        }

        VStack(spacing: 16) {
          privacyRow(
            icon: "hand.raised.fill",
            title: "Privacy Policy",
            subtitle: "How we protect your data",
            action: openPrivacyPolicy
          )

          privacyRow(
            icon: "doc.text.fill",
            title: "Terms of Service",
            subtitle: "App usage terms and conditions",
            action: openTermsOfService
          )

          privacyRow(
            icon: "trash.fill",
            title: "Delete Account",
            subtitle: "Permanently remove your account",
            action: { /* TODO: Implement account deletion */  }
          )
        }

        Spacer()
      }
      .padding()
      .background(Color.brandInk)
      .navigationTitle("Privacy")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.brandYellow)
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private func privacyRow(
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
    .buttonStyle(PlainButtonStyle())
  }

  private func openPrivacyPolicy() {
    if let url = URL(
      string:
        "https://destiny-fender-4ad.notion.site/Privacy-Policy-LockIn-Challenge-26b77834762b80679bfdd2fa0695b057?pvs=73"
    ) {
      UIApplication.shared.open(url)
    }
  }

  private func openTermsOfService() {
    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
      UIApplication.shared.open(url)
    }
  }
}

// MARK: - Help & Support View
struct HelpSupportView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      VStack(spacing: 24) {
        VStack(spacing: 16) {
          Text("Help & Support")
            .titleStyle()
            .foregroundColor(.brandYellow)

          Text("Get help and contact our support team")
            .bodyStyle()
            .foregroundColor(.secondary)
        }

        VStack(spacing: 16) {
          helpRow(
            icon: "questionmark.circle.fill",
            title: "FAQ",
            subtitle: "Frequently asked questions",
            action: { /* TODO: Implement FAQ */  }
          )

          helpRow(
            icon: "envelope.fill",
            title: "Contact Support",
            subtitle: "Get help from our team",
            action: openContactSupport
          )

          helpRow(
            icon: "star.fill",
            title: "Rate the App",
            subtitle: "Share your feedback",
            action: { /* TODO: Implement app rating */  }
          )

          helpRow(
            icon: "info.circle.fill",
            title: "About",
            subtitle: "App version and info",
            action: { /* TODO: Implement about */  }
          )
        }

        Spacer()
      }
      .padding()
      .background(Color.brandInk)
      .navigationTitle("Help")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.brandYellow)
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  private func helpRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void)
    -> some View
  {
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
    .buttonStyle(PlainButtonStyle())
  }

  private func openContactSupport() {
    if let url = URL(string: "mailto:support@lockinapp.com?subject=LockIn Support Request") {
      UIApplication.shared.open(url)
    }
  }
}

#Preview {
  SettingsView()
    .environmentObject(AuthService())
}
