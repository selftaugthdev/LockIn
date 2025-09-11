import FirebaseFirestore
import Foundation
import RevenueCat
import SwiftUI

@MainActor
class PaywallService: ObservableObject {
  @Published var isPro = false
  @Published var isLoading = false
  @Published var errorMessage: String?
  @Published var shouldShowPaywall = false
  @Published var isPresentingPaywall = false
  @Published var presentationReady = true

  private let authService: AuthService
  private let userDefaults = UserDefaults.standard

  // Frequency capping keys
  private let lastPaywallShownKey = "lastPaywallShown"
  private let paywallShownCountKey = "paywallShownCount"
  private let lastPaywallShownWeekKey = "lastPaywallShownWeek"

  init(authService: AuthService) {
    self.authService = authService
    setupRevenueCat()
    checkProStatus()
  }

  private func setupRevenueCat() {
    // Configure RevenueCat with your API key
    Purchases.logLevel = .debug
    Purchases.configure(withAPIKey: "appl_LzsdTlJaBclpBLwEMQEzdiQRvVW")

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
          // Debug: Print all entitlements
          print("🔍 DEBUG checkProStatus - All entitlements:")
          for (key, entitlement) in customerInfo?.entitlements.all ?? [:] {
            print(
              "  - \(key): isActive=\(entitlement.isActive), willRenew=\(entitlement.willRenew)")
          }

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

        // Debug: Print all entitlements
        print("🔍 DEBUG: All entitlements:")
        for (key, entitlement) in customerInfo?.entitlements.all ?? [:] {
          print("  - \(key): isActive=\(entitlement.isActive), willRenew=\(entitlement.willRenew)")
        }

        // Check for pro entitlement
        if let proEntitlement = customerInfo?.entitlements["pro"], proEntitlement.isActive {
          self.isPro = true
          self.updateUserProStatus(isPro: true)
          print("✅ Pro subscription activated!")

          // Reset paywall state since user is now Pro
          self.shouldShowPaywall = false
          self.isPresentingPaywall = false
          self.presentationReady = true

          // Force a refresh of customer info to ensure status is updated
          self.checkProStatus()
        } else {
          print("❌ Pro entitlement not found or not active")
          print("🔍 Available entitlements: \(customerInfo?.entitlements.all.keys ?? [])")
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

          // Reset paywall state since user is now Pro
          self.shouldShowPaywall = false
          self.isPresentingPaywall = false
          self.presentationReady = true
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

  // MARK: - Frequency Capping

  func shouldShowPaywallModal() -> Bool {
    // Don't show if user is already Pro
    if isPro { return false }

    // Don't show if shown in last 24 hours
    if let lastShown = userDefaults.object(forKey: lastPaywallShownKey) as? Date {
      let hoursSinceLastShown = Date().timeIntervalSince(lastShown) / 3600
      if hoursSinceLastShown < 24 { return false }
    }

    // Don't show more than 2 times per week
    let currentWeek = Calendar.current.component(.weekOfYear, from: Date())
    let lastShownWeek = userDefaults.integer(forKey: lastPaywallShownWeekKey)
    let shownCount = userDefaults.integer(forKey: paywallShownCountKey)

    if currentWeek == lastShownWeek && shownCount >= 2 {
      return false
    }

    // Reset counter for new week
    if currentWeek != lastShownWeek {
      userDefaults.set(0, forKey: paywallShownCountKey)
      userDefaults.set(currentWeek, forKey: lastPaywallShownWeekKey)
    }

    return true
  }

  func recordPaywallShown() {
    userDefaults.set(Date(), forKey: lastPaywallShownKey)
    let currentCount = userDefaults.integer(forKey: paywallShownCountKey)
    userDefaults.set(currentCount + 1, forKey: paywallShownCountKey)
  }

  func showPaywallIfEligible() {
    if shouldShowPaywallModal() && !isPresentingPaywall {
      // Add a small delay to prevent presentation conflicts
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.isPresentingPaywall = true
        self.shouldShowPaywall = true
        self.recordPaywallShown()
      }
    }
  }

  func safeShowPaywall() {
    print("DEBUG: safeShowPaywall called")
    print("DEBUG: isPresentingPaywall: \(isPresentingPaywall)")
    print("DEBUG: presentationReady: \(presentationReady)")
    print("DEBUG: isPro: \(isPro)")

    // Don't show paywall if user is already Pro
    if isPro {
      print("DEBUG: User is already Pro, not showing paywall")
      return
    }

    if !isPresentingPaywall && presentationReady {
      print("DEBUG: Safe to show paywall")
      isPresentingPaywall = true

      // Add a small delay to ensure TabView is stable
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.shouldShowPaywall = true
      }
    } else {
      print("DEBUG: Not safe to show paywall, retrying in 0.5 seconds")
      presentationReady = false
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self.presentationReady = true
        self.safeShowPaywall()
      }
    }
  }

  // MARK: - PaywallKit Integration

  func createPaywallView() -> some View {
    PaywallView()
  }
}
