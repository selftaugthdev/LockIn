# LockIn Cloud Functions

This directory contains the Cloud Functions for the LockIn app.

## Setup

1. Install dependencies:

```bash
cd functions
npm install
```

2. Build the TypeScript:

```bash
npm run build
```

## Deployment

1. Make sure you're logged into Firebase CLI:

```bash
firebase login
```

2. Deploy the functions:

```bash
npm run deploy
```

## Local Development

1. Start the Firebase emulator:

```bash
npm run serve
```

## Functions

### onCompletionCreate

Triggered when a new completion document is created in the `completions` collection.

**Anti-cheat measures:**

- Validates required fields (`userId`, `challengeId`)
- Verifies `challengeId` exists in `challenges` collection
- Ensures user document exists before processing
- One completion per day guard (prevents spamming)
- Only Cloud Functions can update counter fields (enforced by Firestore rules)
- Comprehensive logging for monitoring and debugging

**What it does:**

- Increments `totalCount` for the user (always, for analytics)
- Increments `dailyCount` and `weeklyCount` if it's a new day
- Updates `lastCompleted` timestamp
- Prevents multiple increments per day (one completion per day rule)
- Logs all operations for security monitoring

**User Document Updates:**

- `totalCount`: Always incremented
- `dailyCount`: Incremented once per day
- `weeklyCount`: Incremented once per day (resets weekly)
- `streakCount`: Incremented once per day
- `lastCompleted`: Updated to current server timestamp

### resetDaily

Scheduled function that runs daily at midnight UTC (00:00).

**What it does:**

- Resets all users' `dailyCount` to 0
- Uses batched updates for efficiency (300 users per batch)
- Handles large user bases with pagination

**Schedule:** `0 0 * * *` (every day at 00:00 UTC)

### resetWeekly

Scheduled function that runs weekly on Sundays at 23:59 UTC.

**What it does:**

- Resets all users' `weeklyCount` to 0
- Uses batched updates for efficiency (300 users per batch)
- Handles large user bases with pagination

**Schedule:** `59 23 * * 0` (Sundays at 23:59 UTC)

## Security & Anti-Cheat

The leaderboard system implements several anti-cheat measures to maintain integrity:

### Client-Side Restrictions

- **Counter Fields Protected**: Clients cannot directly write to `totalCount`, `dailyCount`, `weeklyCount`, `streakCount`, or `lastCompleted`
- **Firestore Rules**: Enforced at the database level to prevent unauthorized counter modifications
- **Completion Validation**: Only authenticated users can create completions for themselves

### Server-Side Validation

- **Challenge Validation**: Verifies `challengeId` exists in the challenges collection before processing
- **User Validation**: Ensures user document exists before updating counters
- **One Per Day Rule**: Prevents multiple daily completions from the same user
- **Atomic Operations**: Uses Firestore transactions to prevent race conditions

### Monitoring & Logging

- **Comprehensive Logging**: All operations are logged for security monitoring
- **Error Handling**: Invalid completions are logged and rejected
- **Audit Trail**: Complete history of all counter updates

### Data Integrity

- **Server Timestamps**: All timestamps use server time to prevent client manipulation
- **Atomic Updates**: Counter increments are atomic to prevent partial updates
- **Validation Chain**: Multiple validation layers prevent invalid data from entering the system
