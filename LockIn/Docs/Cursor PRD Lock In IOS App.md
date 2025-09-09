# Lock-In App – Product Requirements Document (PRD)

## 1. Objective
Launch a seasonal-to-evergreen self-improvement app centered on **daily challenges**, **streaks**, **aura points**, and **leaderboards**. Optimized for Shorts/TikTok distribution.

---

## 2. Target Users & JTBD
- **Target Users:** Gen Z / young millennials who want a focus sprint (Sept–Dec) and simple accountability mechanics.
- **Job To Be Done:** “Give me one lightweight thing to do each day, make it social, and let me see progress/clout fast.”

---

## 3. Core Use Cases (v1)
1. View today’s **Daily Challenge** → complete in 1 tap → earn **streak + aura**  
2. View **Leaderboard** (Global + Friends) with **weekly resets**  
3. **Progress Dashboard** (streak graph + aura meter)  
4. **Premium**: weekly themed challenges, friends leaderboard, aura insights

---

## 4. Non-Goals (v1)
- Long-form courses  
- Complex habit builders  
- DMs or chat groups  
- Web app  

---

## 5. Success Metrics (first 30 days)
- D1 retention ≥ **40%**  
- D7 retention ≥ **15%**  
- Avg sessions/user/day ≥ **1.6**  
- Free→Paid conversion ≥ **3–5%**  
- Video shares/screenshots per MAU ≥ **8%**  

---

## 6. Monetization
- **Free:** daily challenge, streaks, global leaderboard  
- **Premium ($4.99/mo or $29.99/yr):**
  - Personalized lock-in plan (AI, later)  
  - Friends leaderboard  
  - Weekly themed challenges  
  - Aura analytics & premium badges  

---

## 7. Risks & Mitigations
- **Seasonality:** Position app as “Lock-In → Aura” brand; weekly resets keep it fresh.  
- **Churn:** Streak tension, shareable badges, and weekly shout-outs.  

---

## 8. Firebase Setup

### Services to Enable
- Authentication (Anonymous, Sign in with Apple later)  
- Firestore (Native mode)  
- Analytics  
- (Optional) Cloud Functions for weekly leaderboard reset  

### Firestore Data Model
- users/{userId}
- displayName: String?
- createdAt: Timestamp
- streakCount: Int
- premium: Bool
- lastCompleted: Timestamp?
- friendCode: String

- challenges/{challengeId}
- title: String
- type: String
- difficulty: Int
- dayIndex: Int
- isActive: Bool

- completions/{completionId}
- userId: String
- challengeId: String
- completedAt: Timestamp

- leaderboardWeekly/{weekKey}
- entries: [{ userId, displayName, streakWeekly }]
- generatedAt: Timestamp

---

## Analytics Events

- `app_open`  
- `challenge_view`  
- `challenge_complete` (params: `challenge_id`, `type`, `difficulty`)  
- `streak_incremented` (params: `streak_count`)  
- `leaderboard_view` (params: `scope`)  
- `premium_view`, `premium_start_checkout`, `premium_purchase_success`  
- `share_attempt` (params: `type`)  

## Color Palette & Design System

### Brand Tokens
- **BrandYellow** → `#FFFF00` (accents, buttons)  
- **BrandInk** → `#0B0B0F` (near-black UI)  
- **BrandGray** → `#1C1C22` (dark cards), `#F4F5F7` (light cards)  
- **BrandGreen** → `#22C55E` (success)  
- **BrandRed** → `#EF4444` (penalty)  
- **Text:** use `Color.primary` / `Color.secondary` for accessibility  

### Typography
- Montserrat Regular / SemiBold / Bold  
- Or fallback: SF Pro  

## Project Structure (Xcode / Cursor) 
LockIn/
├─ Sources/
│  ├─ App/
│  ├─ Features/
│  │  ├─ DailyChallenge/
│  │  ├─ Leaderboard/
│  │  ├─ Progress/
│  │  ├─ Premium/
│  │  ├─ Onboarding/
│  │  └─ Settings/
│  ├─ Services/
│  ├─ Models/
│  ├─ DesignSystem/
│  ├─ Utils/
│  └─ Config/
├─ Resources/
│  ├─ Assets.xcassets
│  └─ PreloadedChallenges.json
├─ Tests/
└─ Package.swift

## 11. Cursor ToDo List

- Initialize Xcode project + add Firebase (Analytics, Auth, Firestore)  
- Add assets (brand colors, fonts, app icon)  
- Implement `AuthService` (anonymous) + bootstrap user doc  
- Build `DailyChallengeView` (JSON preload)  
- Implement `ChallengeService.complete()` with streak updates  
- Build `ProgressView` (streak graph + completions list)  
- Build `LeaderboardView` (top 50 global by streaks)  
- Add `AnalyticsService` with events  
- Add `PreloadedChallenges.json` (90–120 prompts)  
- Implement share flow for streak/badges  
- Add `SettingsView` (privacy, reset data for dev)  
- (Later) Friends leaderboard + Premium (RevenueCat)  

---

## 12. Git & Commit Conventions

- Short, imperative messages (no emojis, no long bodies)  
  - `init: firebase + auth`  
  - `feat: daily challenge view`  
  - `feat: complete challenge tx`  
  - `chore: preload challenges`  
  - `style: colors + typography`  
- Branch naming: `feat/`, `fix/`, `chore/`, `refactor/`  
- `.gitignore`: include `GoogleService-Info.plist`, DerivedData, build artifacts  

## Security Rules (starter)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isAuth() { return request.auth != null; }
    function isOwner(uid) { return isAuth() && request.auth.uid == uid; }

    match /users/{uid} {
      allow read: if isOwner(uid);
      allow write: if isOwner(uid);
    }

    match /challenges/{id} {
      allow read: if true;
      allow write: if false;
    }

    match /completions/{id} {
      allow read: if isAuth() && request.resource.data.userId == request.auth.uid;
      allow create: if isAuth() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if false;
    }

    match /leaderboardWeekly/{weekKey} {
      allow read: if true;
      allow write: if false;
    }
  }
}
