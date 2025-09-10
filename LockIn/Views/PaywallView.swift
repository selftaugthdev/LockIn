import RevenueCat
import SwiftUI

struct PaywallView: View {
  @EnvironmentObject var paywallService: PaywallService
  @Environment(\.dismiss) private var dismiss
  @State private var packages: [Package] = []
  @State private var selectedPackage: Package?
  @State private var showingCustomEditor = false

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 32) {
            // Header
            headerSection

            // Features
            featuresSection

            // Pricing
            pricingSection

            // CTA Button
            ctaSection

            // Footer
            footerSection
          }
          .padding()
        }
      }
      .navigationTitle("Unlock Pro")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Close") {
            dismiss()
          }
          .foregroundColor(.brandYellow)
        }
      }
      .preferredColorScheme(.dark)
    }
    .task {
      await loadPackages()
    }
    .sheet(isPresented: $showingCustomEditor) {
      CustomChallengeEditor()
    }
    .onChange(of: paywallService.isPro) { isPro in
      if isPro {
        // Auto-open custom editor after successful purchase
        dismiss()
        showingCustomEditor = true
      }
    }
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 16) {
      // Crown icon
      Image(systemName: "crown.fill")
        .font(.system(size: 60))
        .foregroundColor(.brandYellow)

      VStack(spacing: 8) {
        Text("Unlock Your Potential")
          .titleStyle()
          .foregroundColor(.white)
          .multilineTextAlignment(.center)

        Text("Create custom challenges that fit your unique goals and lifestyle")
          .bodyStyle()
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }
    }
  }

  // MARK: - Features Section

  private var featuresSection: some View {
    VStack(spacing: 20) {
      Text("What's Included")
        .headlineStyle()
        .foregroundColor(.white)

      VStack(spacing: 16) {
        ProFeatureRow(
          icon: "plus.circle.fill",
          title: "Custom Challenges",
          description: "Create unlimited personal challenges tailored to your goals"
        )

        ProFeatureRow(
          icon: "bell.fill",
          title: "Smart Reminders",
          description: "Get personalized notifications to keep you on track"
        )

        ProFeatureRow(
          icon: "paintbrush.fill",
          title: "Premium Themes",
          description: "Beautiful themes to personalize your experience"
        )

        ProFeatureRow(
          icon: "chart.bar.fill",
          title: "Advanced Analytics",
          description: "Detailed insights into your progress and patterns"
        )

        ProFeatureRow(
          icon: "infinity",
          title: "Unlimited Everything",
          description: "No limits on challenges, reminders, or customizations"
        )
      }
    }
    .padding(24)
    .background(Color.brandGray)
    .cornerRadius(20)
  }

  // MARK: - Pricing Section

  private var pricingSection: some View {
    VStack(spacing: 16) {
      Text("Choose Your Plan")
        .headlineStyle()
        .foregroundColor(.white)

      if packages.isEmpty {
        ProgressView()
          .progressViewStyle(CircularProgressViewStyle(tint: .brandYellow))
      } else {
        VStack(spacing: 12) {
          ForEach(packages, id: \.identifier) { package in
            PackageRow(
              package: package,
              isSelected: selectedPackage?.identifier == package.identifier,
              onTap: {
                selectedPackage = package
              }
            )
          }
        }
      }

      // Trial info
      HStack {
        Image(systemName: "checkmark.circle.fill")
          .foregroundColor(.brandGreen)
        Text(
          "3-day free trial, then \(selectedPackage?.storeProduct.localizedPriceString ?? "$3.99")/week"
        )
        .font(.caption)
        .foregroundColor(.secondary)
        Spacer()
      }
    }
  }

  // MARK: - CTA Section

  private var ctaSection: some View {
    VStack(spacing: 16) {
      Button(action: {
        if let package = selectedPackage {
          paywallService.purchase(package: package)
        }
      }) {
        HStack {
          if paywallService.isLoading {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
              .scaleEffect(0.8)
          } else {
            Text("Start Free Trial")
              .fontWeight(.semibold)
          }
        }
        .foregroundColor(.brandInk)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.brandYellow)
        .cornerRadius(16)
      }
      .disabled(paywallService.isLoading || selectedPackage == nil)

      Button("Restore Purchases") {
        paywallService.restorePurchases()
      }
      .foregroundColor(.brandYellow)
      .font(.subheadline)

      if let errorMessage = paywallService.errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundColor(.brandRed)
          .multilineTextAlignment(.center)
      }
    }
  }

  // MARK: - Footer Section

  private var footerSection: some View {
    VStack(spacing: 12) {
      Text("Cancel anytime. No commitment.")
        .font(.caption)
        .foregroundColor(.secondary)

      HStack(spacing: 20) {
        Button("Privacy Policy") {
          // TODO: Open privacy policy
        }
        .font(.caption)
        .foregroundColor(.brandYellow)

        Button("Terms of Service") {
          // TODO: Open terms of service
        }
        .font(.caption)
        .foregroundColor(.brandYellow)
      }
    }
  }

  // MARK: - Helper Methods

  private func loadPackages() async {
    do {
      let offerings = try await Purchases.shared.offerings()
      if let currentOffering = offerings.current {
        await MainActor.run {
          self.packages = currentOffering.availablePackages
          // Prefer weekly package, fallback to first available
          self.selectedPackage =
            currentOffering.availablePackages.first { $0.packageType == .weekly }
            ?? currentOffering.availablePackages.first
        }
      }
    } catch {
      print("Error loading packages: \(error)")
    }
  }
}

struct PackageRow: View {
  let package: Package
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(packageTypeLabel(for: package.packageType))
            .font(.title3)
            .fontWeight(.bold)
            .foregroundColor(.primary)

          Text(package.storeProduct.localizedDescription)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text(package.storeProduct.localizedPriceString)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.brandYellow)

          Text(package.storeProduct.localizedTitle)
            .font(.caption2)
            .foregroundColor(.secondary)
        }

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundColor(isSelected ? .brandYellow : .secondary)
      }
      .padding()
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? Color.brandYellow.opacity(0.1) : Color.brandGray)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(isSelected ? Color.brandYellow : Color.clear, lineWidth: 1)
          )
      )
    }
  }

  private func packageTypeLabel(for packageType: PackageType) -> String {
    switch packageType {
    case .annual:
      return "Yearly"
    case .monthly:
      return "Monthly"
    case .weekly:
      return "Weekly (With a 3-day Free Trial)"
    case .twoMonth:
      return "2 Months"
    case .threeMonth:
      return "3 Months"
    case .sixMonth:
      return "6 Months"
    case .lifetime:
      return "Lifetime"
    case .custom:
      return "Custom"
    case .unknown:
      return "Unknown"
    @unknown default:
      return "Unknown"
    }
  }
}

#Preview {
  PaywallView()
    .environmentObject(PaywallService(authService: AuthService()))
}
