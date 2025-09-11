import SwiftUI
import UIKit

struct NotificationPermissionView: View {
  @StateObject private var reminderService = ReminderService()
  @State private var isRequestingPermission = false
  @State private var showPermissionDeniedAlert = false

  let onPermissionGranted: () -> Void
  let onPermissionDenied: () -> Void

  var body: some View {
    ZStack {
      Color.brandInk
        .ignoresSafeArea()

      VStack(spacing: 40) {
        Spacer()

        // Icon
        Image(systemName: "bell.badge")
          .font(.system(size: 80))
          .foregroundColor(.brandYellow)

        // Content
        VStack(spacing: 24) {
          Text("Stay on Track")
            .titleStyle()
            .foregroundColor(.white)
            .multilineTextAlignment(.center)

          Text("Get gentle reminders to complete your daily challenges")
            .title2Style()
            .foregroundColor(.brandYellow)
            .multilineTextAlignment(.center)

          VStack(alignment: .leading, spacing: 16) {
            benefitRow(
              icon: "clock",
              title: "Perfect Timing",
              description: "Reminders at the time that works best for you"
            )

            benefitRow(
              icon: "brain.head.profile",
              title: "Smart Adaptations",
              description: "Learn your patterns and optimize reminder timing"
            )

            benefitRow(
              icon: "moon.zzz",
              title: "Evening Nudges",
              description: "Gentle reminders if you haven't completed your challenge yet"
            )

            benefitRow(
              icon: "hand.raised.slash",
              title: "Respectful",
              description: "Easy to snooze, skip, or customize to your preferences"
            )
          }
          .padding(.horizontal, 32)
        }

        Spacer()

        // Action Buttons
        VStack(spacing: 16) {
          // Allow Notifications Button
          Button(action: requestNotificationPermission) {
            HStack {
              if isRequestingPermission {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "bell")
                Text("Allow Notifications")
              }
            }
            .font(.headline)
            .foregroundColor(.brandInk)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brandYellow)
            .cornerRadius(16)
          }
          .disabled(isRequestingPermission)

          // Skip Button
          Button(action: onPermissionDenied) {
            Text("Skip for Now")
              .font(.headline)
              .foregroundColor(.secondary)
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 50)
      }
    }
    .preferredColorScheme(.dark)
    .alert("Notifications Disabled", isPresented: $showPermissionDeniedAlert) {
      Button("Settings") {
        openAppSettings()
      }
      Button("Skip", role: .cancel) {
        onPermissionDenied()
      }
    } message: {
      Text("To enable notifications later, go to Settings > Lock In > Notifications")
    }
  }

  private func benefitRow(icon: String, title: String, description: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundColor(.brandYellow)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .headlineStyle()
          .foregroundColor(.white)

        Text(description)
          .bodyStyle()
          .foregroundColor(.secondary)
      }

      Spacer()
    }
  }

  private func requestNotificationPermission() {
    isRequestingPermission = true

    Task {
      let granted = await reminderService.requestNotificationPermission()

      await MainActor.run {
        isRequestingPermission = false

        if granted {
          onPermissionGranted()
        } else {
          // Check if permission was denied (not just not determined)
          if reminderService.notificationPermissionStatus == .denied {
            showPermissionDeniedAlert = true
          } else {
            onPermissionDenied()
          }
        }
      }
    }
  }

  private func openAppSettings() {
    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(settingsUrl)
    }
  }
}

// MARK: - Preview
struct NotificationPermissionView_Previews: PreviewProvider {
  static var previews: some View {
    NotificationPermissionView(
      onPermissionGranted: {},
      onPermissionDenied: {}
    )
  }
}
