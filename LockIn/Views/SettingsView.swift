import AuthenticationServices
import CryptoKit
import FirebaseAuth
import GoogleSignIn
import SwiftUI
import UIKit

struct SettingsView: View {
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var paywallService: PaywallService
  @StateObject private var reminderService = ReminderService()
  @State private var showingSignOutAlert = false
  @State private var showingResetDataAlert = false
  @State private var showingBackupPrompt = false
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
    .alert("Reset Local Data", isPresented: $showingResetDataAlert) {
      Button("Cancel", role: .cancel) {}
      Button("Reset Data", role: .destructive) {
        Task {
          do {
            try await authService.resetLocalData()
          } catch {
            print("Error resetting data: \(error)")
          }
        }
      }
    } message: {
      Text("This will clear your streaks and progress on this device. This cannot be undone.")
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
    .sheet(isPresented: $showingBackupPrompt) {
      BackupProgressView()
    }
  }

  @ViewBuilder
  private var accountActionsSection: some View {
    if authService.isAnonymous {
      // For anonymous users, show backup and reset options
      VStack(spacing: 12) {
        // Backup Progress Button
        Button("Back Up Your Progress") {
          showingBackupPrompt = true
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.brandYellow)
        .foregroundColor(.brandInk)
        .cornerRadius(12)

        // Reset Data Button
        Button("Reset Local Data") {
          showingResetDataAlert = true
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.brandRed)
        .foregroundColor(.white)
        .cornerRadius(12)
      }
      .padding(.top, 8)
    } else {
      // For signed-in users, show sign out
      Button("Sign Out") {
        showingSignOutAlert = true
      }
      .frame(maxWidth: .infinity)
      .padding()
      .background(Color.brandRed)
      .foregroundColor(.white)
      .cornerRadius(12)
      .padding(.top, 8)
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

      // Account Actions Section
      accountActionsSection
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

      if paywallService.isPro {
        // Pro user - show subscription management
        VStack(spacing: 12) {
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.brandYellow)
            Text("Pro Active")
              .headlineStyle()
              .foregroundColor(.brandYellow)
            Spacer()
          }

          Text("You have access to all premium features")
            .bodyStyle()
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)

          Button("Manage Subscription") {
            manageSubscription()
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.brandYellow)
          .foregroundColor(.brandInk)
          .cornerRadius(12)
        }
      } else {
        // Free user - show upgrade option
        VStack(spacing: 12) {
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
      }
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

  private func manageSubscription() {
    // Open the system subscription management interface
    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
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
            .padding()
            .background(Color.brandGray)
            .foregroundColor(.white)
            .cornerRadius(12)
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
  @State private var showingFAQ = false
  @State private var showingAbout = false
  @State private var showingEmailAlert = false

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
            action: { showingFAQ = true }
          )

          helpRow(
            icon: "envelope.fill",
            title: "Contact Support",
            subtitle: "Get help from our team",
            action: openContactSupport
          )

          helpRow(
            icon: "info.circle.fill",
            title: "About",
            subtitle: "App version and info",
            action: { showingAbout = true }
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
    .sheet(isPresented: $showingFAQ) {
      FAQView()
    }
    .sheet(isPresented: $showingAbout) {
      AboutView()
    }
    .alert("Email Copied", isPresented: $showingEmailAlert) {
      Button("OK") {}
    } message: {
      Text("Email address copied to clipboard: thatnocodelife@gmail.com")
    }
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
    let email = "thatnocodelife@gmail.com"
    let subject = "LockIn Support Request"
    let body = "Hi there!\n\nI need help with:\n\n[Please describe your issue here]\n\nThanks!"

    // Create the mailto URL with proper encoding
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = email
    components.queryItems = [
      URLQueryItem(name: "subject", value: subject),
      URLQueryItem(name: "body", value: body),
    ]

    if let url = components.url {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
      } else {
        // Fallback: Copy email to clipboard and show SwiftUI alert
        UIPasteboard.general.string = email
        print("Email copied to clipboard: \(email)")
        showingEmailAlert = true
      }
    } else {
      // Ultimate fallback
      UIPasteboard.general.string = email
      print("Failed to create mailto URL, email copied to clipboard: \(email)")
      showingEmailAlert = true
    }
  }

}

