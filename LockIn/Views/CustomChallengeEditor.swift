import FirebaseFirestore
import SwiftUI

struct CustomChallengeEditor: View {
  // @EnvironmentObject var paywallService: PaywallService
  @State private var challengeTitle = ""
  @State private var selectedType: ChallengeType = .wellness
  @State private var selectedDifficulty: Int = 1

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk
          .ignoresSafeArea()

        VStack(spacing: 24) {
          // Header
          VStack(spacing: 8) {
            Text("Create Custom Challenge")
              .titleStyle()
              .foregroundColor(.brandYellow)

            Text("Design your own daily challenge")
              .bodyStyle()
              .foregroundColor(.secondary)
          }

          // Form
          VStack(spacing: 20) {
            // Challenge Title
            VStack(alignment: .leading, spacing: 8) {
              Text("Challenge Title")
                .headlineStyle()
                .foregroundColor(.white)

              TextField("Enter your challenge...", text: $challengeTitle)
                .textFieldStyle(CustomTextFieldStyle())
            }

            // Challenge Type
            VStack(alignment: .leading, spacing: 8) {
              Text("Type")
                .headlineStyle()
                .foregroundColor(.white)

              Picker("Type", selection: $selectedType) {
                ForEach(ChallengeType.allCases, id: \.self) { type in
                  Text(type.rawValue.capitalized)
                    .tag(type)
                }
              }
              .pickerStyle(SegmentedPickerStyle())
            }

            // Difficulty
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

            // Preview
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
          .padding()
          .background(Color.brandGray)
          .cornerRadius(20)

          // Create Button
          Button(action: createChallenge) {
            HStack {
              Image(systemName: "plus.circle.fill")
              Text("Create Challenge")
            }
            .foregroundColor(.brandInk)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brandYellow)
            .cornerRadius(16)
          }
          .disabled(challengeTitle.isEmpty)
          .opacity(challengeTitle.isEmpty ? 0.6 : 1.0)

          Spacer()
        }
        .padding()
      }
      .navigationTitle("Custom Challenge")
      .navigationBarTitleDisplayMode(.inline)
      .preferredColorScheme(.dark)
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

  private func createChallenge() {
    // This is where you'd save the custom challenge
    // For now, just show a success message
    print("Creating custom challenge: \(challengeTitle)")
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
