import FirebaseFirestore
import SwiftUI

struct CustomChallengeEditor: View {
  @EnvironmentObject var challengeService: ChallengeService
  @Environment(\.dismiss) private var dismiss
  @State private var challengeTitle = ""
  @State private var selectedType: ChallengeType = .wellness
  @State private var selectedDifficulty: Int = 1
  @State private var customAura: String = ""
  @State private var selectedDuration: Int = 0  // 0 = permanent, 7 = 1 week, 30 = 1 month, etc.
  @State private var isCreating = false
  @State private var showSuccess = false
  @State private var showSuccessMessage = false

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk
          .ignoresSafeArea()

        VStack(spacing: 0) {
          ScrollView {
            VStack(spacing: 24) {
              headerView
              formView
            }
            .padding()
          }

          createButtonView
        }
      }
      .navigationTitle("Custom Challenge")
      .navigationBarTitleDisplayMode(.inline)
      .preferredColorScheme(.dark)
      .alert("Challenge Created!", isPresented: $showSuccessMessage) {
        Button("OK") {
          dismiss()
        }
      } message: {
        Text("Your custom challenge has been added to the home page under \"Custom Challenges\"")
      }
    }
  }

  private var headerView: some View {
    VStack(spacing: 8) {
      Text("Create Custom Challenge")
        .titleStyle()
        .foregroundColor(.brandYellow)

      Text("Design your own daily challenge")
        .bodyStyle()
        .foregroundColor(.secondary)
    }
  }

  private var formView: some View {
    VStack(spacing: 20) {
      challengeTitleSection
      challengeTypeSection
      difficultySection
      auraSection
      durationSection
      previewSection
    }
    .padding()
    .background(Color.brandGray)
    .cornerRadius(20)
  }

  private var challengeTitleSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Challenge Title")
        .headlineStyle()
        .foregroundColor(.white)

      TextField("Enter your challenge...", text: $challengeTitle)
        .textFieldStyle(CustomTextFieldStyle())
    }
  }

  private var challengeTypeSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Type")
        .headlineStyle()
        .foregroundColor(.white)

      HStack(spacing: 8) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(ChallengeType.allCases, id: \.self) { type in
              typeButton(for: type)
            }
          }
          .padding(.horizontal, 4)
        }

        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundColor(.secondary)
          .opacity(0.7)
      }
    }
  }

  private var difficultySection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Difficulty")
        .headlineStyle()
        .foregroundColor(.white)

      HStack {
        ForEach(1...3, id: \.self) { level in
          Button(action: {
            selectedDifficulty = level
          }) {
            Text("\(level)")
              .fontWeight(.semibold)
              .foregroundColor(selectedDifficulty == level ? .brandInk : .white)
              .frame(width: 40, height: 40)
              .background(
                Circle()
                  .fill(selectedDifficulty == level ? Color.brandYellow : Color.brandGray)
              )
          }
        }

        Spacer()

        Text(difficultyText)
          .bodyStyle()
          .foregroundColor(.secondary)
      }
    }
  }

  private var auraSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Aura")
        .headlineStyle()
        .foregroundColor(.white)

      VStack(alignment: .leading, spacing: 8) {
        TextField("Enter Aura (10-50)", text: $customAura)
          .textFieldStyle(CustomTextFieldStyle())
          .keyboardType(.numberPad)

        Text("Choose Aura between 10-50 for fair friend comparisons")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }

  private var durationSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Duration")
        .headlineStyle()
        .foregroundColor(.white)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(durationOptions, id: \.value) { option in
            Button(action: {
              selectedDuration = option.value
            }) {
              Text(option.label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(selectedDuration == option.value ? .brandInk : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                  RoundedRectangle(cornerRadius: 16)
                    .fill(
                      selectedDuration == option.value ? Color.brandYellow : Color.brandGray
                    )
                )
            }
          }
        }
        .padding(.horizontal, 4)
      }
    }
  }

  private var previewSection: some View {
    Group {
      if !challengeTitle.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Preview")
            .headlineStyle()
            .foregroundColor(.white)

          ChallengePreviewCard(
            title: challengeTitle,
            type: selectedType,
            difficulty: selectedDifficulty
          )
        }
      }
    }
  }

  private var createButtonView: some View {
    VStack {
      Button(action: createChallenge) {
        HStack {
          if isCreating {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
              .scaleEffect(0.8)
          } else if showSuccess {
            Image(systemName: "checkmark.circle.fill")
          } else {
            Image(systemName: "plus.circle.fill")
          }

          Text(
            showSuccess ? "Challenge Created!" : isCreating ? "Creating..." : "Create Challenge"
          )
        }
        .foregroundColor(.brandInk)
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity)
        .padding()
        .background(showSuccess ? Color.green : Color.brandYellow)
        .cornerRadius(16)
      }
      .disabled(challengeTitle.isEmpty || isCreating || showSuccess)
      .opacity(challengeTitle.isEmpty ? 0.6 : 1.0)
      .padding(.horizontal)
      .padding(.bottom, 20)
    }
  }

  private func typeButton(for type: ChallengeType) -> some View {
    Button(action: {
      selectedType = type
    }) {
      HStack(spacing: 6) {
        Text(type.emoji)
          .font(.caption)
        Text(type.displayName)
          .font(.caption)
          .fontWeight(.medium)
      }
      .foregroundColor(selectedType == type ? .brandInk : .white)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(selectedType == type ? Color.brandYellow : Color.brandGray)
      )
    }
  }

  private var difficultyText: String {
    switch selectedDifficulty {
    case 1: return "Easy"
    case 2: return "Medium"
    case 3: return "Hard"
    default: return ""
    }
  }

  private var durationOptions: [(label: String, value: Int)] {
    [
      ("Permanent", 0),
      ("1 Week", 7),
      ("2 Weeks", 14),
      ("1 Month", 30),
      ("2 Months", 60),
      ("3 Months", 90),
      ("6 Months", 180),
      ("1 Year", 365),
    ]
  }

  private func createChallenge() {
    guard !challengeTitle.isEmpty else { return }

    // Validate Aura input
    let auraPoints: Int?
    if !customAura.isEmpty {
      guard let aura = Int(customAura), aura >= 10 && aura <= 50 else {
        // Show error for invalid Aura
        return
      }
      auraPoints = aura
    } else {
      auraPoints = nil
    }

    isCreating = true

    Task {
      do {
        let _ = try await challengeService.createCustomChallenge(
          title: challengeTitle,
          type: selectedType,
          difficulty: selectedDifficulty,
          customAura: auraPoints,
          durationDays: selectedDuration == 0 ? nil : selectedDuration
        )

        await MainActor.run {
          isCreating = false
          showSuccessMessage = true
        }
      } catch {
        await MainActor.run {
          isCreating = false
          print("Error creating custom challenge: \(error)")
        }
      }
    }
  }
}

