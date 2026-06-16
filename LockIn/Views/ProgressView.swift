import SwiftUI

struct ProgressView: View {
  @EnvironmentObject var moduleService: ModuleService
  @EnvironmentObject var authService: AuthService

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk.ignoresSafeArea()

        ScrollView {
          VStack(spacing: 20) {
            if let userModule = moduleService.activeModule {
              moduleArcCard(userModule)
              pathProgressCard
              statsGrid(userModule)
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

  // MARK: - Module Arc (hero card)

  private func moduleArcCard(_ userModule: UserModule) -> some View {
    VStack(spacing: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(userModule.moduleTitle)
            .font(Typography.headline)
            .foregroundColor(.white.opacity(0.5))
          Text("Day \(userModule.currentDay) of \(UserModule.durationDays)")
            .font(Typography.largeTitle)
            .foregroundColor(.white)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text("\(userModule.totalXPEarned)")
            .font(Typography.title2)
            .fontWeight(.bold)
            .foregroundColor(.brandYellow)
          Text("XP earned")
            .font(Typography.caption)
            .foregroundColor(.white.opacity(0.35))
        }
      }

      moduleArcBar(userModule)

      HStack {
        Text("\(userModule.completedDays.count) days completed")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.4))
        Spacer()
        Text("\(userModule.daysRemaining) to go")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.4))
      }
    }
    .padding(20)
    .background(Color.brandGray)
    .cornerRadius(20)
  }

  private func moduleArcBar(_ userModule: UserModule) -> some View {
    GeometryReader { geo in
      let total = UserModule.durationDays
      let dotSize: CGFloat = 6
      let spacing = (geo.size.width - dotSize) / CGFloat(max(total - 1, 1))

      ZStack(alignment: .leading) {
        Rectangle()
          .fill(Color.white.opacity(0.07))
          .frame(height: 2)
          .frame(maxWidth: .infinity)
          .padding(.top, dotSize / 2 - 1)

        Rectangle()
          .fill(Color.brandYellow)
          .frame(
            width: total > 1
              ? spacing * CGFloat(min(userModule.completedDays.count, total - 1))
              : 0,
            height: 2
          )
          .padding(.top, dotSize / 2 - 1)

        ForEach(1...total, id: \.self) { day in
          let completed = userModule.completedDays.contains(day)
          let isCurrent = day == userModule.currentDay

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

  // MARK: - Path Progress Card

  @ViewBuilder
  private var pathProgressCard: some View {
    if let path = moduleService.currentPath {
      VStack(alignment: .leading, spacing: 14) {
        Text("PATH PROGRESS")
          .font(Typography.caption2)
          .fontWeight(.semibold)
          .foregroundColor(.brandYellow.opacity(0.7))
          .tracking(1.5)

        HStack(spacing: 8) {
          ForEach(path.moduleIds, id: \.self) { moduleId in
            let isCompleted = moduleService.completedModuleIds.contains(moduleId)
            let isActive = moduleService.activeModule?.moduleId == moduleId
            let module = moduleService.availableModules.first { $0.id == moduleId }

            VStack(spacing: 6) {
              RoundedRectangle(cornerRadius: 4)
                .fill(
                  isCompleted ? Color.brandYellow
                    : isActive ? Color.brandYellow.opacity(0.3)
                    : Color.white.opacity(0.08)
                )
                .frame(height: 4)

              if let module {
                Text(module.title)
                  .font(Typography.caption2)
                  .foregroundColor(
                    isCompleted ? .white.opacity(0.6)
                      : isActive ? .white.opacity(0.4)
                      : .white.opacity(0.2)
                  )
                  .lineLimit(1)
              }
            }
          }
        }

        Text("\(moduleService.completedModuleIds.count) of \(path.moduleIds.count) modules done")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.35))
      }
      .padding(20)
      .background(Color.brandGray)
      .cornerRadius(16)
    }
  }

  // MARK: - Stats Grid

  private func statsGrid(_ userModule: UserModule) -> some View {
    HStack(spacing: 12) {
      statTile(
        icon: "flame.fill",
        color: .brandYellow,
        value: "\(authService.currentUser?.streakCount ?? 0)",
        label: "Day streak"
      )
      statTile(
        icon: "checkmark.circle.fill",
        color: .brandGreen,
        value: "\(userModule.completedDays.count)",
        label: "Days done"
      )
      statTile(
        icon: "moon.zzz.fill",
        color: .white.opacity(0.4),
        value: "\(userModule.missedDays.count)",
        label: "Days missed"
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
      Text("No active module")
        .font(Typography.headline)
        .foregroundColor(.white.opacity(0.4))
      Text("Enroll in a module to start tracking your progress.")
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
    .environmentObject(ModuleService(auth: auth))
}
