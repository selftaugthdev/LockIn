import SwiftUI

struct AdvisorView: View {
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var paywallService: PaywallService
  @StateObject private var advisor = AdvisorService.shared

  @State private var selectedFigure: AdvisorFigure = .machiavelli
  @State private var situation: String = ""
  @State private var currentResponse: String = ""
  @State private var currentSession: AdvisorSession?
  @State private var showingSavedSessions = false
  @State private var sessionSaved = false

  // Usage limits
  @State private var hasUsedFreeQuestion = false
  @State private var proQuestionsToday = 0

  private let freeUsedKey = "advisor_free_used"
  private var proCountKey: String {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    return "advisor_pro_\(df.string(from: Date()))"
  }

  private var isProAtDailyLimit: Bool {
    paywallService.isPro && proQuestionsToday >= 20
  }

  private var canSubmit: Bool {
    guard situation.trimmingCharacters(in: .whitespacesAndNewlines).count >= 20 else { return false }
    if paywallService.isPro { return !isProAtDailyLimit }
    return !hasUsedFreeQuestion
  }

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk.ignoresSafeArea()

        if paywallService.isPro || !hasUsedFreeQuestion {
          mainContent
        } else {
          lockedState
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("The Advisor")
            .font(Typography.headline)
            .foregroundColor(.brandYellow)
        }
        if paywallService.isPro {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button {
              showingSavedSessions = true
            } label: {
              Image(systemName: "bookmark.fill")
                .foregroundColor(.white.opacity(0.5))
            }
          }
        }
      }
      .preferredColorScheme(.dark)
      .sheet(isPresented: $showingSavedSessions) {
        SavedSessionsSheet()
          .environmentObject(authService)
      }
      .onAppear {
        hasUsedFreeQuestion = UserDefaults.standard.bool(forKey: freeUsedKey)
        proQuestionsToday = UserDefaults.standard.integer(forKey: proCountKey)
        if paywallService.isPro, let uid = authService.uid {
          Task { await advisor.loadSavedSessions(userId: uid) }
        }
      }
    }
  }

  // MARK: - Main Content

  private var mainContent: some View {
    ScrollView {
      VStack(spacing: 20) {
        headerCard

        if !paywallService.isPro {
          freeTeaser
        }

        figureSelector
        situationInput

        if advisor.isLoading {
          ThinkingCard(figureName: selectedFigure.displayName)
        } else if !currentResponse.isEmpty {
          responseCard
        }

        Spacer(minLength: 80)
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
    }
  }

  // MARK: - Header Card

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("What Would They Do?")
        .font(Typography.title2)
        .foregroundColor(.white)
      Text("Describe your situation. Pick your figure. Get a strategic analysis from history's sharpest minds.")
        .font(Typography.subheadline)
        .foregroundColor(.white.opacity(0.45))
        .lineSpacing(3)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 4)
    .padding(.bottom, 4)
  }

  // MARK: - Free Teaser Banner

  private var freeTeaser: some View {
    HStack(spacing: 10) {
      Image(systemName: "gift")
        .font(.subheadline)
        .foregroundColor(.brandYellow)
      Text("You have 1 free question. Make it count.")
        .font(Typography.caption)
        .foregroundColor(.white.opacity(0.6))
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color.brandYellow.opacity(0.08))
    .cornerRadius(10)
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.brandYellow.opacity(0.2), lineWidth: 1)
    )
  }

  // MARK: - Figure Selector

  private var figureSelector: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("SELECT YOUR FIGURE")
        .font(Typography.caption2)
        .fontWeight(.semibold)
        .foregroundColor(.white.opacity(0.4))
        .tracking(1.5)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(AdvisorFigure.allCases) { figure in
            FigureChip(
              figure: figure,
              isSelected: selectedFigure == figure,
              onTap: {
                selectedFigure = figure
                currentResponse = ""
                currentSession = nil
                sessionSaved = false
              }
            )
          }
        }
        .padding(.horizontal, 1)
      }

      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 2) {
          Text(selectedFigure.displayName)
            .font(Typography.headline)
            .foregroundColor(.white)
          Text(selectedFigure.tagline)
            .font(Typography.caption)
            .foregroundColor(.brandYellow.opacity(0.7))
        }
        Spacer()
        Text(selectedFigure.era)
          .font(Typography.caption2)
          .foregroundColor(.white.opacity(0.3))
      }
      .padding(16)
      .background(Color.brandGray)
      .cornerRadius(12)
    }
  }

  // MARK: - Situation Input

  private var situationInput: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("YOUR SITUATION")
        .font(Typography.caption2)
        .fontWeight(.semibold)
        .foregroundColor(.white.opacity(0.4))
        .tracking(1.5)

      ZStack(alignment: .topLeading) {
        if situation.isEmpty {
          Text("Describe what's happening. Be specific — who, what, what you want the outcome to be.")
            .font(Typography.body)
            .foregroundColor(.white.opacity(0.25))
            .padding(.top, 8)
            .padding(.leading, 4)
        }

        TextEditor(text: $situation)
          .font(Typography.body)
          .foregroundColor(.white)
          .scrollContentBackground(.hidden)
          .background(Color.clear)
          .frame(minHeight: 120)
          .disabled(advisor.isLoading)
      }
      .padding(16)
      .background(Color.brandGray)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.white.opacity(0.08), lineWidth: 1)
      )
      .opacity(advisor.isLoading ? 0.5 : 1)

      if isProAtDailyLimit {
        Text("You've reached your 20 questions for today. Come back tomorrow.")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.5))
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 16)
          .background(Color.brandGray)
          .cornerRadius(14)
      } else {
        Button {
          Task { await getAdvice() }
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "arrow.up.circle.fill")
              .font(.title3)
            Text("Ask \(selectedFigure.displayName)")
              .font(Typography.headline)
              .foregroundColor(.brandInk)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(canSubmit && !advisor.isLoading ? Color.brandYellow : Color.brandYellow.opacity(0.3))
          .cornerRadius(14)
        }
        .disabled(!canSubmit || advisor.isLoading)
      }

      if let error = advisor.errorMessage {
        Text(error)
          .font(Typography.caption)
          .foregroundColor(.brandRed)
      }
    }
  }

  // MARK: - Response Card

  private var responseCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(selectedFigure.displayName.uppercased())
            .font(Typography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.brandYellow.opacity(0.7))
            .tracking(1.5)
          Text(selectedFigure.tagline)
            .font(Typography.caption)
            .foregroundColor(.white.opacity(0.4))
        }
        Spacer()
        if paywallService.isPro {
          if !sessionSaved {
            Button {
              Task { await saveCurrentSession() }
            } label: {
              HStack(spacing: 4) {
                Image(systemName: "bookmark")
                  .font(.caption)
                Text("Save")
                  .font(Typography.caption)
                  .fontWeight(.semibold)
              }
              .foregroundColor(.brandYellow)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(Color.brandYellow.opacity(0.1))
              .cornerRadius(8)
            }
          } else {
            HStack(spacing: 4) {
              Image(systemName: "bookmark.fill")
                .font(.caption)
              Text("Saved")
                .font(Typography.caption)
                .fontWeight(.semibold)
            }
            .foregroundColor(.brandGreen)
          }
        }
      }
      .padding(20)

      Divider()
        .background(Color.white.opacity(0.06))

      Text(currentResponse)
        .font(Typography.body)
        .foregroundColor(.white.opacity(0.8))
        .lineSpacing(6)
        .fixedSize(horizontal: false, vertical: true)
        .padding(20)

      Divider()
        .background(Color.white.opacity(0.06))

      if !paywallService.isPro {
        Button {
          paywallService.safeShowPaywall()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "lock.open.fill")
              .font(.caption)
            Text("Unlock unlimited questions")
              .font(Typography.subheadline)
              .fontWeight(.semibold)
          }
          .foregroundColor(.brandYellow)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
        }
      } else {
        Button {
          situation = ""
          currentResponse = ""
          currentSession = nil
          sessionSaved = false
        } label: {
          Text("New Question")
            .font(Typography.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
      }
    }
    .background(Color.brandGray)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.brandYellow.opacity(0.15), lineWidth: 1)
    )
  }

  // MARK: - Locked State

  private var lockedState: some View {
    VStack(spacing: 24) {
      Spacer()

      VStack(spacing: 16) {
        Image(systemName: "brain.head.profile")
          .font(.system(size: 48))
          .foregroundColor(.brandYellow.opacity(0.6))

        Text("The Advisor")
          .font(Typography.title2)
          .foregroundColor(.white)

        Text("Get strategic analysis from Machiavelli, Nietzsche, Sun Tzu, and six other philosophers. Describe your situation — they'll tell you exactly what to do.")
          .font(Typography.body)
          .foregroundColor(.white.opacity(0.5))
          .multilineTextAlignment(.center)
          .lineSpacing(4)
          .padding(.horizontal, 24)
      }

      VStack(spacing: 8) {
        ForEach(["Machiavelli on being manipulated", "Sun Tzu on a difficult colleague", "Epictetus on what you can't control"], id: \.self) { example in
          HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.brandYellow)
              .font(.caption)
            Text(example)
              .font(Typography.subheadline)
              .foregroundColor(.white.opacity(0.6))
            Spacer()
          }
        }
      }
      .padding(.horizontal, 32)

      Button {
        paywallService.safeShowPaywall()
      } label: {
        Text("Unlock The Advisor")
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

  // MARK: - Actions

  private func getAdvice() async {
    let trimmed = situation.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let uid = authService.uid else { return }

    do {
      let response = try await advisor.query(figure: selectedFigure, situation: trimmed)
      currentResponse = response
      currentSession = AdvisorSession(
        userId: uid,
        figure: selectedFigure,
        situation: trimmed,
        response: response
      )
      sessionSaved = false

      if paywallService.isPro {
        proQuestionsToday += 1
        UserDefaults.standard.set(proQuestionsToday, forKey: proCountKey)
      } else {
        hasUsedFreeQuestion = true
        UserDefaults.standard.set(true, forKey: freeUsedKey)
      }
    } catch {
      advisor.errorMessage = error.localizedDescription
    }
  }

  private func saveCurrentSession() async {
    guard let session = currentSession, let uid = authService.uid else { return }
    do {
      try await advisor.saveSession(session, userId: uid)
      sessionSaved = true
    } catch {
      print("AdvisorView: failed to save session — \(error)")
    }
  }
}

