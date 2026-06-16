import SwiftUI

struct LibraryView: View {
  @EnvironmentObject var moduleService: ModuleService
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var paywallService: PaywallService
  @ObservedObject private var advisor = AdvisorService.shared

  @State private var selectedTab: LibraryTab = .mentalEdge
  @State private var scenarios: [Scenario] = []
  @State private var selectedScenario: Scenario?

  enum LibraryTab: String, CaseIterable {
    case mentalEdge = "Mental Edge"
    case scenarios = "Scenarios"
    case saved = "Saved"
  }

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk.ignoresSafeArea()

        if paywallService.isPro {
          VStack(spacing: 0) {
            tabPicker
              .padding(.horizontal, 20)
              .padding(.top, 8)

            ScrollView {
              VStack(spacing: 16) {
                switch selectedTab {
                case .mentalEdge:
                  mentalEdgeSection
                case .scenarios:
                  scenariosSection
                case .saved:
                  savedSection
                }
                Spacer(minLength: 80)
              }
              .padding(.horizontal, 20)
              .padding(.top, 16)
            }
          }
        } else {
          lockedState
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Library")
            .font(Typography.headline)
            .foregroundColor(.brandYellow)
        }
      }
      .preferredColorScheme(.dark)
      .onAppear {
        scenarios = Scenario.loadAll()
      }
      .task {
        if paywallService.isPro, let uid = authService.uid {
          await advisor.loadSavedSessions(userId: uid)
        }
      }
      .sheet(item: $selectedScenario) { scenario in
        ScenarioDetailSheet(scenario: scenario)
          .environmentObject(authService)
          .environmentObject(paywallService)
      }
      .fullScreenCover(isPresented: $paywallService.shouldShowPaywall) {
        PaywallView()
      }
    }
  }

  // MARK: - Tab Picker

  private var tabPicker: some View {
    HStack(spacing: 0) {
      ForEach(LibraryTab.allCases, id: \.self) { tab in
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            selectedTab = tab
          }
        } label: {
          Text(tab.rawValue)
            .font(Typography.subheadline)
            .fontWeight(selectedTab == tab ? .semibold : .regular)
            .foregroundColor(selectedTab == tab ? .brandYellow : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .background(
          VStack {
            Spacer()
            if selectedTab == tab {
              Rectangle()
                .fill(Color.brandYellow)
                .frame(height: 2)
            } else {
              Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            }
          }
        )
      }
    }
  }

  // MARK: - Mental Edge Section

  private var mentalEdgeSection: some View {
    let grouped = completedDaysByModule

    return Group {
      if grouped.isEmpty {
        emptyMentalEdge
      } else {
        let totalDays = grouped.reduce(0) { $0 + $1.days.count }
        VStack(alignment: .leading, spacing: 20) {
          Text("\(totalDays) insight\(totalDays == 1 ? "" : "s") unlocked")
            .font(Typography.caption)
            .foregroundColor(.white.opacity(0.35))

          ForEach(grouped, id: \.module.id) { item in
            moduleSection(module: item.module, days: item.days)
          }
        }
      }
    }
  }

  private func moduleSection(module: Module, days: [ModuleDay]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Text(module.title.uppercased())
          .font(Typography.caption2)
          .fontWeight(.semibold)
          .foregroundColor(.brandYellow.opacity(0.7))
          .tracking(1.5)
        Rectangle()
          .fill(Color.white.opacity(0.08))
          .frame(height: 1)
      }

      ForEach(days) { day in
        MentalEdgeLibraryCard(day: day)
      }
    }
  }

  private var completedDaysByModule: [(module: Module, days: [ModuleDay])] {
    var result: [(module: Module, days: [ModuleDay])] = []

    for moduleId in moduleService.completedModuleIds {
      guard let module = moduleService.availableModules.first(where: { $0.id == moduleId }) else { continue }
      result.append((module: module, days: module.days))
    }

    if let userModule = moduleService.activeModule,
       !moduleService.completedModuleIds.contains(userModule.moduleId),
       let module = moduleService.activeModuleContent {
      let completed = module.days.filter { userModule.completedDays.contains($0.dayNumber) }
      if !completed.isEmpty {
        result.append((module: module, days: completed))
      }
    }

    return result
  }

  private var emptyMentalEdge: some View {
    VStack(spacing: 12) {
      Image(systemName: "book.closed")
        .font(.largeTitle)
        .foregroundColor(.white.opacity(0.15))
      Text("No insights yet")
        .font(Typography.headline)
        .foregroundColor(.white.opacity(0.4))
      Text("Complete days to unlock Mental Edge insights from history's sharpest minds.")
        .font(Typography.subheadline)
        .foregroundColor(.white.opacity(0.25))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 200)
  }

  // MARK: - Scenarios Section

  private var scenariosSection: some View {
    Group {
      if scenarios.isEmpty {
        emptyScenarios
      } else {
        VStack(alignment: .leading, spacing: 20) {
          Text("\(scenarios.count) situations. Pick one. Get clarity.")
            .font(Typography.caption)
            .foregroundColor(.white.opacity(0.35))

          ForEach(ScenarioCategory.allCases, id: \.self) { category in
            let categoryScenarios = scenarios.filter { $0.category == category }
            if !categoryScenarios.isEmpty {
              scenarioCategorySection(category: category, scenarios: categoryScenarios)
            }
          }
        }
      }
    }
  }

  private func scenarioCategorySection(category: ScenarioCategory, scenarios: [Scenario]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Text(category.rawValue.uppercased())
          .font(Typography.caption2)
          .fontWeight(.semibold)
          .foregroundColor(.brandYellow.opacity(0.7))
          .tracking(1.5)
        Rectangle()
          .fill(Color.white.opacity(0.08))
          .frame(height: 1)
      }

      VStack(spacing: 10) {
        ForEach(scenarios) { scenario in
          ScenarioCard(scenario: scenario)
            .onTapGesture { selectedScenario = scenario }
        }
      }
    }
  }

  private var emptyScenarios: some View {
    VStack(spacing: 12) {
      Image(systemName: "text.bubble")
        .font(.largeTitle)
        .foregroundColor(.white.opacity(0.15))
      Text("No scenarios loaded")
        .font(Typography.headline)
        .foregroundColor(.white.opacity(0.4))
    }
    .frame(maxWidth: .infinity, minHeight: 200)
  }

  // MARK: - Saved Section

  private var savedSection: some View {
    Group {
      if advisor.savedSessions.isEmpty {
        emptySaved
      } else {
        VStack(spacing: 12) {
          ForEach(advisor.savedSessions) { session in
            SavedSessionCard(session: session)
              .environmentObject(authService)
          }
        }
      }
    }
  }

  private var emptySaved: some View {
    VStack(spacing: 12) {
      Image(systemName: "bookmark")
        .font(.largeTitle)
        .foregroundColor(.white.opacity(0.15))
      Text("No saved sessions")
        .font(Typography.headline)
        .foregroundColor(.white.opacity(0.4))
      Text("Save responses from The Advisor and they'll appear here.")
        .font(Typography.subheadline)
        .foregroundColor(.white.opacity(0.25))
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 200)
  }

  // MARK: - Locked State

  private var lockedState: some View {
    VStack(spacing: 24) {
      Spacer()

      VStack(spacing: 16) {
        Image(systemName: "books.vertical.fill")
          .font(.system(size: 48))
          .foregroundColor(.brandYellow.opacity(0.6))

        Text("The Library")
          .font(Typography.title2)
          .foregroundColor(.white)

        Text("Mental Edge insights, pre-built scenarios with your philosopher of choice, and all your saved Advisor sessions — in one place.")
          .font(Typography.body)
          .foregroundColor(.white.opacity(0.5))
          .multilineTextAlignment(.center)
          .lineSpacing(4)
          .padding(.horizontal, 24)
      }

      Button {
        paywallService.safeShowPaywall()
      } label: {
        Text("Go Pro")
          .font(Typography.headline)
          .foregroundColor(.brandInk)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 18)
          .background(Color.brandYellow)
          .cornerRadius(14)
      }
      .padding(.horizontal, 24)

      Spacer()
    }
  }
}

