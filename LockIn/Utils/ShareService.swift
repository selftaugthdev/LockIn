import SwiftUI
import UIKit

class ShareService {
  static let shared = ShareService()

  private init() {}

  func shareStreak(_ streakCount: Int, from view: UIView) {
    // Create a custom share view with graphics and social media buttons
    let shareView = StreakShareView(streakCount: streakCount)
    let hostingController = UIHostingController(rootView: shareView)
    hostingController.modalPresentationStyle = .pageSheet

    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first
    {
      window.rootViewController?.present(hostingController, animated: true)
    }

    // Log analytics
    AnalyticsService.shared.logShareAttempt(type: "streak")
  }

  func shareAchievement(_ achievement: String, from view: UIView) {
    let shareText = "🏆 \(achievement) on Lock In! Ready to challenge yourself? #LockIn #Achievement"

    let activityViewController = UIActivityViewController(
      activityItems: [shareText],
      applicationActivities: nil
    )

    // For iPad
    if let popover = activityViewController.popoverPresentationController {
      popover.sourceView = view
      popover.sourceRect = view.bounds
    }

    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first
    {
      window.rootViewController?.present(activityViewController, animated: true)
    }

    // Log analytics
    AnalyticsService.shared.logShareAttempt(type: "achievement")
  }
}

// SwiftUI wrapper for sharing
struct ShareButton: UIViewRepresentable {
  let text: String
  let type: String

  func makeUIView(context: Context) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle("Share", for: .normal)
    button.backgroundColor = UIColor(Color.brandYellow)
    button.setTitleColor(UIColor(Color.brandInk), for: .normal)
    button.layer.cornerRadius = 12
    button.addTarget(context.coordinator, action: #selector(Coordinator.share), for: .touchUpInside)
    return button
  }

