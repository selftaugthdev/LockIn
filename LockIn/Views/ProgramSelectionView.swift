import SwiftUI

struct ProgramSelectionView: View {
  @EnvironmentObject var programService: ProgramService
  @State private var selectedProgram: Program?

  var body: some View {
    ZStack {
      Color.brandInk.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 32) {

          // Header
          VStack(alignment: .leading, spacing: 8) {
            Text("Choose Your Program")
              .font(Typography.largeTitle)
              .foregroundColor(.white)

            Text("Commit to one. See it through.")
              .font(Typography.body)
              .foregroundColor(.white.opacity(0.5))
          }
          .padding(.top, 8)

          // Program cards
          VStack(spacing: 16) {
            ForEach(programService.availablePrograms) { program in
              ProgramCard(program: program)
                .onTapGesture {
                  selectedProgram = program
                }
            }
          }

          if programService.availablePrograms.isEmpty {
            Text("No programs available.")
              .font(Typography.body)
              .foregroundColor(.white.opacity(0.4))
              .frame(maxWidth: .infinity, alignment: .center)
              .padding(.top, 60)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
      }
    }
    .sheet(item: $selectedProgram) { program in
      ProgramDetailSheet(program: program)
    }
  }
}

// MARK: - Program Card

struct ProgramCard: View {
  let program: Program

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {

      // Top row — duration + difficulty badges
      HStack(spacing: 8) {
        Badge(text: "\(program.durationDays) Days", color: .brandYellow)
        Badge(text: program.difficulty.displayName, color: difficultyColor)
        if program.isPremium {
          Badge(text: "PRO", color: .brandBlue)
        }
        Spacer()
        Text("\(program.totalXP) XP")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.4))
      }

      // Title + subtitle
      VStack(alignment: .leading, spacing: 4) {
        Text(program.title)
          .font(Typography.title2)
          .foregroundColor(.white)

        Text(program.subtitle)
          .font(Typography.subheadline)
          .foregroundColor(.white.opacity(0.55))
          .lineLimit(2)
      }

      // Phase indicators
      HStack(spacing: 4) {
        ForEach([ProgramPhase.foundation, .build, .push, .peak], id: \.self) { phase in
          Text(phase.displayName)
            .font(Typography.caption2)
            .foregroundColor(.white.opacity(0.35))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .cornerRadius(4)
        }
        Spacer()
      }
    }
    .padding(20)
    .background(Color.brandGray)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.07), lineWidth: 1)
    )
  }

  private var difficultyColor: Color {
    switch program.difficulty {
    case .beginner: return .brandGreen
    case .intermediate: return .brandYellow
    case .hard: return .brandRed
    }
  }
}

// MARK: - Program Detail Sheet

struct ProgramDetailSheet: View {
  let program: Program
  @EnvironmentObject var programService: ProgramService
  @Environment(\.dismiss) var dismiss
  @State private var isEnrolling = false
  @State private var errorMessage: String?

  var body: some View {
    ZStack {
      Color.brandInk.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 28) {

          // Badges
          HStack(spacing: 8) {
            Badge(text: "\(program.durationDays) Days", color: .brandYellow)
            Badge(text: program.difficulty.displayName, color: difficultyColor)
            if program.isPremium {
              Badge(text: "PRO", color: .brandBlue)
            }
          }

          // Title + description
          VStack(alignment: .leading, spacing: 12) {
            Text(program.title)
              .font(Typography.largeTitle)
              .foregroundColor(.white)

            Text(program.description)
              .font(Typography.body)
              .foregroundColor(.white.opacity(0.6))
              .lineSpacing(4)
          }

          // Phase breakdown
          VStack(alignment: .leading, spacing: 12) {
            Text("How it works")
              .font(Typography.headline)
              .foregroundColor(.white)

            ForEach([ProgramPhase.foundation, .build, .push, .peak], id: \.self) { phase in
              PhaseRow(phase: phase, program: program)
            }
          }

          // XP info
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Total XP")
                .font(Typography.caption)
                .foregroundColor(.white.opacity(0.4))
              Text("\(program.totalXP) XP")
                .font(Typography.title3)
                .foregroundColor(.brandYellow)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
              Text("Challenges")
                .font(Typography.caption)
                .foregroundColor(.white.opacity(0.4))
              Text("\(program.days.count)")
                .font(Typography.title3)
                .foregroundColor(.white)
            }
          }
          .padding(16)
          .background(Color.brandGray)
          .cornerRadius(12)

          if let error = errorMessage {
            Text(error)
              .font(Typography.footnote)
              .foregroundColor(.brandRed)
          }

          // CTA
          Button {
            Task { await enroll() }
          } label: {
            HStack {
              if isEnrolling {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
              } else {
                Text("I'm ready. Start program.")
                  .font(Typography.headline)
                  .foregroundColor(.brandInk)
              }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.brandYellow)
            .cornerRadius(12)
          }
          .disabled(isEnrolling)
          .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }

  private var difficultyColor: Color {
    switch program.difficulty {
    case .beginner: return .brandGreen
    case .intermediate: return .brandYellow
    case .hard: return .brandRed
    }
  }

  private func enroll() async {
    isEnrolling = true
    errorMessage = nil
    do {
      try await programService.enrollInProgram(program)
      dismiss()
    } catch {
      errorMessage = "Failed to start program. Try again."
    }
    isEnrolling = false
  }
}

// MARK: - Phase Row

struct PhaseRow: View {
  let phase: ProgramPhase
  let program: Program

  var body: some View {
    let daysInPhase = program.days.filter { $0.phase == phase }

    HStack(alignment: .top, spacing: 12) {
      Circle()
        .fill(Color.brandYellow.opacity(0.2))
        .frame(width: 8, height: 8)
        .padding(.top, 6)

      VStack(alignment: .leading, spacing: 2) {
        Text(phase.displayName)
          .font(Typography.subheadline)
          .foregroundColor(.white)
        Text(phase.tagline)
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.45))
        Text("\(daysInPhase.count) days")
          .font(Typography.caption2)
          .foregroundColor(.white.opacity(0.3))
      }
    }
  }
}

// MARK: - Reusable Badge

struct Badge: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(Typography.caption)
      .fontWeight(.semibold)
      .foregroundColor(color)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(color.opacity(0.12))
      .cornerRadius(6)
  }
}

#Preview {
  let auth = AuthService()
  ProgramSelectionView()
    .environmentObject(ProgramService(auth: auth))
}
