import SwiftUI

struct ProCard: View {
  @EnvironmentObject var paywallService: PaywallService
  @State private var showingPaywall = false

  var body: some View {
    VStack(spacing: 20) {
      // Header with Pro badge
      HStack {
        HStack(spacing: 8) {
          Image(systemName: "crown.fill")
            .foregroundColor(.brandYellow)
            .font(.caption)
          Text("PRO")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.brandYellow)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.brandYellow.opacity(0.2))
        .cornerRadius(12)

        Spacer()
      }

      // Main content
      VStack(spacing: 16) {
        // Title and subtitle
        VStack(spacing: 8) {
          Text("Create your own Lock In")
            .title2Style()
            .foregroundColor(.white)
            .multilineTextAlignment(.center)

          Text("Make challenges that fit your goals")
            .bodyStyle()
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }

        // Features list
        VStack(spacing: 12) {
          ProFeatureRow(
            icon: "plus.circle.fill",
            title: "Custom challenges",
            description: "Design your own daily challenges"
          )

          ProFeatureRow(
            icon: "bell.fill",
            title: "Extra reminders",
            description: "Never miss your custom challenges"
          )

          ProFeatureRow(
            icon: "paintbrush.fill",
            title: "Themes",
            description: "Personalize your experience"
          )
        }

        // CTA Button
        Button(action: {
          showingPaywall = true
        }) {
          HStack(spacing: 8) {
            Text("Unlock Pro")
              .fontWeight(.semibold)

            // 3-day free trial badge
            Text("3-day free trial")
              .font(.caption)
              .fontWeight(.medium)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.white.opacity(0.2))
              .cornerRadius(8)
          }
          .foregroundColor(.brandInk)
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.brandYellow)
          .cornerRadius(16)
        }
      }
    }
    .padding(24)
    .background(
      LinearGradient(
        colors: [Color.brandGray, Color.brandGray.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .cornerRadius(20)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(
          LinearGradient(
            colors: [Color.brandYellow.opacity(0.6), Color.brandYellow.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
    )
    .sheet(isPresented: $showingPaywall) {
      PaywallView()
    }
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
        .frame(width: 20)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .fontWeight(.semibold)
          .foregroundColor(.white)
          .font(.subheadline)

        Text(description)
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()
    }
  }
}

#Preview {
  ProCard()
    .environmentObject(PaywallService(authService: AuthService()))
    .background(Color.brandInk)
}