struct ChallengePreviewCard: View {
  let title: String
  let type: ChallengeType
  let difficulty: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .title2Style()
        .foregroundColor(.white)

      HStack {
        Image(systemName: typeIcon)
          .foregroundColor(.brandYellow)

        Text(type.rawValue.capitalized)
          .headlineStyle()
          .foregroundColor(.brandYellow)

        Spacer()

        HStack(spacing: 4) {
          ForEach(1...3, id: \.self) { level in
            Image(systemName: "star.fill")
              .foregroundColor(level <= difficulty ? .brandYellow : .gray)
              .font(.caption)
          }
        }
      }
    }
    .padding()
    .background(Color.brandInk)
    .cornerRadius(12)
  }

  private var typeIcon: String {
    switch type {
    case .mindfulness: return "brain.head.profile"
    case .fitness: return "figure.run"
    case .learning: return "book"
    case .creativity: return "paintbrush"
    case .social: return "person.2"
    case .productivity: return "checkmark.circle"
    case .wellness: return "heart"
    case .gratitude: return "hands.sparkles"
    }
  }
}

struct CustomTextFieldStyle: TextFieldStyle {
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .padding()
      .background(Color.brandInk)
      .cornerRadius(12)
      .foregroundColor(.white)
  }
}

#Preview {
  CustomChallengeEditor()
    .environmentObject(PaywallService(authService: AuthService()))
}
