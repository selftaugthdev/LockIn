import SwiftUI

struct CustomChallengesCard: View {
  @EnvironmentObject var challengeService: ChallengeService
  @State private var showingCustomEditor = false
  @State private var hideCompletedChallenges = false
  @State private var showingAllChallenges = false

  private var customChallenges: [Challenge] {
    let allCustom = challengeService.availableChallenges.filter { challenge in
      // Custom challenges don't have "preloaded_" prefix in their ID
      !(challenge.id?.hasPrefix("preloaded_") ?? true)
    }

    if hideCompletedChallenges {
      return allCustom.filter { challenge in
        // Filter out completed challenges
        return !isChallengeCompleted(challenge)
      }
    }

    return allCustom
  }

  private func isChallengeCompleted(_ challenge: Challenge) -> Bool {
    let cid =
      (challenge.id?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
        $0.isEmpty ? nil : $0
      }
      ?? challenge.title
      .lowercased()
      .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

    return challengeService.completedChallengesToday.contains(cid)
  }

  var body: some View {
    VStack(spacing: 20) {
      // Header with Custom badge and toggle
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

        // Toggle to hide completed challenges
        Button(action: {
          hideCompletedChallenges.toggle()
        }) {
          HStack(spacing: 4) {
            Image(systemName: hideCompletedChallenges ? "eye.slash.fill" : "eye.fill")
              .font(.caption)
            Text(hideCompletedChallenges ? "Show All" : "Hide Done")
              .font(.caption)
              .fontWeight(.medium)
          }
          .foregroundColor(.brandYellow)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.brandYellow.opacity(0.1))
          .cornerRadius(8)
        }
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

        // Custom challenges list
        if !customChallenges.isEmpty {
          VStack(spacing: 8) {
            let challengesToShow =
              showingAllChallenges ? customChallenges : Array(customChallenges.prefix(3))

            ForEach(challengesToShow, id: \.id) { challenge in
              CustomChallengeRow(challenge: challenge)
            }

            if customChallenges.count > 3 {
              Button(action: {
                showingAllChallenges.toggle()
              }) {
                HStack(spacing: 4) {
                  Image(systemName: showingAllChallenges ? "chevron.up" : "chevron.down")
                    .font(.caption)
                  Text(showingAllChallenges ? "Show Less" : "+ \(customChallenges.count - 3) more")
                    .font(.caption)
                    .fontWeight(.medium)
                }
                .foregroundColor(.brandYellow)
                .padding(.top, 4)
              }
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

  private var isCompleted: Bool {
    let cid =
      (challenge.id?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
        $0.isEmpty ? nil : $0
      }
      ?? challenge.title
      .lowercased()
      .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

    return challengeService.completedChallengesToday.contains(cid)
  }

  var body: some View {
    Button(action: completeChallenge) {
      HStack(spacing: 12) {
        Text(challenge.type.emoji)
          .font(.caption)

        VStack(alignment: .leading, spacing: 2) {
          Text(challenge.title)
            .fontWeight(.medium)
            .foregroundColor(isCompleted ? .secondary : .white)
            .font(.subheadline)
            .lineLimit(1)

          Text(challenge.type.displayName)
            .font(.caption)
            .foregroundColor(isCompleted ? .secondary : .brandYellow)
        }

        Spacer()

        HStack(spacing: 2) {
          ForEach(1...3, id: \.self) { level in
            Image(systemName: "star.fill")
              .foregroundColor(
                level <= challenge.difficulty ? (isCompleted ? .secondary : .brandYellow) : .gray
              )
              .font(.caption2)
          }
        }

        if isCompleting {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .brandYellow))
            .scaleEffect(0.8)
            .frame(width: 16, height: 16)
        } else {
          Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
            .foregroundColor(isCompleted ? .brandGreen : .brandYellow)
            .font(.caption)
            .frame(width: 16, height: 16)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(isCompleted ? Color.brandInk.opacity(0.1) : Color.brandInk.opacity(0.3))
      .cornerRadius(8)
    }
    .buttonStyle(PlainButtonStyle())
    .disabled(isCompleting || isCompleted)
  }

  private func completeChallenge() {
    // For custom challenges, show a confirmation dialog instead of immediately completing
    let alert = UIAlertController(
      title: "Complete Challenge",
      message:
        "Are you sure you want to mark '\(challenge.title)' as completed? This action cannot be undone.",
      preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(
      UIAlertAction(title: "Complete", style: .default) { _ in
        self.performCompletion()
      })

    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first
    {
      window.rootViewController?.present(alert, animated: true)
    }
  }

  private func performCompletion() {
    guard !isCompleting else { return }

    isCompleting = true

    Task {
      do {
        let _ = try await challengeService.completeChallenge(challenge)

        // Wait a moment for Cloud Function to process
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Refresh user data to get updated aura
        // We'll let the DailyChallengeView handle the user data refresh
        // since it has access to the AuthService

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

          // Show error alert to user
          DispatchQueue.main.async {
            let alert = UIAlertController(
              title: "Completion Failed",
              message: getErrorMessage(for: error),
              preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first
            {
              window.rootViewController?.present(alert, animated: true)
            }
          }
        }
      }
    }
  }

  private func getErrorMessage(for error: Error) -> String {
    // Check if it's a permission denied error (Firestore rules violation)
    if let nsError = error as NSError? {
      if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 7 {
        return "Already completed this challenge today. Pick another or come back tomorrow."
      }
    }

    // Default error message
    return "Unable to complete challenge. Please check your internet connection and try again."
  }
}

#Preview {
  CustomChallengesCard()
    .environmentObject(ChallengeService(auth: AuthService()))
    .background(Color.brandInk)
}