// MARK: - Scenario Card

struct ScenarioCard: View {
  let scenario: Scenario

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text(scenario.philosopher.displayName.uppercased())
          .font(Typography.caption2)
          .fontWeight(.semibold)
          .foregroundColor(.brandYellow.opacity(0.7))
          .tracking(1)

        Text(scenario.title)
          .font(Typography.subheadline)
          .fontWeight(.semibold)
          .foregroundColor(.white)

        Text(scenario.hook)
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.45))
          .lineSpacing(2)
          .lineLimit(2)
      }

      Spacer()

      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundColor(.white.opacity(0.25))
        .padding(.top, 4)
    }
    .padding(16)
    .background(Color.brandGray)
    .cornerRadius(14)
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.white.opacity(0.07), lineWidth: 1)
    )
  }
}

// MARK: - Scenario Detail Sheet

struct ScenarioDetailSheet: View {
  let scenario: Scenario
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var paywallService: PaywallService
  @Environment(\.dismiss) private var dismiss
  @State private var showingAdvisor = false

  var body: some View {
    ZStack {
      Color.brandInk.ignoresSafeArea()

      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          // Badges
          HStack(spacing: 8) {
            Badge(text: scenario.category.rawValue.uppercased(), color: .brandYellow)
            Badge(text: scenario.philosopher.displayName.uppercased(), color: .brandBlue)
          }

          // Title + hook
          VStack(alignment: .leading, spacing: 8) {
            Text(scenario.title)
              .font(Typography.largeTitle)
              .foregroundColor(.white)
            Text(scenario.hook)
              .font(Typography.body)
              .foregroundColor(.white.opacity(0.5))
              .lineSpacing(3)
          }

          // Philosopher context
          HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
              Text(scenario.philosopher.displayName)
                .font(Typography.headline)
                .foregroundColor(.white)
              Text(scenario.philosopher.tagline)
                .font(Typography.caption)
                .foregroundColor(.brandYellow.opacity(0.7))
            }
            Spacer()
            Text(scenario.philosopher.era)
              .font(Typography.caption2)
              .foregroundColor(.white.opacity(0.3))
          }
          .padding(16)
          .background(Color.brandGray)
          .cornerRadius(12)

