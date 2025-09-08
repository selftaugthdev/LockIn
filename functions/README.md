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

**What it does:**

- Increments `totalCount` for the user
- Increments `dailyCount` and `weeklyCount` if it's a new day
- Updates `lastCompleted` timestamp
- Prevents multiple increments per day (one completion per day rule)

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
