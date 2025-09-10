import SwiftUI

struct ChallengeSelectionView: View {
  @EnvironmentObject var challengeService: ChallengeService
  @EnvironmentObject var paywallService: PaywallService
  @Environment(\.dismiss) private var dismiss
  @State private var searchText = ""
  @State private var selectedType: ChallengeType? = nil
  @State private var showingCustomEditor = false
  @State private var showingLimitReachedAlert = false
  @State private var showFreeProBanner = false

  private var filteredChallenges: [Challenge] {
    var challenges = challengeService.availableChallenges

    // Filter by search text
    if !searchText.isEmpty {
      challenges = challenges.filter { challenge in
        challenge.title.localizedCaseInsensitiveContains(searchText)
      }
    }

    // Filter by type
    if let selectedType = selectedType {
      challenges = challenges.filter { challenge in
        challenge.type == selectedType
      }
    }

    return challenges
  }

  var body: some View {
    NavigationView {
      ZStack {
        Color.brandInk
          .ignoresSafeArea()

        ScrollView {
          VStack(spacing: 16) {
            // Header
            headerSection

            // Free vs Pro Banner (only show when free user has 1 challenge selected)
            if showFreeProBanner {
              freeProBanner
            }

            // Filters
            filtersSection

            // Challenge List
            challengesListContent
          }
          .padding(.top, 8)
        }
      }
      .navigationTitle("Choose Challenges")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.brandYellow)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          if paywallService.isPro {
            Button(action: {
              showingCustomEditor = true
            }) {
              Image(systemName: "plus")
                .foregroundColor(.brandYellow)
            }
          }
        }
      }
      .preferredColorScheme(.dark)
    }
    .sheet(isPresented: $showingCustomEditor) {
      CustomChallengeEditor()
    }
    .alert("Challenge Limit Reached", isPresented: $showingLimitReachedAlert) {
      Button("Upgrade to Pro") {
        // Dismiss this view and show paywall
        dismiss()
        // The paywall will be shown from the parent view
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Free users can only select 1 challenge per day. Upgrade to Pro to choose unlimited challenges and create custom ones!"
      )
    }
  }

  private var headerSection: some View {
    VStack(spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Select Your Challenges")
            .title2Style()
            .foregroundColor(.white)

          Text(paywallService.isPro ? "Choose as many as you want" : "Choose 1 challenge for today")
            .bodyStyle()
            .foregroundColor(.secondary)
        }

        Spacer()

        // Selection count
        VStack(alignment: .trailing, spacing: 4) {
          Text("\(challengeService.selectedChallenges.count)")
            .title2Style()
            .foregroundColor(.brandYellow)

          Text("Selected")
            .captionStyle()
            .foregroundColor(.secondary)
        }
      }

      // Search bar
      HStack {
        Image(systemName: "magnifyingglass")
          .foregroundColor(.secondary)

        TextField("Search challenges...", text: $searchText)
          .textFieldStyle(PlainTextFieldStyle())
          .foregroundColor(.white)
      }
      .padding()
      .background(Color.brandGray)
      .cornerRadius(12)
    }
    .padding()
  }

  private var freeProBanner: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Free: Pick 1 challenge daily · Pro: Pick multiple & create your own.")
          .font(.caption)
          .foregroundColor(.secondary)
        Text("Try Pro For FREE For 3 Days")
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(.brandYellow)
      }
      Spacer()
      Button("Try Pro FREE") {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          paywallService.safeShowPaywall()
        }
      }
      .font(.caption)
      .fontWeight(.semibold)
      .foregroundColor(.brandInk)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Color.brandYellow)
      .cornerRadius(8)
    }
    .padding(.horizontal)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.brandGray.opacity(0.5))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.brandYellow.opacity(0.3), lineWidth: 1)
        )
    )
    .padding(.horizontal)
  }

  private var filtersSection: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        // All types filter
        FilterChip(
          title: "All",
          isSelected: selectedType == nil,
          action: { selectedType = nil }
        )

        // Type filters
        ForEach(ChallengeType.allCases, id: \.self) { type in
          FilterChip(
            title: type.displayName,
            isSelected: selectedType == type,
            action: { selectedType = selectedType == type ? nil : type }
          )
        }
      }
      .padding(.horizontal)
    }
  }

  private var challengesListContent: some View {
    LazyVStack(spacing: 12) {
      ForEach(filteredChallenges) { challenge in
        let canSelect = paywallService.isPro || challengeService.selectedChallenges.count < 1
        ChallengeSelectionRow(
          challenge: challenge,
          isSelected: challengeService.selectedChallenges.contains { $0.id == challenge.id },
          canSelect: canSelect,
          onTap: { attemptSelect(challenge) }
        )
      }
    }
    .padding()
  }

  private func attemptSelect(_ challenge: Challenge) {
    let alreadySelected = challengeService.selectedChallenges.contains { $0.id == challenge.id }

    // Free user trying to add a second challenge
    if !paywallService.isPro && !alreadySelected && challengeService.selectedChallenges.count >= 1 {
      withAnimation { showFreeProBanner = true }
      UINotificationFeedbackGenerator().notificationOccurred(.warning)
      // (Optional) also show the alert or paywall here if you like
      // showingLimitReachedAlert = true
      return
    }

    Task { await toggleChallengeSelection(challenge) }
  }

  private func toggleChallengeSelection(_ challenge: Challenge) async {
    let isSelected = challengeService.selectedChallenges.contains { $0.id == challenge.id }

    do {
      if isSelected {
        try await challengeService.deselectChallenge(challenge)
        // Hide banner when deselecting
        await MainActor.run {
          showFreeProBanner = false
        }
      } else {
        try await challengeService.selectChallenge(challenge, isPro: paywallService.isPro)
      }
    } catch ChallengeError.limitReached {
      // Show banner and alert for free users who try to select more than 1 challenge
      await MainActor.run {
        showFreeProBanner = true
        showingLimitReachedAlert = true
      }
    } catch {
      print("Error toggling challenge selection: \(error)")
    }
  }
}