// MARK: - Thinking Card

struct ThinkingCard: View {
  let figureName: String
  @State private var phase = 0

  var body: some View {
    VStack(spacing: 20) {
      Text("\(figureName) is thinking...")
        .font(Typography.subheadline)
        .foregroundColor(.white.opacity(0.5))

      HStack(spacing: 10) {
        ForEach(0..<3, id: \.self) { index in
          Circle()
            .fill(Color.brandYellow)
            .frame(width: 8, height: 8)
            .scaleEffect(phase == index ? 1.4 : 0.7)
            .opacity(phase == index ? 1 : 0.3)
            .animation(.easeInOut(duration: 0.4), value: phase)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 44)
    .background(Color.brandGray)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.brandYellow.opacity(0.1), lineWidth: 1)
    )
    .onAppear {
      let timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
        phase = (phase + 1) % 3
      }
      RunLoop.main.add(timer, forMode: .common)
    }
  }
}

// MARK: - Figure Chip

struct FigureChip: View {
  let figure: AdvisorFigure
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      Text(figure.displayName)
        .font(Typography.caption)
        .fontWeight(isSelected ? .semibold : .regular)
        .foregroundColor(isSelected ? .brandInk : .white.opacity(0.6))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? Color.brandYellow : Color.brandGray)
        .cornerRadius(20)
    }
  }
}

