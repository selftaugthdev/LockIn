import FirebaseFirestore
import GoogleSignIn
import FirebaseAuth
import RevenueCat
import SwiftUI

// MARK: - Onboarding Step

enum OnboardingStep: Int {
  case splash = 0
  case whatFellApart
  case howLong
  case holdingBack
  case whatWinningMeans
  case socialProof
  case howItWorks
  case yourProgram
  case commitment
  case yourName
  case reminderTime
  case signIn
  case paywall
}

// MARK: - Onboarding View

struct OnboardingView: View {
  @EnvironmentObject var authService: AuthService
  @EnvironmentObject var paywallService: PaywallService

  @State private var step: OnboardingStep = .splash
  @State private var direction: Int = 1

  // Answers
  @State private var whatFellApart: Set<String> = []
  @State private var howLong: String = ""
  @State private var holdingBack: String = ""
  @State private var whatWinningMeans: String = ""
  @State private var userName: String = ""
  @State private var reminderTime: Date = defaultReminderTime()

  // Sign-in state
  @State private var isSigningIn = false
  @State private var signInError: String?

  // Paywall state
  @State private var offerings: Offerings?
  @State private var isPurchasing = false
  @State private var purchaseError: String?

  var body: some View {
    ZStack {
      Color.brandInk.ignoresSafeArea()

      stepView
        .id(step.rawValue)
        .transition(
          .asymmetric(
            insertion: .move(edge: direction > 0 ? .trailing : .leading),
            removal: .move(edge: direction > 0 ? .leading : .trailing)
          )
        )
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Step Router

  @ViewBuilder
  private var stepView: some View {
    switch step {
    case .splash:          splashStep
    case .whatFellApart:   whatFellApartStep
    case .howLong:         howLongStep
    case .holdingBack:     holdingBackStep
    case .whatWinningMeans: whatWinningMeansStep
    case .socialProof:     socialProofStep
    case .howItWorks:      howItWorksStep
    case .yourProgram:     yourProgramStep
    case .commitment:      commitmentStep
    case .yourName:        yourNameStep
    case .reminderTime:    reminderTimeStep
    case .signIn:          signInStep
    case .paywall:         paywallStep
    }
  }

  // MARK: - Navigation

  private func next() {
    let nextRaw = step.rawValue + 1
    guard let next = OnboardingStep(rawValue: nextRaw) else { return }
    direction = 1
    withAnimation(.easeInOut(duration: 0.35)) {
      step = next
    }
  }

  private func back() {
    let prevRaw = step.rawValue - 1
    guard prevRaw >= 1, let prev = OnboardingStep(rawValue: prevRaw) else { return }
    direction = -1
    withAnimation(.easeInOut(duration: 0.35)) {
      step = prev
    }
  }

  // MARK: - Progress Indicator

  private func progressDots(total: Int, current: Int) -> some View {
    HStack(spacing: 6) {
      ForEach(0..<total, id: \.self) { i in
        Capsule()
          .fill(i == current ? Color.brandYellow : Color.white.opacity(0.15))
          .frame(width: i == current ? 20 : 6, height: 6)
          .animation(.easeInOut(duration: 0.2), value: current)
      }
    }
  }

  // MARK: - Reusable Question Layout

  private func questionLayout<Content: View>(
    stepIndex: Int,
    totalSteps: Int,
    question: String,
    subtitle: String? = nil,
    canContinue: Bool = true,
    continueLabel: String = "Continue",
    onContinue: (() -> Void)? = nil,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(spacing: 0) {
      // Top bar
      HStack {
        if stepIndex > 0 {
          Button(action: back) {
            Image(systemName: "chevron.left")
              .font(.title3)
              .foregroundColor(.white.opacity(0.5))
          }
        }
        Spacer()
        progressDots(total: totalSteps, current: stepIndex)
        Spacer()
        if stepIndex > 0 {
          Color.clear.frame(width: 24)
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 16)
      .padding(.bottom, 28)

      // Question header
      VStack(alignment: .leading, spacing: 8) {
        Text(question)
          .font(Typography.title)
          .foregroundColor(.white)
          .fixedSize(horizontal: false, vertical: true)
        if let subtitle = subtitle {
          Text(subtitle)
            .font(Typography.subheadline)
            .foregroundColor(.white.opacity(0.45))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.bottom, 28)

      // Answer options
      content()
        .padding(.horizontal, 24)

      Spacer()

      // Continue button
      Button {
        if let action = onContinue {
          action()
        } else {
          next()
        }
      } label: {
        Text(continueLabel)
          .font(Typography.headline)
          .foregroundColor(.brandInk)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 18)
          .background(canContinue ? Color.brandYellow : Color.white.opacity(0.15))
          .cornerRadius(14)
      }
      .disabled(!canContinue)
      .padding(.horizontal, 24)
      .padding(.bottom, 44)
      .padding(.top, 16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  // MARK: - Step 1: Splash

  private var splashStep: some View {
    ZStack {
      Color.brandInk.ignoresSafeArea()
      VStack(spacing: 16) {
        Spacer()
        Text("FORGE")
          .font(.system(size: 64, weight: .black, design: .default))
          .tracking(8)
          .foregroundColor(.white)
        Text("Built under pressure.")
          .font(Typography.body)
          .foregroundColor(.white.opacity(0.4))
        Spacer()
        Text("Tap to begin")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.2))
          .padding(.bottom, 60)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      next()
    }
  }

  // MARK: - Step 2: What Fell Apart

  private var whatFellApartStep: some View {
    let options = ["Fitness", "Discipline", "Focus", "Relationships", "Career", "Everything"]
    return questionLayout(
      stepIndex: 0,
      totalSteps: 10,
      question: "What fell apart?",
      subtitle: "Select everything that applies.",
      canContinue: !whatFellApart.isEmpty
    ) {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(options, id: \.self) { option in
          let selected = whatFellApart.contains(option)
          Button {
            if selected {
              whatFellApart.remove(option)
            } else {
              whatFellApart.insert(option)
            }
          } label: {
            Text(option)
              .font(Typography.subheadline)
              .fontWeight(.medium)
              .foregroundColor(selected ? .brandInk : .white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .background(selected ? Color.brandYellow : Color.brandGray)
              .cornerRadius(12)
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(selected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
              )
          }
        }
      }
    }
  }

  // MARK: - Step 3: How Long

  private var howLongStep: some View {
    let options = ["Less than 3 months", "About 6 months", "About a year", "Longer than that"]
    return questionLayout(
      stepIndex: 1,
      totalSteps: 10,
      question: "How long have you been off track?",
      canContinue: !howLong.isEmpty
    ) {
      VStack(spacing: 10) {
        ForEach(options, id: \.self) { option in
          selectionRow(option, selected: howLong == option) {
            howLong = option
          }
        }
      }
    }
  }

  // MARK: - Step 4: Holding Back

  private var holdingBackStep: some View {
    let options = [
      "Fear of failing again",
      "No structure to follow",
      "Lost all motivation",
      "I don't know where to start"
    ]
    return questionLayout(
      stepIndex: 2,
      totalSteps: 10,
      question: "What's actually holding you back?",
      subtitle: "Be honest. No one else is reading this.",
      canContinue: !holdingBack.isEmpty
    ) {
      VStack(spacing: 10) {
        ForEach(options, id: \.self) { option in
          selectionRow(option, selected: holdingBack == option) {
            holdingBack = option
          }
        }
      }
    }
  }

  // MARK: - Step 5: What Winning Means

  private var whatWinningMeansStep: some View {
    let options = [
      "Feeling in control again",
      "Being someone I respect",
      "Physical health and energy",
      "Mental clarity and focus"
    ]
    return questionLayout(
      stepIndex: 3,
      totalSteps: 10,
      question: "What does getting back on track mean to you?",
      canContinue: !whatWinningMeans.isEmpty
    ) {
      VStack(spacing: 10) {
        ForEach(options, id: \.self) { option in
          selectionRow(option, selected: whatWinningMeans == option) {
            whatWinningMeans = option
          }
        }
      }
    }
  }

  // MARK: - Step 6: Social Proof

  private var socialProofStep: some View {
    questionLayout(
      stepIndex: 4,
      totalSteps: 10,
      question: "You're not alone.",
      continueLabel: "That's good to hear"
    ) {
      VStack(alignment: .leading, spacing: 20) {
        Text("Most men don't talk about falling off. They just quietly struggle, waiting for the right moment to start over.")
          .font(Typography.body)
          .foregroundColor(.white.opacity(0.6))
          .lineSpacing(5)

        Text("The right moment is now. Not Monday. Not next month. Today.")
          .font(Typography.body)
          .foregroundColor(.white)
          .lineSpacing(5)

        HStack(spacing: 16) {
          statPill(value: "30", label: "days")
          statPill(value: "1", label: "challenge a day")
          statPill(value: "0", label: "excuses")
        }
      }
    }
  }

  // MARK: - Step 7: How It Works

  private var howItWorksStep: some View {
    questionLayout(
      stepIndex: 5,
      totalSteps: 10,
      question: "Here's how Forge works."
    ) {
      VStack(spacing: 16) {
        howItWorksRow(
          number: "01",
          title: "One challenge per day",
          body: "No choosing, no browsing. Your challenge is assigned. You execute."
        )
        howItWorksRow(
          number: "02",
          title: "Difficulty builds as you go",
          body: "The first week eases you in. By week four, you'll be doing things you wouldn't have attempted on Day 1."
        )
        howItWorksRow(
          number: "03",
          title: "Miss a day, earn it back",
          body: "No streak-breaking, no starting over. Miss a day and the next one is a recovery day. Two challenges, same XP. You work harder, not less."
        )
      }
    }
  }

  // MARK: - Step 8: Your Program

  private var yourProgramStep: some View {
    questionLayout(
      stepIndex: 6,
      totalSteps: 10,
      question: "This is where you start.",
      subtitle: "Based on what you told us.",
      continueLabel: "This is my program"
    ) {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 8) {
            Badge(text: "30 Days", color: .brandYellow)
            Badge(text: "Beginner", color: .brandGreen)
          }
          Text("30-Day Foundation")
            .font(Typography.title2)
            .foregroundColor(.white)
          Text("Build the discipline you lost")
            .font(Typography.subheadline)
            .foregroundColor(.white.opacity(0.5))
        }
        .padding(20)
        .background(Color.brandGray)
        .cornerRadius(16)
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color.brandYellow.opacity(0.2), lineWidth: 1)
        )

        Text("Every man starts here. The Foundation program was designed for one thing: proving to yourself that you can show up every single day.")
          .font(Typography.subheadline)
          .foregroundColor(.white.opacity(0.5))
          .lineSpacing(4)
      }
    }
  }

