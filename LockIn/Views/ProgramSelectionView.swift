import SwiftUI

struct ProgramSelectionView: View {
  @EnvironmentObject var moduleService: ModuleService
  @State private var selectedModule: Module?

  var body: some View {
    ZStack {
      Color.brandInk.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          headerSection
          moduleList
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 48)
      }
    }
    .sheet(item: $selectedModule) { module in
      ModuleDetailSheet(module: module)
    }
  }

  // MARK: - Header

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let path = moduleService.currentPath {
        Text(path.title.uppercased())
          .font(Typography.caption2)
          .fontWeight(.semibold)
          .foregroundColor(.brandYellow.opacity(0.7))
          .tracking(2)

        Text("Choose your\nnext module.")
          .font(Typography.largeTitle)
          .foregroundColor(.white)

        Text(path.subtitle)
          .font(Typography.subheadline)
          .foregroundColor(.white.opacity(0.4))
      } else {
        Text("Choose your\nnext module.")
          .font(Typography.largeTitle)
          .foregroundColor(.white)
      }
    }
  }

  // MARK: - Module List

  private var moduleList: some View {
    VStack(spacing: 12) {
      if moduleService.availableModules.isEmpty {
        Text("Loading modules...")
          .font(Typography.body)
          .foregroundColor(.white.opacity(0.4))
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.top, 60)
      } else {
        ForEach(orderedModules) { module in
          let isLocked = moduleService.isModuleLocked(module)
          let isCompleted = moduleService.completedModuleIds.contains(module.id)

          ModuleCard(
            module: module,
            isLocked: isLocked,
            isCompleted: isCompleted,
            isNext: isNextModule(module)
          )
          .onTapGesture {
            if !isLocked { selectedModule = module }
          }
        }
      }
    }
  }

  private var orderedModules: [Module] {
    guard let path = moduleService.currentPath else {
      return moduleService.availableModules.sorted { $0.order < $1.order }
    }
    return path.moduleIds.compactMap { id in
      moduleService.availableModules.first { $0.id == id }
    }
  }

  private func isNextModule(_ module: Module) -> Bool {
    !moduleService.isModuleLocked(module)
      && !moduleService.completedModuleIds.contains(module.id)
      && orderedModules.first(where: {
        !moduleService.isModuleLocked($0) && !moduleService.completedModuleIds.contains($0.id)
      })?.id == module.id
  }
}

// MARK: - Module Card

struct ModuleCard: View {
  let module: Module
  let isLocked: Bool
  let isCompleted: Bool
  let isNext: Bool

  var body: some View {
    HStack(spacing: 16) {
      // Order number
      Text(String(format: "%02d", module.order))
        .font(.system(size: 28, weight: .bold, design: .monospaced))
        .foregroundColor(numberColor)
        .frame(width: 44, alignment: .leading)

      // Content
      VStack(alignment: .leading, spacing: 6) {
        Text(module.title)
          .font(Typography.title3)
          .foregroundColor(isLocked ? .white.opacity(0.3) : .white)

        Text(module.tagline)
          .font(Typography.caption)
          .foregroundColor(isLocked ? .white.opacity(0.2) : .white.opacity(0.5))
          .lineLimit(2)

        HStack(spacing: 8) {
          Text(module.philosopher)
            .font(Typography.caption2)
            .foregroundColor(isLocked ? .white.opacity(0.2) : .brandYellow.opacity(0.7))
          Text("·")
            .foregroundColor(.white.opacity(0.2))
          Text("7 days")
            .font(Typography.caption2)
            .foregroundColor(isLocked ? .white.opacity(0.2) : .white.opacity(0.4))
          Text("·")
            .foregroundColor(.white.opacity(0.2))
          Text("\(module.totalXP) XP")
            .font(Typography.caption2)
            .foregroundColor(isLocked ? .white.opacity(0.2) : .white.opacity(0.4))
        }
      }

      Spacer()

      // State indicator
      stateIndicator
    }
    .padding(20)
    .background(cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(borderColor, lineWidth: 1)
    )
    .opacity(isLocked ? 0.6 : 1)
  }

