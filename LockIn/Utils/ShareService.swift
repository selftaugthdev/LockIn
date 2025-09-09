import SwiftUI
import UIKit

class ShareService {
  static let shared = ShareService()

  private init() {}

  func shareStreak(_ streakCount: Int, from view: UIView) {
    let shareText =
      "🔥 I've locked in for \(streakCount) days straight! Join me on Lock In to build your own streak! #LockIn #Streak"

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
