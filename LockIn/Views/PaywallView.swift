import RevenueCat
import SwiftUI
import UIKit

struct PaywallView: View {
  @EnvironmentObject var paywallService: PaywallService
  @Environment(\.dismiss) private var dismiss
  @State private var packages: [Package] = []
  @State private var selectedPackage: Package?

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk.ignoresSafeArea()

        ScrollView {
          VStack(spacing: 32) {
            headerSection
            featuresSection
            pricingSection
            ctaSection
            footerSection
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 40)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Close") { dismiss() }
            .font(Typography.subheadline)
            .foregroundColor(.brandYellow)
        }
      }
      .preferredColorScheme(.dark)
    }
    .task { await loadPackages() }
    .onChange(of: paywallService.isPro) { _, isPro in
      if isPro { dismiss() }
    }
  }

  // MARK: - Header

  private var headerSection: some View {
    VStack(spacing: 16) {
      Image(systemName: "flame.fill")
        .font(.system(size: 52))
        .foregroundColor(.brandYellow)
        .padding(.top, 24)

      VStack(spacing: 12) {
        Text("The real work\nstarts here.")
          .font(Typography.largeTitle)
          .foregroundColor(.white)
          .multilineTextAlignment(.center)

        Text("Foundation gives you the map.\nPro gives you the weapons.")
          .font(Typography.body)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
    }
  }

  // MARK: - Features

  private var featuresSection: some View {
    VStack(spacing: 0) {
      ForgeFeatureRow(
        icon: "bolt.fill",
        title: "Mental Edge",
        description: "A philosopher's insight every day. The edge most men never develop."
      )
      Divider().background(Color.white.opacity(0.08))
      ForgeFeatureRow(
        icon: "bubble.left.fill",
        title: "Advisor",
        description: "Ask any philosopher anything. Direct, unfiltered strategic counsel — on demand."
      )
      Divider().background(Color.white.opacity(0.08))
      ForgeFeatureRow(
        icon: "moon.fill",
        title: "Nightly Reflection",
        description: "End each day with a reckoning. Lock in what you learned before it fades."
      )
      Divider().background(Color.white.opacity(0.08))
      ForgeFeatureRow(
        icon: "books.vertical.fill",
        title: "Library",
        description: "Every Mental Edge. Every Advisor session. Your arsenal — always within reach."
      )
    }
    .background(Color.brandGray)
    .cornerRadius(16)
  }

  // MARK: - Pricing

  private var pricingSection: some View {
    VStack(spacing: 10) {
      if packages.isEmpty {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .brandYellow))
          .frame(height: 120)
      } else {
        ForEach(sortedPackages, id: \.identifier) { package in
          ForgePlanRow(
            package: package,
            isSelected: selectedPackage?.identifier == package.identifier,
            isRecommended: package.packageType == .annual,
            onTap: { selectedPackage = package }
          )
        }
      }
    }
  }

  private var sortedPackages: [Package] {
    let order: [PackageType] = [.weekly, .monthly, .annual, .lifetime]
    return packages.sorted {
      (order.firstIndex(of: $0.packageType) ?? 99) < (order.firstIndex(of: $1.packageType) ?? 99)
    }
  }

  // MARK: - CTA

  private var ctaSection: some View {
    VStack(spacing: 14) {
      Button(action: {
        guard let package = selectedPackage else { return }
        paywallService.purchase(package: package)
      }) {
        HStack {
          if paywallService.isLoading {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
              .scaleEffect(0.8)
          } else {
            Text(ctaLabel)
              .font(Typography.headline)
          }
        }
        .foregroundColor(.brandInk)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.brandYellow)
        .cornerRadius(14)
      }
      .disabled(paywallService.isLoading || selectedPackage == nil)

      Button("Restore Purchases") {
        paywallService.restorePurchases()
      }
      .font(Typography.subheadline)
      .foregroundColor(.brandYellow.opacity(0.6))

      if let error = paywallService.errorMessage {
        Text(error)
          .font(Typography.caption)
          .foregroundColor(.brandRed)
          .multilineTextAlignment(.center)
      }
    }
  }

  private var ctaLabel: String {
    guard let package = selectedPackage else { return "Get Pro" }
    if package.storeProduct.introductoryDiscount != nil { return "Start 7-Day Free Trial" }
    if package.packageType == .lifetime { return "Get Lifetime Access" }
    return "Get Pro"
  }

  // MARK: - Footer

  private var footerSection: some View {
    VStack(spacing: 12) {
      if let package = selectedPackage, package.storeProduct.introductoryDiscount != nil {
        Text("Try free for 7 days. Cancel before your trial ends and you won't be charged.")
          .font(Typography.caption)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      } else {
        Text("Cancel anytime.")
          .font(Typography.caption)
          .foregroundColor(.secondary)
      }

      HStack(spacing: 20) {
        Button("Privacy Policy") { openPrivacyPolicy() }
          .font(Typography.caption)
          .foregroundColor(.secondary)
        Button("Terms") { openTermsOfService() }
          .font(Typography.caption)
          .foregroundColor(.secondary)
      }
    }
  }

  // MARK: - Helpers

  private func loadPackages() async {
    do {
      let offerings = try await Purchases.shared.offerings()
      if let current = offerings.current {
        await MainActor.run {
          self.packages = current.availablePackages
          self.selectedPackage =
            current.availablePackages.first { $0.packageType == .annual }
            ?? current.availablePackages.first
        }
      }
    } catch {
      print("Error loading packages: \(error)")
    }
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

// MARK: - Feature Row

struct ForgeFeatureRow: View {
  let icon: String
  let title: String
  let description: String

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: icon)
        .font(.system(size: 18))
        .foregroundColor(.brandYellow)
        .frame(width: 24)
        .padding(.top, 2)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(Typography.headline)
          .foregroundColor(.white)
        Text(description)
          .font(Typography.subheadline)
          .foregroundColor(.secondary)
      }

      Spacer()
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
  }
}

