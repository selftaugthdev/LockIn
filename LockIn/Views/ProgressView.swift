import SwiftUI

struct ProgressView: View {
  @EnvironmentObject var programService: ProgramService
  @EnvironmentObject var authService: AuthService

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk.ignoresSafeArea()

        ScrollView {
          VStack(spacing: 20) {
            if let program = programService.activeProgram {
              programArcCard(program)
              phaseCard(program)
              statsGrid(program)
            } else {
              emptyState
            }

            Spacer(minLength: 80)
          }
          .padding(.horizontal, 20)
          .padding(.top, 8)
        }
      }
      .navigationTitle("Progress")
      .navigationBarTitleDisplayMode(.large)
      .preferredColorScheme(.dark)
    }
  }

  // MARK: - Program Arc (hero card)

  private func programArcCard(_ program: UserProgram) -> some View {
    VStack(spacing: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(program.programTitle)
            .font(Typography.headline)
            .foregroundColor(.white.opacity(0.5))
          Text("Day \(program.currentDay) of \(program.programDurationDays)")
            .font(Typography.largeTitle)
            .foregroundColor(.white)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text("\(program.totalXPEarned)")
            .font(Typography.title2)
            .fontWeight(.bold)
            .foregroundColor(.brandYellow)
          Text("XP earned")
            .font(Typography.caption)
            .foregroundColor(.white.opacity(0.35))
        }
      }

      // Full program arc bar — dots for each day
      programArcBar(program)

      HStack {
        Text("\(program.completedDays.count) days completed")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.4))
        Spacer()
        Text("\(program.daysRemaining) to go")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.4))
      }
    }
    .padding(20)
    .background(Color.brandGray)
    .cornerRadius(20)
  }

  private func programArcBar(_ program: UserProgram) -> some View {
    GeometryReader { geo in
      let total = program.programDurationDays
      let dotSize: CGFloat = 6
      let spacing = (geo.size.width - dotSize) / CGFloat(max(total - 1, 1))

      ZStack(alignment: .leading) {
        // Track line
        Rectangle()
          .fill(Color.white.opacity(0.07))
          .frame(height: 2)
          .frame(maxWidth: .infinity)
          .padding(.top, dotSize / 2 - 1)

        // Filled line up to current
        Rectangle()
          .fill(Color.brandYellow)
          .frame(
            width: total > 1
              ? spacing * CGFloat(min(program.completedDays.count, total - 1))
              : 0,
            height: 2
          )
          .padding(.top, dotSize / 2 - 1)

        // Dots
        ForEach(1...total, id: \.self) { day in
          let completed = program.completedDays.contains(day)
          let isCurrent = day == program.currentDay

          Circle()
            .fill(completed ? Color.brandYellow : (isCurrent ? Color.white : Color.white.opacity(0.12)))
            .frame(width: isCurrent ? 10 : dotSize, height: isCurrent ? 10 : dotSize)
            .overlay(
              Circle()
                .stroke(isCurrent ? Color.brandYellow : Color.clear, lineWidth: 1.5)
                .frame(width: 14, height: 14)
            )
            .offset(x: spacing * CGFloat(day - 1) - (isCurrent ? 2 : 0))
        }
      }
    }
    .frame(height: 16)
  }

  // MARK: - Phase Card

  private func phaseCard(_ program: UserProgram) -> some View {
    guard let day = programService.todaysProgramDay else { return AnyView(EmptyView()) }

    return AnyView(
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("CURRENT PHASE")
            .font(Typography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.brandYellow.opacity(0.7))
            .tracking(1.5)
          Text(day.phase.displayName)
            .font(Typography.title2)
            .foregroundColor(.white)
          Text(day.phase.tagline)
            .font(Typography.caption)
            .foregroundColor(.white.opacity(0.4))
        }

        Spacer()

        // Phase position indicator
        VStack(spacing: 3) {
          ForEach(ProgramPhase.allCases, id: \.self) { phase in
            RoundedRectangle(cornerRadius: 2)
              .fill(phase == day.phase ? Color.brandYellow : Color.white.opacity(0.1))
              .frame(width: 4, height: phase == day.phase ? 24 : 12)
              .animation(.easeInOut(duration: 0.3), value: day.phase)
          }
        }
      }
      .padding(20)
      .background(Color.brandGray)
      .cornerRadius(16)
    )
  }

  // MARK: - Stats Grid

  private func statsGrid(_ program: UserProgram) -> some View {
    HStack(spacing: 12) {
      statTile(
        icon: "flame.fill",
        color: .brandYellow,
        value: "\(program.longestStreakInProgram)",
        label: "Best streak"
      )
      statTile(
        icon: "checkmark.circle.fill",
        color: .brandGreen,
        value: "\(program.completedDays.count)",
        label: "Days done"
      )
      statTile(
        icon: "arrow.counterclockwise",
        color: .brandRed,
        value: "\(program.recoveryDays.count)",
        label: "Recovery days"
      )
    }
  }

  private func statTile(icon: String, color: Color, value: String, label: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundColor(color)
      Text(value)
        .font(Typography.title2)
        .fontWeight(.bold)
        .foregroundColor(.white)
      Text(label)
        .font(Typography.caption2)
        .foregroundColor(.white.opacity(0.35))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 20)
    .background(Color.brandGray)
    .cornerRadius(16)
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "chart.line.uptrend.xyaxis")
        .font(.largeTitle)
        .foregroundColor(.white.opacity(0.15))
      Text("No active program")
        .font(Typography.headline)
        .foregroundColor(.white.opacity(0.4))
      Text("Enroll in a program to start tracking your progress.")
        .font(Typography.subheadline)
        .foregroundColor(.white.opacity(0.25))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 250)
  }
}

#Preview {
  let auth = AuthService()
  ProgressView()
    .environmentObject(auth)
    .environmentObject(ProgramService(auth: auth))
}