  func updateUIView(_ uiView: UIButton, context: Context) {
    // Update if needed
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject {
    let parent: ShareButton

    init(_ parent: ShareButton) {
      self.parent = parent
    }

    @objc func share() {
      let shareText = parent.text

      let activityViewController = UIActivityViewController(
        activityItems: [shareText],
        applicationActivities: nil
      )

      if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
        let window = windowScene.windows.first
      {
        window.rootViewController?.present(activityViewController, animated: true)
      }

      // Log analytics
      AnalyticsService.shared.logShareAttempt(type: parent.type)
    }
  }
}

// MARK: - Custom Streak Share View

struct StreakShareView: View {
  let streakCount: Int
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 24) {
            // Header
            Text("Share Your Streak!")
              .titleStyle()
              .foregroundColor(.brandYellow)
              .padding(.top)

            // Beautiful Streak Badge
            streakBadge

            // Share Text
            shareTextSection

            // Social Media Buttons
            socialMediaButtons

            // Copy Button
            copyButton

            Spacer(minLength: 50)
          }
          .padding()
        }
      }
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
  }

  private var streakBadge: some View {
    ZStack {
      // Background with gradient
      RoundedRectangle(cornerRadius: 24)
        .fill(
          LinearGradient(
            gradient: Gradient(colors: [
              Color.brandYellow.opacity(0.2), Color.brandBlue.opacity(0.1),
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 280, height: 200)
        .overlay(
          RoundedRectangle(cornerRadius: 24)
            .stroke(Color.brandYellow.opacity(0.3), lineWidth: 2)
        )

      VStack(spacing: 16) {
        // Fire icon
        Image(systemName: "flame.fill")
          .font(.system(size: 48, weight: .bold))
          .foregroundColor(.brandYellow)
          .shadow(color: .brandYellow.opacity(0.5), radius: 8, x: 0, y: 0)

        // Streak count
        Text("\(streakCount)")
          .font(.custom("Montserrat", size: 48, relativeTo: .largeTitle))
          .fontWeight(.bold)
          .foregroundColor(.white)

        // "DAY STREAK" text
        Text("DAY STREAK")
          .font(.custom("Montserrat", size: 16, relativeTo: .headline))
          .fontWeight(.semibold)
          .foregroundColor(.brandYellow)
          .tracking(2)

        // Lock In branding
        Text("LOCK IN")
          .font(.custom("Montserrat", size: 12, relativeTo: .caption))
          .fontWeight(.bold)
          .foregroundColor(.brandYellow.opacity(0.8))
          .tracking(1)
      }
    }
  }

  private var shareTextSection: some View {
    VStack(spacing: 12) {
      Text("Your Share Message:")
        .headlineStyle()
        .foregroundColor(.white)

      Text(
        "🔥 I've locked in for \(streakCount) days straight! Join me on 'The Great Lock In Challenge App' to build your own streak! #LockIn #Challenge"
      )
      .bodyStyle()
      .foregroundColor(.secondary)
      .multilineTextAlignment(.center)
      .padding()
      .background(Color.brandGray)
      .cornerRadius(12)
    }
  }

  private var socialMediaButtons: some View {
    VStack(spacing: 16) {
      Text("Share to Social Media")
        .headlineStyle()
        .foregroundColor(.white)

      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
        socialButton(icon: "camera.fill", title: "TikTok", color: .black) {
          shareToTikTok()
        }

        socialButton(icon: "camera.fill", title: "Instagram", color: .purple) {
          shareToInstagram()
        }

        socialButton(icon: "camera.fill", title: "Snapchat", color: .yellow) {
          shareToSnapchat()
        }

        socialButton(icon: "bird.fill", title: "Twitter", color: .blue) {
          shareToTwitter()
        }

        socialButton(icon: "square.and.arrow.up", title: "More", color: .gray) {
          shareToMore()
        }

        socialButton(icon: "link", title: "Copy Link", color: .green) {
          copyToClipboard()
        }
      }
    }
  }

  private func socialButton(icon: String, title: String, color: Color, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 24, weight: .semibold))
          .foregroundColor(.white)
          .frame(width: 50, height: 50)
          .background(color)
          .clipShape(Circle())

        Text(title)
          .captionStyle()
          .foregroundColor(.white)
      }
    }
    .buttonStyle(PlainButtonStyle())
  }

  private var copyButton: some View {
    Button(action: copyToClipboard) {
      HStack {
        Image(systemName: "doc.on.doc.fill")
        Text("Copy to Clipboard")
      }
      .font(.headline)
      .foregroundColor(.brandInk)
      .frame(maxWidth: .infinity)
      .padding()
      .background(Color.brandYellow)
      .cornerRadius(12)
    }
  }

  // MARK: - Share Actions

  private func shareToTikTok() {
    let shareText =
      "🔥 I've locked in for \(streakCount) days straight! Join me on Lock In to build your own streak! #LockIn #Streak"
    openURL(
      "https://www.tiktok.com/upload?text=\(shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    )
  }

  private func shareToInstagram() {
    let shareText =
      "🔥 I've locked in for \(streakCount) days straight! Join me on Lock In to build your own streak! #LockIn #Streak"
    openURL(
      "https://www.instagram.com/create/story/?text=\(shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    )
  }

  private func shareToSnapchat() {
    let shareText =
      "🔥 I've locked in for \(streakCount) days straight! Join me on Lock In to build your own streak! #LockIn #Streak"
    openURL(
      "snapchat://camera?text=\(shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    )
  }

  private func shareToTwitter() {
    let shareText =
      "🔥 I've locked in for \(streakCount) days straight! Join me on Lock In to build your own streak! #LockIn #Streak"
    openURL(
      "https://twitter.com/intent/tweet?text=\(shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    )
  }

  private func shareToMore() {
    let shareText =
      "🔥 I've locked in for \(streakCount) days straight! Join me on Lock In to build your own streak! #LockIn #Streak"

    let activityViewController = UIActivityViewController(
      activityItems: [shareText],
      applicationActivities: nil
    )

    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first
    {
      window.rootViewController?.present(activityViewController, animated: true)
    }
  }

  private func copyToClipboard() {
    let shareText =
      "🔥 I've locked in for \(streakCount) days straight! Join me on Lock In to build your own streak! #LockIn #Streak"
    UIPasteboard.general.string = shareText

    // Show feedback
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    impactFeedback.impactOccurred()
  }

  private func openURL(_ urlString: String) {
    if let url = URL(string: urlString) {
      if UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
      } else {
        // Fallback to web version
        let webURL = urlString.replacingOccurrences(
          of: "snapchat://", with: "https://www.snapchat.com/")
        if let webURL = URL(string: webURL) {
          UIApplication.shared.open(webURL)
        }
      }
    }
  }
}
