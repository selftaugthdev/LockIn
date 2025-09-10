import FirebaseFirestore
import Foundation
import PaywallKit
import RevenueCat
import SwiftUI

@MainActor
class PaywallService: ObservableObject {
  @Published var isPro = false
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let authService: AuthService

  init(authService: AuthService) {
    self.authService = authService
    setupRevenueCat()
    checkProStatus()
  }

  private func setupRevenueCat() {
    // Configure RevenueCat with your API key
    Purchases.logLevel = .debug
    Purchases.configure(withAPIKey: "your_revenuecat_api_key_here")

    // Set up user ID for RevenueCat
    if let userId = authService.uid {
      Purchases.shared.logIn(userId) { customerInfo, created, error in
        if let error = error {
          print("RevenueCat login error: \(error)")
        } else {
          print("RevenueCat login successful")
          self.checkProStatus()
        }
      }
    }
  }

  func checkProStatus() {
    Purchases.shared.getCustomerInfo { customerInfo, error in
      DispatchQueue.main.async {
        if let error = error {
          print("Error checking pro status: \(error)")
          self.errorMessage = "Failed to check subscription status"
        } else {
          self.isPro = customerInfo?.entitlements["pro"]?.isActive == true
          print("Pro status: \(self.isPro)")
        }
      }
    }
  }

  func purchase(package: Package) {
    isLoading = true
    errorMessage = nil

    Purchases.shared.purchase(package: package) { transaction, customerInfo, error, userCancelled in
      DispatchQueue.main.async {
        self.isLoading = false

        if let error = error {
          if !userCancelled {
            self.errorMessage = "Purchase failed: \(error.localizedDescription)"
          }
          return
        }

        if customerInfo?.entitlements["pro"]?.isActive == true {
          self.isPro = true
          self.updateUserProStatus(isPro: true)
          print("✅ Pro subscription activated!")
        }
      }
    }
  }

  func restorePurchases() {
    isLoading = true
    errorMessage = nil

    Purchases.shared.restorePurchases { customerInfo, error in
      DispatchQueue.main.async {
        self.isLoading = false

        if let error = error {
          self.errorMessage = "Restore failed: \(error.localizedDescription)"
          return
        }

        if customerInfo?.entitlements["pro"]?.isActive == true {
          self.isPro = true
          self.updateUserProStatus(isPro: true)
          print("✅ Purchases restored successfully!")
        } else {
          self.errorMessage = "No active subscriptions found"
        }
      }
    }
  }

  private func updateUserProStatus(isPro: Bool) {
    // Update the user's pro status in Firestore
    guard let uid = authService.uid else { return }

    let userRef = Firestore.firestore().collection("users").document(uid)
    userRef.updateData(["premium": isPro]) { error in
      if let error = error {
        print("Error updating user pro status: \(error)")
      } else {
        print("User pro status updated to: \(isPro)")
      }
    }
  }

  // MARK: - PaywallKit Integration

  func createPaywallView() -> some View {
    // Use your actual PaywallKit view here
    // This will be replaced with your PaywallKit view
    PaywallView(
      onPurchase: { package in
        self.purchase(package: package)
      },
      onRestore: {
        self.restorePurchases()
      }
    )
  }
}

struct ProFeatureRow: View {
  let icon: String
  let title: String
  let description: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .foregroundColor(.brandYellow)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .fontWeight(.semibold)
          .foregroundColor(.white)

        Text(description)
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()
    }
  }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundColor(.brandInk)
      .fontWeight(.semibold)
      .frame(maxWidth: .infinity)
      .padding()
      .background(Color.brandYellow)
      .cornerRadius(12)
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
  }
}

struct SecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundColor(.brandYellow)
      .fontWeight(.medium)
      .frame(maxWidth: .infinity)
      .padding()
      .background(Color.clear)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.brandYellow, lineWidth: 1)
      )
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
  }
}