  private var stateIndicator: some View {
    Group {
      if isCompleted {
        Image(systemName: "checkmark.circle.fill")
          .font(.title3)
          .foregroundColor(.brandGreen)
      } else if isLocked {
        Image(systemName: "lock.fill")
          .font(.subheadline)
          .foregroundColor(.white.opacity(0.25))
      } else if isNext {
        Image(systemName: "chevron.right")
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundColor(.brandYellow)
      } else {
        Image(systemName: "chevron.right")
          .font(.subheadline)
          .foregroundColor(.white.opacity(0.3))
      }
    }
  }

  private var numberColor: Color {
    if isCompleted { return .brandGreen }
    if isLocked { return .white.opacity(0.2) }
    if isNext { return .brandYellow }
    return .white.opacity(0.5)
  }

  private var cardBackground: Color {
    isNext ? Color.brandYellow.opacity(0.06) : Color.brandGray
  }

  private var borderColor: Color {
    if isCompleted { return .brandGreen.opacity(0.25) }
    if isNext { return .brandYellow.opacity(0.25) }
    return .white.opacity(0.07)
  }
}

// MARK: - Module Detail Sheet

struct ModuleDetailSheet: View {
  let module: Module
  @EnvironmentObject var moduleService: ModuleService
  @Environment(\.dismiss) var dismiss
  @State private var isEnrolling = false
  @State private var errorMessage: String?

  private var isCompleted: Bool {
    moduleService.completedModuleIds.contains(module.id)
  }

  var body: some View {
    ZStack {
      Color.brandInk.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 28) {

          // Badges
          HStack(spacing: 8) {
            Badge(text: "7 DAYS", color: .brandYellow)
            Badge(text: module.philosopher.uppercased(), color: .brandBlue)
            if module.isPremium {
              Badge(text: "PRO", color: .brandBlue)
            }
          }

          // Title + tagline
          VStack(alignment: .leading, spacing: 8) {
            Text(module.title)
              .font(Typography.largeTitle)
              .foregroundColor(.white)
            Text(module.tagline)
              .font(Typography.body)
              .foregroundColor(.white.opacity(0.5))
              .lineSpacing(3)
          }

          // Day breakdown
          VStack(alignment: .leading, spacing: 12) {
            Text("7 DAYS")
              .font(Typography.caption2)
              .fontWeight(.semibold)
              .foregroundColor(.brandYellow.opacity(0.7))
              .tracking(1.5)

            VStack(spacing: 0) {
              ForEach(module.days) { day in
                HStack(spacing: 14) {
                  Text("\(day.dayNumber)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.brandYellow.opacity(0.5))
                    .frame(width: 20, alignment: .center)

                  Text(day.challengeTitle)
                    .font(Typography.subheadline)
                    .foregroundColor(.white.opacity(0.75))

                  Spacer()
                }
                .padding(.vertical, 10)

                if day.dayNumber < module.days.count {
                  Divider().background(Color.white.opacity(0.06))
                }
              }
            }
            .padding(.horizontal, 16)
            .background(Color.brandGray)
            .cornerRadius(12)
          }

          // XP info
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Total XP")
                .font(Typography.caption)
                .foregroundColor(.white.opacity(0.4))
              Text("\(module.totalXP) XP")
                .font(Typography.title3)
                .foregroundColor(.brandYellow)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
              Text("Duration")
                .font(Typography.caption)
                .foregroundColor(.white.opacity(0.4))
              Text("7 days")
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
          if isCompleted {
            HStack(spacing: 10) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.brandGreen)
              Text("Module completed")
                .font(Typography.headline)
                .foregroundColor(.brandGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.brandGreen.opacity(0.1))
            .cornerRadius(12)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(Color.brandGreen.opacity(0.3), lineWidth: 1)
            )
          } else {
            Button {
              Task { await enroll() }
            } label: {
              HStack {
                if isEnrolling {
                  ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
                } else {
                  Text("Start \(module.title)")
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
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .preferredColorScheme(.dark)
  }

  private func enroll() async {
    isEnrolling = true
    errorMessage = nil
    do {
      let pathId = moduleService.currentPath?.id
      try await moduleService.enrollInModule(module, pathId: pathId)
      dismiss()
    } catch {
      errorMessage = "Failed to start module. Try again."
    }
    isEnrolling = false
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
    .environmentObject(ModuleService(auth: auth))
}