// MARK: - Saved Sessions Sheet

struct SavedSessionsSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var authService: AuthService
  @ObservedObject private var advisor = AdvisorService.shared

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk.ignoresSafeArea()

        if advisor.savedSessions.isEmpty {
          VStack(spacing: 12) {
            Image(systemName: "bookmark")
              .font(.largeTitle)
              .foregroundColor(.white.opacity(0.15))
            Text("No saved sessions")
              .font(Typography.headline)
              .foregroundColor(.white.opacity(0.4))
            Text("Save a response from The Advisor and it will appear here.")
              .font(Typography.subheadline)
              .foregroundColor(.white.opacity(0.25))
              .multilineTextAlignment(.center)
          }
          .padding(.horizontal, 32)
        } else {
          ScrollView {
            VStack(spacing: 14) {
              ForEach(advisor.savedSessions) { session in
                SavedSessionCard(session: session)
              }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
          }
        }
      }
      .navigationTitle("Saved")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") { dismiss() }
            .foregroundColor(.brandYellow)
        }
      }
      .preferredColorScheme(.dark)
    }
  }
}

// MARK: - Saved Session Card

struct SavedSessionCard: View {
  let session: AdvisorSession
  @ObservedObject private var advisor = AdvisorService.shared
  @EnvironmentObject var authService: AuthService
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded.toggle()
        }
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(session.figure.uppercased())
              .font(Typography.caption2)
              .fontWeight(.semibold)
              .foregroundColor(.brandYellow.opacity(0.7))
              .tracking(1)
            Text(session.situation)
              .font(Typography.subheadline)
              .foregroundColor(.white.opacity(0.7))
              .lineLimit(2)
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

        Text(session.response)
          .font(Typography.body)
          .foregroundColor(.white.opacity(0.7))
          .lineSpacing(5)
          .fixedSize(horizontal: false, vertical: true)
          .padding(16)

        Divider()
          .background(Color.white.opacity(0.06))

        Button {
          Task { await advisor.deleteSession(session) }
        } label: {
          Text("Remove")
            .font(Typography.caption)
            .foregroundColor(.brandRed.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
      }
    }
    .background(Color.brandGray)
    .cornerRadius(14)
  }
}

#Preview {
  let auth = AuthService()
  AdvisorView()
    .environmentObject(auth)
    .environmentObject(PaywallService(authService: auth))
}
