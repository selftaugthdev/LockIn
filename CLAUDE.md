# Forge — Claude Code Context

## What this is
iOS app called **Forge** (repo folder: LockIn). 30-day psychological sovereignty program for men 25–45. Built around philosophers: Machiavelli, Nietzsche, Schopenhauer, Sun Tzu, etc. App ID: `com.thierrydb.LockIn`.

## Stack
- SwiftUI + Firebase (Auth, Firestore, Cloud Functions Gen2/Node20)
- RevenueCat (PaywallKit) for Pro subscription
- Google Sign-In
- Anthropic Claude API via Firebase Function proxy (`functions/src/index.ts`)

## Tab structure
Today (`ProgramDayView`) | Progress (`ProgressView`) | Advisor (`AdvisorView`) | Library (`LibraryView`)

## Key architecture

### Program system
- `foundation_30.json` — bundled 30-day program (loaded from bundle, not Firestore)
- `Program.swift` — `Program`, `ProgramDay`, `MentalEdge`, `ProgramPhase` (wakeUp/armorUp/sharpen/operate = wake_up/armor_up/sharpen/operate raw values)
- `UserProgram.swift` — user's enrollment state, stored in Firestore `userPrograms` collection
- `ProgramService.swift` — loads/advances/completes program days, manages enrollment
- Phases: wakeUp (days 1–7), armorUp (8–14), sharpen (15–21), operate (22–30)

### Auth flow
- `AuthService.swift` — Firebase Auth, anonymous sign-in, Google/Apple linking
- `ContentView.swift` — routes: spinner → onboarding OR spinner (while `hasFetchedActiveProgram=false`) → `ProgramSelectionView` OR `MainTabView`
- `ProgramService.hasFetchedActiveProgram` flag prevents flash to ProgramSelectionView before Firestore loads

### Premium gating
- `PaywallService.isPro` gates: Mental Edge card, nightly reflection, Advisor tab, Library tab
- Free users get 1 lifetime Advisor question (UserDefaults key: `advisor_free_used`)
- Pro users get 20 Advisor questions/day (UserDefaults key: `advisor_pro_YYYY-MM-DD`)

### Advisor (AI philosopher Q&A)
- `AdvisorService.swift` — 9 philosophers with system prompts, calls Firebase Function
- Firebase Function `advisor` deployed at `https://advisor-ejsk6rqzwa-uc.a.run.app`
- Calls `claude-sonnet-4-6` via Anthropic SDK, `ANTHROPIC_API_KEY` stored as Firebase Secret
- Sessions saved to Firestore `advisorSessions` collection

### Streak / XP
- `completeProgramDay()` in ProgramService updates `streakCount`, `lastCompleted`, `totalXP` on user doc
- Streak logic: yesterday → increment, today → preserve, gap → reset to 1

## Firestore collections
- `users/{uid}` — User profile, streak, XP
- `userPrograms/{uuid}` — UserProgram enrollment (userId field for queries)
- `advisorSessions/{docId}` — saved Advisor Q&A
- `reflections/{userId}_{programId}_day{n}` — nightly reflections
- `programCompletions/{docId}` — completed programs

## Key files
```
LockIn/
  Models/         Program.swift, User.swift, UserProgram.swift
  Services/       AuthService.swift, ProgramService.swift, AdvisorService.swift,
                  ReflectionService.swift, PaywallService.swift
  Views/          ProgramDayView.swift, AdvisorView.swift, LibraryView.swift,
                  ProgramSelectionView.swift, OnboardingView.swift, ProgressView.swift
  Resources/Programs/foundation_30.json
functions/src/index.ts   ← Firebase Functions (advisor endpoint)
```

## Current state (as of 2026-03-23)
- App builds and runs. Day completion works. Advisor works end-to-end.
- Firestore rules fixed to include userPrograms/advisorSessions/reflections/programCompletions.
- `hasFetchedActiveProgram` spinner prevents accidental re-enrollment on launch.
- Streak now correctly updated on program day completion.

## What's next (spec priorities)
1. Paywall rebuild — new pricing: weekly €3.99, monthly €9.99, annual €59.99, lifetime €149.99; 7-day trial; new copy
2. Onboarding update — new questions per spec (what are you dealing with, how bad is it, what matters most)
3. Notification revisions — new copy matching Forge voice, evening reflection trigger at 8pm
4. Program 2: The Operator (Days 31–60) — offensive program content
5. Daily Mental Edge standalone mode (post-program retention)
6. Scenario Library (pre-built Advisor situations)

## Conventions
- Colors: `Color.brandInk`, `Color.brandYellow`, `Color.brandGray`, `Color.brandGreen`, `Color.brandRed`, `Color.brandBlue`
- Typography: `Typography.largeTitle`, `.title2`, `.headline`, `.subheadline`, `.body`, `.caption`, `.caption2`, `.footnote`
- Dark-only app (`preferredColorScheme(.dark)` on all sheets/nav)
- No "Co-Authored-By" in commits