// MARK: - FAQ View
struct FAQView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var expandedQuestions: Set<Int> = []

  let faqs = [
    FAQItem(
      question: "How do I complete a challenge?",
      answer:
        "Simply tap the 'Complete Challenge' button on your daily challenge. You can also add custom challenges by tapping the '+' button."
    ),
    FAQItem(
      question: "What are SMART reminders?",
      answer:
        "SMART reminders help you stay consistent with your habits. They include daily reminders, weekly quotas, and smart nudges that adapt to your behavior."
    ),
    FAQItem(
      question: "How do I add friends?",
      answer:
        "Friend functionality is coming soon! You'll be able to add friends using friend codes and compete on leaderboards together."
    ),
    FAQItem(
      question: "What's the difference between free and pro?",
      answer:
        "Free users get access to basic challenges and features. Pro users get unlimited custom challenges, advanced analytics, and premium features."
    ),
    FAQItem(
      question: "How do I reset my progress?",
      answer:
        "Go to Settings > Developer Options > Reset Data. This will clear all your progress and start fresh."
    ),
    FAQItem(
      question: "Can I use the app offline?",
      answer:
        "Yes! You can complete challenges and view your progress offline. Data will sync when you're back online."
    ),
    FAQItem(
      question: "How do I change my display name?",
      answer:
        "Go to Settings > Profile to update your display name. This will be visible on leaderboards and to friends."
    ),
    FAQItem(
      question: "What if I miss a day?",
      answer:
        "Don't worry! Missing a day is normal. The app focuses on consistency over perfection. Just get back on track the next day."
    ),
  ]

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 16) {
          VStack(spacing: 8) {
            Text("Frequently Asked Questions")
              .titleStyle()
              .foregroundColor(.brandYellow)

            Text("Find answers to common questions")
              .bodyStyle()
              .foregroundColor(.secondary)
          }
          .padding(.top)

          LazyVStack(spacing: 12) {
            ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
              FAQRow(
                faq: faq,
                isExpanded: expandedQuestions.contains(index),
                onTap: {
                  withAnimation(.easeInOut(duration: 0.3)) {
                    if expandedQuestions.contains(index) {
                      expandedQuestions.remove(index)
                    } else {
                      expandedQuestions.insert(index)
                    }
                  }
                }
              )
            }
          }
          .padding(.horizontal)
        }
      }
      .background(Color.brandInk)
      .navigationTitle("FAQ")
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
}

struct FAQItem {
  let question: String
  let answer: String
}

struct FAQRow: View {
  let faq: FAQItem
  let isExpanded: Bool
  let onTap: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button(action: onTap) {
        HStack {
          Text(faq.question)
            .headlineStyle()
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)

          Spacer()

          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .foregroundColor(.brandYellow)
            .font(.caption)
        }
        .padding()
      }
      .buttonStyle(PlainButtonStyle())

      if isExpanded {
        VStack(alignment: .leading, spacing: 8) {
          Divider()
            .background(Color.brandGray)

          Text(faq.answer)
            .bodyStyle()
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .background(Color.brandGray)
    .cornerRadius(12)
  }
}

// MARK: - About View
struct AboutView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          // App Icon and Title
          VStack(spacing: 16) {
            Image(systemName: "lock.fill")
              .font(.system(size: 60))
              .foregroundColor(.brandYellow)

            Text("LockIn")
              .titleStyle()
              .foregroundColor(.brandYellow)

            Text("Version 1.0.0")
              .bodyStyle()
              .foregroundColor(.secondary)
          }

          // App Description
          VStack(spacing: 16) {
            Text("About LockIn")
              .headlineStyle()
              .foregroundColor(.white)

            Text(
              "LockIn helps you build consistent daily habits through micro-challenges. Whether it's fitness, mindfulness, learning, or productivity, we make it easy to lock in your goals one small step at a time."
            )
            .bodyStyle()
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
          }

          // Features
          VStack(spacing: 12) {
            Text("Key Features")
              .headlineStyle()
              .foregroundColor(.white)

            VStack(spacing: 8) {
              featureRow(icon: "target", text: "90+ Preloaded Challenges")
              featureRow(icon: "bell", text: "SMART Reminders")
              featureRow(icon: "chart.bar", text: "Progress Tracking")
              featureRow(icon: "trophy", text: "Leaderboards")
              featureRow(icon: "person.2", text: "Friends (Coming Soon)")
            }
          }

          // Developer Info
          VStack(spacing: 12) {
            Text("Developer")
              .headlineStyle()
              .foregroundColor(.white)

            Text("Built with ❤️ by That No Code Life")
              .bodyStyle()
              .foregroundColor(.secondary)
          }

          // Legal
          VStack(spacing: 8) {
            Text("Legal")
              .headlineStyle()
              .foregroundColor(.white)

            HStack(spacing: 20) {
              Button("Privacy Policy") {
                if let url = URL(
                  string:
                    "https://destiny-fender-4ad.notion.site/Privacy-Policy-LockIn-Challenge-26b77834762b80679bfdd2fa0695b057?pvs=73"
                ) {
                  UIApplication.shared.open(url)
                }
              }
              .font(.caption)
              .foregroundColor(.brandYellow)

              Button("Terms of Service") {
                if let url = URL(
                  string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                {
                  UIApplication.shared.open(url)
                }
              }
              .font(.caption)
              .foregroundColor(.brandYellow)
            }
          }
        }
        .padding()
      }
      .background(Color.brandInk)
      .navigationTitle("About")
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

  private func featureRow(icon: String, text: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundColor(.brandYellow)
        .frame(width: 20)

      Text(text)
        .bodyStyle()
        .foregroundColor(.secondary)

      Spacer()
    }
  }
}