struct FilterChip: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(isSelected ? .brandInk : .white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? Color.brandYellow : Color.brandGray)
        .cornerRadius(20)
    }
  }
}

struct ChallengeSelectionRow: View {
  let challenge: Challenge
  let isSelected: Bool
  let canSelect: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 16) {
        // Selection indicator
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .foregroundColor(isSelected ? .brandYellow : .secondary)
          .font(.title2)

        // Challenge info
        VStack(alignment: .leading, spacing: 4) {
          Text(challenge.title)
            .headlineStyle()
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)

          HStack(spacing: 12) {
            HStack(spacing: 4) {
              Text(challenge.type.emoji)
                .font(.caption)
              Text(challenge.type.displayName)
                .captionStyle()
                .foregroundColor(.brandYellow)
            }

            HStack(spacing: 2) {
              ForEach(1...3, id: \.self) { level in
                Image(systemName: "star.fill")
                  .foregroundColor(level <= challenge.difficulty ? .brandYellow : .gray)
                  .font(.caption2)
              }
            }
          }
        }

        Spacer()

        // Custom challenge indicator
        if challenge.dayIndex == 0 {
          Image(systemName: "person.circle.fill")
            .foregroundColor(.brandYellow)
            .font(.title3)
        }

        // Lock icon for greyed out rows
        if !canSelect && !isSelected {
          Image(systemName: "lock.fill")
            .foregroundColor(.secondary)
            .font(.caption)
        }
      }
      .padding()
      .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(isSelected ? Color.brandYellow.opacity(0.1) : Color.brandGray)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(isSelected ? Color.brandYellow : Color.clear, lineWidth: 1)
          )
      )
    }
    .opacity((!canSelect && !isSelected) ? 0.5 : 1.0)
  }
}

#Preview {
  ChallengeSelectionView()
    .environmentObject(ChallengeService(auth: AuthService()))
    .environmentObject(PaywallService(authService: AuthService()))
    .background(Color.brandInk)
}
