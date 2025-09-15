import SwiftUI

struct CustomChallengesCard: View {
  @EnvironmentObject var challengeService: ChallengeService
  @State private var showingCustomEditor = false

  private var customChallenges: [Challenge] {
    challengeService.availableChallenges.filter { challenge in
      // Custom challenges don't have "preloaded_" prefix in their ID
      !(challenge.id?.hasPrefix("preloaded_") ?? true)
    }
  }

  var body: some View {
    VStack(spacing: 20) {
      // Header with Custom badge
      HStack {
        HStack(spacing: 8) {
          Image(systemName: "star.fill")
            .foregroundColor(.brandYellow)
            .font(.caption)
          Text("CUSTOM")
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
          Text("Your Custom Challenges")
            .title2Style()
            .foregroundColor(.white)
            .multilineTextAlignment(.center)

          Text(
            "\(customChallenges.count) challenge\(customChallenges.count == 1 ? "" : "s") created"
          )
          .bodyStyle()
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
        }

        // Custom challenges list (show up to 3)
        if !customChallenges.isEmpty {
          VStack(spacing: 8) {
            ForEach(Array(customChallenges.prefix(3)), id: \.id) { challenge in
              CustomChallengeRow(challenge: challenge)
            }

            if customChallenges.count > 3 {
              Text("+ \(customChallenges.count - 3) more")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
          }
        } else {
          Text("No custom challenges yet")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
        }

        // CTA Button
        Button(action: {
          showingCustomEditor = true
        }) {
          HStack(spacing: 8) {
            Image(systemName: "plus")
              .fontWeight(.semibold)
            Text("Create New Challenge")
              .fontWeight(.semibold)
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
    .sheet(isPresented: $showingCustomEditor) {
      CustomChallengeEditor()
    }
  }
}

struct CustomChallengeRow: View {
  let challenge: Challenge
  @EnvironmentObject var challengeService: ChallengeService
  @State private var isCompleting = false

  var body: some View {
    Button(action: completeChallenge) {
      HStack(spacing: 12) {
        Text(challenge.type.emoji)
          .font(.caption)

        VStack(alignment: .leading, spacing: 2) {
          Text(challenge.title)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .font(.subheadline)
            .lineLimit(1)

          Text(challenge.type.displayName)
            .font(.caption)
            .foregroundColor(.brandYellow)
        }

        Spacer()

        HStack(spacing: 2) {
          ForEach(1...3, id: \.self) { level in
            Image(systemName: "star.fill")
              .foregroundColor(level <= challenge.difficulty ? .brandYellow : .gray)
              .font(.caption2)
          }
        }

        if isCompleting {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .brandYellow))
            .scaleEffect(0.8)
        } else {
          Image(systemName: "checkmark.circle")
            .foregroundColor(.brandYellow)
            .font(.caption)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.brandInk.opacity(0.3))
      .cornerRadius(8)
    }
    .buttonStyle(PlainButtonStyle())
    .disabled(isCompleting)
  }

  private func completeChallenge() {
    guard !isCompleting else { return }

    isCompleting = true

    Task {
      do {
        let _ = try await challengeService.completeChallenge(challenge)
        await MainActor.run {
          isCompleting = false
          // Show success feedback
          let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
          impactFeedback.impactOccurred()
        }
      } catch {
        await MainActor.run {
          isCompleting = false
          print("Error completing custom challenge: \(error)")
        }
      }
    }
  }
}

#Preview {
  CustomChallengesCard()
    .environmentObject(ChallengeService(auth: AuthService()))
    .background(Color.brandInk)
}