  // MARK: - Step 9: Commitment

  private var commitmentStep: some View {
    ZStack {
      Color.brandInk.ignoresSafeArea()
      VStack(spacing: 0) {
        Spacer()
        VStack(spacing: 20) {
          Text("This only works\nif you show up.")
            .font(Typography.largeTitle)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineSpacing(4)

          Text("Not when you feel like it.\nEvery day.")
            .font(Typography.body)
            .foregroundColor(.white.opacity(0.4))
            .multilineTextAlignment(.center)
        }
        Spacer()
        Button {
          next()
        } label: {
          Text("I commit.")
            .font(Typography.headline)
            .foregroundColor(.brandInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.brandYellow)
            .cornerRadius(14)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 44)
      }
    }
  }

  // MARK: - Step 10: Your Name

  private var yourNameStep: some View {
    questionLayout(
      stepIndex: 7,
      totalSteps: 10,
      question: "What should we call you?",
      canContinue: userName.trimmingCharacters(in: .whitespaces).count >= 2
    ) {
      VStack(alignment: .leading, spacing: 8) {
        TextField("", text: $userName)
          .font(Typography.title2)
          .foregroundColor(.white)
          .tint(.brandYellow)
          .placeholder(when: userName.isEmpty) {
            Text("Your first name")
              .font(Typography.title2)
              .foregroundColor(.white.opacity(0.2))
          }
          .padding(.vertical, 16)
          .padding(.horizontal, 20)
          .background(Color.brandGray)
          .cornerRadius(12)
          .autocorrectionDisabled()
          .textInputAutocapitalization(.words)

        Text("Only you will see this.")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.25))
          .padding(.horizontal, 4)
      }
    }
  }

  // MARK: - Step 11: Reminder Time

  private var reminderTimeStep: some View {
    questionLayout(
      stepIndex: 8,
      totalSteps: 10,
      question: "When do you want your daily reminder?",
      subtitle: "We'll check in once a day. No spam."
    ) {
      VStack(spacing: 16) {
        DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
          .datePickerStyle(.wheel)
          .labelsHidden()
          .colorScheme(.dark)
          .accentColor(.brandYellow)
          .frame(maxWidth: .infinity)

        Text("You can change this any time in Settings.")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.25))
          .frame(maxWidth: .infinity, alignment: .center)
      }
    }
  }

  // MARK: - Step 12: Sign In

  private var signInStep: some View {
    questionLayout(
      stepIndex: 9,
      totalSteps: 10,
      question: "Save your progress.",
      subtitle: "Sign in so you never lose your streak.",
      canContinue: false
    ) {
      VStack(spacing: 16) {
        if let error = signInError {
          Text(error)
            .font(Typography.caption)
            .foregroundColor(.brandRed)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Button {
          Task { await signInWithGoogle() }
        } label: {
          HStack(spacing: 12) {
            if isSigningIn {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
                .scaleEffect(0.85)
            } else {
              Image(systemName: "globe")
                .font(.title3)
            }
            Text(isSigningIn ? "Signing in..." : "Continue with Google")
              .font(Typography.headline)
              .foregroundColor(.brandInk)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 18)
          .background(Color.white)
          .cornerRadius(14)
        }
        .disabled(isSigningIn)

        Text("Your progress is tied to your account. If you uninstall and reinstall, everything is still there.")
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.25))
          .multilineTextAlignment(.center)
          .padding(.top, 8)
      }
    }
  }

  // MARK: - Step 13: Paywall

  private var paywallStep: some View {
    ZStack {
      Color.brandInk.ignoresSafeArea()

      ScrollView {
        VStack(spacing: 28) {
          Spacer(minLength: 40)

          VStack(spacing: 10) {
            Text("Forge Pro")
              .font(Typography.largeTitle)
              .foregroundColor(.white)

            Text("One program. Every day. Less than a coffee a week.")
              .font(Typography.body)
              .foregroundColor(.white.opacity(0.5))
              .multilineTextAlignment(.center)
              .padding(.horizontal, 20)
          }

          // Trial badge
          HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
              .foregroundColor(.brandYellow)
            Text("3 days free. Cancel any time.")
              .font(Typography.subheadline)
              .fontWeight(.semibold)
              .foregroundColor(.brandYellow)
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(Color.brandYellow.opacity(0.1))
          .cornerRadius(30)

          // Packages
          if let offering = offerings?.current {
            VStack(spacing: 12) {
              ForEach(offering.availablePackages, id: \.identifier) { package in
                paywallPackageRow(package)
              }
            }
            .padding(.horizontal, 24)
          } else {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .brandYellow))
              .padding(.vertical, 40)
          }

          // What's included
          VStack(alignment: .leading, spacing: 14) {
            Text("What you get")
              .font(Typography.headline)
              .foregroundColor(.white)

            paywallFeatureRow("Structured 30, 60, and 90-day programs")
            paywallFeatureRow("One challenge per day, designed to push you")
            paywallFeatureRow("Recovery system so you never have to start over")
            paywallFeatureRow("Certificate when you complete a program")
            paywallFeatureRow("New programs added every month")
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 24)

          if let error = purchaseError {
            Text(error)
              .font(Typography.caption)
              .foregroundColor(.brandRed)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 24)
          }

          Spacer(minLength: 100)
        }
      }

      // Bottom CTA
      VStack(spacing: 12) {
        Button {
          Task { await purchase() }
        } label: {
          HStack {
            if isPurchasing {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .brandInk))
            } else {
              Text("Start 3 days free")
                .font(Typography.headline)
                .foregroundColor(.brandInk)
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 18)
          .background(Color.brandYellow)
          .cornerRadius(14)
        }
        .disabled(isPurchasing || offerings == nil)
        .padding(.horizontal, 24)

        HStack(spacing: 20) {
          Button("Restore purchases") {
            Task { await restorePurchases() }
          }
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.3))

          Button("Continue without trial") {
            saveOnboardingAnswers()
            authService.completeOnboarding()
          }
          .font(Typography.caption)
          .foregroundColor(.white.opacity(0.3))
        }

        Text("Billed annually after trial. Cancel any time.")
          .font(Typography.caption2)
          .foregroundColor(.white.opacity(0.2))
      }
      .padding(.bottom, 44)
      .padding(.top, 16)
      .background(
        LinearGradient(
          colors: [Color.brandInk.opacity(0), Color.brandInk],
          startPoint: .top,
          endPoint: .bottom
        )
        .ignoresSafeArea()
      )
      .frame(maxHeight: .infinity, alignment: .bottom)
    }
    .task {
      await loadOfferings()
    }
  }

  // MARK: - Paywall Sub-Views

  private func paywallPackageRow(_ package: Package) -> some View {
    let isYearly = package.packageType == .annual
    let price = package.localizedPriceString
    let period = isYearly ? "/ year" : "/ month"
    let perMonth = isYearly
      ? perMonthPrice(package)
      : nil

    return Button {
      // Auto-select on tap, purchase on the CTA
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 8) {
            Text(isYearly ? "Yearly" : "Monthly")
              .font(Typography.subheadline)
              .fontWeight(.semibold)
              .foregroundColor(.white)
            if isYearly {
              Text("BEST VALUE")
                .font(Typography.caption2)
                .fontWeight(.bold)
                .foregroundColor(.brandInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.brandYellow)
                .cornerRadius(4)
            }
          }
          if let perMonth = perMonth {
            Text(perMonth + " per month")
              .font(Typography.caption)
              .foregroundColor(.white.opacity(0.4))
          }
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
          Text(price)
            .font(Typography.headline)
            .foregroundColor(.white)
          Text(period)
            .font(Typography.caption2)
            .foregroundColor(.white.opacity(0.4))
        }
      }
      .padding(18)
      .background(isYearly ? Color.brandYellow.opacity(0.08) : Color.brandGray)
      .cornerRadius(14)
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .stroke(isYearly ? Color.brandYellow.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 1)
      )
    }
  }

  private func paywallFeatureRow(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "checkmark")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(.brandYellow)
        .padding(.top, 3)
      Text(text)
        .font(Typography.subheadline)
        .foregroundColor(.white.opacity(0.6))
    }
  }

  private func perMonthPrice(_ package: Package) -> String? {
    guard let price = package.storeProduct.price as Decimal?,
          price > 0
    else { return nil }
    let monthly = price / 12
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale.current
    formatter.maximumFractionDigits = 2
    return formatter.string(from: monthly as NSDecimalNumber)
  }

  // MARK: - Reusable Components

  private func selectionRow(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        Text(label)
          .font(Typography.body)
          .foregroundColor(selected ? .brandInk : .white)
        Spacer()
        if selected {
          Image(systemName: "checkmark")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.brandInk)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 18)
      .background(selected ? Color.brandYellow : Color.brandGray)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(selected ? Color.clear : Color.white.opacity(0.07), lineWidth: 1)
      )
    }
  }

  private func howItWorksRow(number: String, title: String, body: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Text(number)
        .font(Typography.caption)
        .fontWeight(.bold)
        .foregroundColor(.brandYellow.opacity(0.6))
        .frame(width: 28)
        .padding(.top, 3)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(Typography.subheadline)
          .fontWeight(.semibold)
          .foregroundColor(.white)
        Text(body)
          .font(Typography.subheadline)
          .foregroundColor(.white.opacity(0.45))
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(16)
    .background(Color.brandGray)
    .cornerRadius(12)
  }

  private func statPill(value: String, label: String) -> some View {
    VStack(spacing: 4) {
      Text(value)
        .font(Typography.title3)
        .fontWeight(.bold)
        .foregroundColor(.brandYellow)
      Text(label)
        .font(Typography.caption2)
        .foregroundColor(.white.opacity(0.35))
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .background(Color.brandGray)
    .cornerRadius(12)
  }

  // MARK: - Actions

  private func signInWithGoogle() async {
    isSigningIn = true
    signInError = nil

    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootVC = windowScene.windows.first?.rootViewController
    else {
      signInError = "Unable to present sign-in."
      isSigningIn = false
      return
    }

    do {
      // Ensure anonymous session exists for linking
      if Auth.auth().currentUser == nil {
        try await authService.signInAnonymously()
      }

      let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
      guard let idToken = result.user.idToken?.tokenString else {
        signInError = "Sign-in failed. Please try again."
        isSigningIn = false
        return
      }

      let credential = GoogleAuthProvider.credential(
        withIDToken: idToken,
        accessToken: result.user.accessToken.tokenString
      )

      try await authService.linkWithGoogle(credential: credential)
      saveOnboardingAnswers()
      next()
    } catch {
      signInError = "Sign-in failed. Please try again."
      print("Google sign-in error: \(error)")
    }

    isSigningIn = false
  }

  private func loadOfferings() async {
    do {
      offerings = try await Purchases.shared.offerings()
    } catch {
      print("Failed to load offerings: \(error)")
    }
  }

  private func purchase() async {
    guard let package = yearlyPackage() ?? offerings?.current?.availablePackages.first else { return }
    isPurchasing = true
    purchaseError = nil

    do {
      let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)
      if customerInfo.entitlements["Pro"]?.isActive == true {
        paywallService.isPro = true
        authService.completeOnboarding()
      } else {
        purchaseError = "Purchase completed but could not activate. Please restore purchases."
      }
    } catch {
      if (error as NSError).code != 2 { // 2 = user cancelled
        purchaseError = "Purchase failed. Please try again."
      }
    }

    isPurchasing = false
  }

  private func restorePurchases() async {
    isPurchasing = true
    do {
      let customerInfo = try await Purchases.shared.restorePurchases()
      if customerInfo.entitlements["Pro"]?.isActive == true {
        paywallService.isPro = true
        authService.completeOnboarding()
      } else {
        purchaseError = "No active subscription found."
      }
    } catch {
      purchaseError = "Restore failed. Please try again."
    }
    isPurchasing = false
  }

  private func yearlyPackage() -> Package? {
    offerings?.current?.availablePackages.first { $0.packageType == .annual }
  }

  private func saveOnboardingAnswers() {
    guard let uid = authService.uid else { return }

    let name = userName.trimmingCharacters(in: .whitespaces)
    let data: [String: Any] = [
      "displayName": name.isEmpty ? nil : name as Any,
      "onboardingWhatFellApart": Array(whatFellApart),
      "onboardingHowLong": howLong,
      "onboardingHoldingBack": holdingBack,
      "onboardingWhatWinningMeans": whatWinningMeans,
      "onboardingReminderTime": Timestamp(date: reminderTime),
      "onboardingCompleted": true
    ]

    Firestore.firestore().collection("users").document(uid).setData(
      data.compactMapValues { $0 },
      merge: true
    )
  }

  // MARK: - Helpers

  private static func defaultReminderTime() -> Date {
    var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    components.hour = 9
    components.minute = 0
    return Calendar.current.date(from: components) ?? Date()
  }
}

// MARK: - Placeholder Text Helper

extension View {
  func placeholder<Content: View>(when shouldShow: Bool, @ViewBuilder placeholder: () -> Content) -> some View {
    ZStack(alignment: .leading) {
      placeholder().opacity(shouldShow ? 1 : 0)
      self
    }
  }
}

#Preview {
  let auth = AuthService()
  OnboardingView()
    .environmentObject(auth)
    .environmentObject(PaywallService(authService: auth))
}