struct BackupProgressView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var authService: AuthService
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var currentNonce: String?

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          // Header
          VStack(spacing: 16) {
            Image(systemName: "icloud.and.arrow.up")
              .font(.system(size: 50))
              .foregroundColor(.brandYellow)

            Text("Back Up Your Progress")
              .titleStyle()
              .foregroundColor(.white)
              .multilineTextAlignment(.center)

            Text(
              "Create a free account to sync your streaks across devices and never lose your progress."
            )
            .bodyStyle()
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
          }

          // Benefits
          VStack(alignment: .leading, spacing: 12) {
            benefitRow(icon: "checkmark.circle", text: "Sync across all your devices")
            benefitRow(icon: "checkmark.circle", text: "Never lose your streaks")
            benefitRow(icon: "checkmark.circle", text: "Access your data anywhere")
            benefitRow(icon: "checkmark.circle", text: "Free forever")
          }
          .padding()
          .background(Color.brandGray)
          .cornerRadius(12)

          // Sign In Options
          VStack(spacing: 12) {
            SignInWithAppleButton(
              onRequest: { request in
                let nonce = randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(nonce)
              },
              onCompletion: { result in
                handleAppleSignIn(result: result)
              }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .cornerRadius(12)

            Button("Sign in with Google") {
              handleGoogleSignIn()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
          }

          if let errorMessage = errorMessage {
            Text(errorMessage)
              .bodyStyle()
              .foregroundColor(.red)
              .multilineTextAlignment(.center)
          }
        }
        .padding()
      }
      .background(Color.brandInk)
      .navigationTitle("Backup Progress")
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
  }

  private func benefitRow(icon: String, text: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundColor(.brandYellow)
        .frame(width: 20)

      Text(text)
        .bodyStyle()
        .foregroundColor(.white)

      Spacer()
    }
  }

  private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
    switch result {
    case .success(let authorization):
      guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
        let identityToken = appleIDCredential.identityToken,
        let identityTokenString = String(data: identityToken, encoding: .utf8),
        let nonce = currentNonce
      else {
        errorMessage = "Failed to get Apple ID credential"
        return
      }

      // ✅ Correct Firebase credential API for Apple
      let credential = OAuthProvider.appleCredential(
        withIDToken: identityTokenString,
        rawNonce: nonce,
        fullName: appleIDCredential.fullName
      )

      Task {
        do {
          try await authService.linkWithApple(credential: credential)
          dismiss()
        } catch {
          await MainActor.run {
            errorMessage = "Failed to link Apple account: \(error.localizedDescription)"
          }
        }
      }

    case .failure(let error):
      // Handle cancellation gracefully - don't show error for user cancellation
      if let authError = error as? ASAuthorizationError, authError.code == .canceled {
        // User cancelled - don't show error message
        return
      }
      errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
    }
  }

  private func handleGoogleSignIn() {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let presentingViewController = windowScene.windows.first?.rootViewController
    else {
      errorMessage = "Unable to present Google Sign In"
      return
    }

    GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) {
      result, error in
      if let error = error {
        DispatchQueue.main.async {
          // Handle cancellation gracefully
          if let gidError = error as? GIDSignInError, gidError.code == .canceled {
            // User cancelled - don't show error
            return
          }
          self.errorMessage = "Google Sign In failed: \(error.localizedDescription)"
        }
        return
      }

      guard let user = result?.user,
        let idToken = user.idToken?.tokenString
      else {
        DispatchQueue.main.async {
          self.errorMessage = "Failed to get Google ID token"
        }
        return
      }

      let credential = GoogleAuthProvider.credential(
        withIDToken: idToken, accessToken: user.accessToken.tokenString)

      Task {
        do {
          // Debug: Check if user is anonymous
          if let currentUser = Auth.auth().currentUser {
            print("Current user is anonymous: \(currentUser.isAnonymous)")
            print("Current user UID: \(currentUser.uid)")
          }

          try await self.authService.linkWithGoogle(credential: credential)
          await MainActor.run {
            self.dismiss()
          }
        } catch {
          await MainActor.run {
            print("Google linking error: \(error)")

            // Check if this is a Firestore permission error during linking
            if let firestoreError = error as? NSError,
              firestoreError.domain == "FIRFirestoreErrorDomain" && firestoreError.code == 7
            {
              print(
                "Firestore permission error during linking - this is expected, linking may have succeeded"
              )
              // Don't show error to user, just dismiss the view
              self.dismiss()
              return
            }

            self.errorMessage = "Failed to link Google account: \(error.localizedDescription)"
          }
        }
      }
    }
  }
}

#Preview {
  SettingsView()
    .environmentObject(AuthService())
}

// MARK: - Nonce helpers
func sha256(_ input: String) -> String {
  let inputData = Data(input.utf8)
  let hashed = SHA256.hash(data: inputData)
  return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

func randomNonceString(length: Int = 32) -> String {
  precondition(length > 0)
  let charset: [Character] = Array(
    "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
  var result = ""
  var remaining = length

  while remaining > 0 {
    var randoms = [UInt8](repeating: 0, count: 16)
    _ = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
    randoms.forEach { random in
      if remaining == 0 { return }
      if random < charset.count {
        result.append(charset[Int(random)])
        remaining -= 1
      }
    }
  }
  return result
}