// MARK: - Plan Row

struct ForgePlanRow: View {
  let package: Package
  let isSelected: Bool
  let isRecommended: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 20))
          .foregroundColor(isSelected ? .brandYellow : .secondary)

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 8) {
            Text(planLabel)
              .font(Typography.headline)
              .foregroundColor(.white)
            if isRecommended {
              Text("BEST VALUE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.brandInk)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.brandYellow)
                .cornerRadius(4)
            }
          }
          if let subtitle = planSubtitle {
            Text(subtitle)
              .font(Typography.caption)
              .foregroundColor(.secondary)
          }
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
          Text(package.storeProduct.localizedPriceString)
            .font(Typography.headline)
            .foregroundColor(.white)
          Text(billingPeriod)
            .font(Typography.caption2)
            .foregroundColor(.secondary)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? Color.brandYellow.opacity(0.08) : Color.brandGray)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(isSelected ? Color.brandYellow : Color.clear, lineWidth: 1.5)
          )
      )
    }
  }

  private var planLabel: String {
    switch package.packageType {
    case .weekly: return "Weekly"
    case .monthly: return "Monthly"
    case .annual: return "Annual"
    case .lifetime: return "Lifetime"
    default: return package.storeProduct.localizedTitle
    }
  }

  private var planSubtitle: String? {
    switch package.packageType {
    case .weekly: return "7-day free trial included"
    case .annual: return "~€5/mo · save 50%"
    default: return nil
    }
  }

  private var billingPeriod: String {
    switch package.packageType {
    case .weekly: return "per week"
    case .monthly: return "per month"
    case .annual: return "per year"
    case .lifetime: return "one time"
    default: return ""
    }
  }
}

#Preview {
  PaywallView()
    .environmentObject(PaywallService(authService: AuthService()))
}