          // Opening prompt preview
          VStack(alignment: .leading, spacing: 10) {
            Text("YOUR OPENING SITUATION")
              .font(Typography.caption2)
              .fontWeight(.semibold)
              .foregroundColor(.white.opacity(0.4))
              .tracking(1.5)

            Text(scenario.openingPrompt)
              .font(Typography.subheadline)
              .foregroundColor(.white.opacity(0.6))
              .lineSpacing(4)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(16)
          .background(Color.brandGray)
          .cornerRadius(12)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.white.opacity(0.06), lineWidth: 1)
          )

          Text("You can edit the situation before sending.")
            .font(Typography.caption)
            .foregroundColor(.white.opacity(0.25))

          // CTA
          Button {
            showingAdvisor = true
          } label: {
            Text("Ask \(scenario.philosopher.displayName)")
              .font(Typography.headline)
              .foregroundColor(.brandInk)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .background(Color.brandYellow)
              .cornerRadius(12)
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
    .preferredColorScheme(.dark)
    .fullScreenCover(isPresented: $showingAdvisor) {
      AdvisorView(initialFigure: scenario.philosopher, initialSituation: scenario.openingPrompt)
        .environmentObject(authService)
        .environmentObject(paywallService)
    }
  }
}

// MARK: - Mental Edge Library Card

struct MentalEdgeLibraryCard: View {
  let day: ModuleDay
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded.toggle()
        }
      } label: {
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
              Text("Day \(day.dayNumber)")
                .font(Typography.caption2)
                .foregroundColor(.white.opacity(0.3))
              Text("·")
                .foregroundColor(.white.opacity(0.2))
              Text(day.mentalEdge.figure)
                .font(Typography.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.brandYellow.opacity(0.7))
            }
            Text(day.challengeTitle)
              .font(Typography.subheadline)
              .fontWeight(.medium)
              .foregroundColor(.white)
              .multilineTextAlignment(.leading)
          }
          Spacer()
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption)
            .foregroundColor(.white.opacity(0.3))
        }
        .padding(16)
      }

      if isExpanded {
        Divider()
          .background(Color.white.opacity(0.06))

        VStack(alignment: .leading, spacing: 10) {
          HStack(spacing: 6) {
            Text(day.mentalEdge.figure)
              .font(Typography.caption)
              .fontWeight(.semibold)
              .foregroundColor(.brandYellow)
            Text("—")
              .foregroundColor(.white.opacity(0.2))
            Text(day.mentalEdge.sourceWork)
              .font(Typography.caption)
              .foregroundColor(.white.opacity(0.45))
            Text(day.mentalEdge.year)
              .font(Typography.caption)
              .foregroundColor(.white.opacity(0.3))
          }

          Text(day.mentalEdge.content)
            .font(Typography.body)
            .foregroundColor(.white.opacity(0.7))
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
      }
    }
    .background(Color.brandGray)
    .cornerRadius(14)
  }
}

#Preview {
  let auth = AuthService()
  LibraryView()
    .environmentObject(auth)
    .environmentObject(ModuleService(auth: auth))
    .environmentObject(PaywallService(authService: auth))
}
