import SwiftUI

struct LibraryView: View {
  @EnvironmentObject var programService: ProgramService
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var paywallService: PaywallService
  @ObservedObject private var advisor = AdvisorService.shared

  @State private var selectedTab: LibraryTab = .mentalEdge

  enum LibraryTab: String, CaseIterable {
    case mentalEdge = "Mental Edge"
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
      .task {
        if paywallService.isPro, let uid = authService.uid {
          await advisor.loadSavedSessions(userId: uid)
        }
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
    let completedDays = completedDaysWithEdges

    return Group {
      if completedDays.isEmpty {
        emptyMentalEdge
      } else {
        VStack(alignment: .leading, spacing: 20) {
          Text("\(completedDays.count) insight\(completedDays.count == 1 ? "" : "s") unlocked")
            .font(Typography.caption)
            .foregroundColor(.white.opacity(0.35))

          ForEach(ProgramPhase.allCases, id: \.self) { phase in
            let phaseDays = completedDays.filter { $0.phase == phase }
            if !phaseDays.isEmpty {
              phaseSection(phase: phase, days: phaseDays)
            }
          }
        }
      }
    }
  }

  private func phaseSection(phase: ProgramPhase, days: [ProgramDay]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Text(phase.displayName)
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

  private var completedDaysWithEdges: [ProgramDay] {
    guard let program = programService.program,
          let userProgram = programService.activeProgram else { return [] }
    return program.days.filter { userProgram.completedDays.contains($0.dayNumber) }
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

        Text("Every Mental Edge insight you unlock, plus your saved Advisor sessions — all in one place.")
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

// MARK: - Mental Edge Library Card

struct MentalEdgeLibraryCard: View {
  let day: ProgramDay
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
    .environmentObject(ProgramService(auth: auth))
    .environmentObject(PaywallService(authService: auth))
}
