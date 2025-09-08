import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// Helper functions for date calculations (currently unused but available for future use)
// function startOfTodayUTC(): Date {
//   const d = new Date();
//   d.setUTCHours(0, 0, 0, 0);
//   return d;
// }

// function startOfWeekUTC(): Date {
//   const d = new Date();
//   const day = d.getUTCDay(); // 0=Sun
//   const diff = day; // week starts Sunday
//   d.setUTCDate(d.getUTCDate() - diff);
//   d.setUTCHours(0, 0, 0, 0);
//   return d;
// }

exports.onCompletionCreate = functions.firestore
  .document("completions/{completionId}")
  .onCreate(async (snap) => {
    const data = snap.data();
    const userId = data.userId as string;
    if (!userId) return;

    const userRef = db.collection("users").doc(userId);
    await db.runTransaction(async (txn) => {
      const userSnap = await txn.get(userRef);
      const user = userSnap.data() || {};
      const lastCompleted: admin.firestore.Timestamp | null = user.lastCompleted || null;

      const now = new Date();

      // detect if lastCompleted is already today (prevent multi-increment abuse)
      const isSameDay =
        lastCompleted?.toDate().getUTCFullYear() === now.getUTCFullYear() &&
        lastCompleted?.toDate().getUTCMonth() === now.getUTCMonth() &&
        lastCompleted?.toDate().getUTCDate() === now.getUTCDate();

      const updates: admin.firestore.UpdateData<admin.firestore.DocumentData> = {
        totalCount: admin.firestore.FieldValue.increment(1),
        lastCompleted: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Only increment daily/weekly once per day? (optional)
      // For a single daily challenge, you usually want 1 increment per day:
      if (!isSameDay) {
        updates["dailyCount"] = admin.firestore.FieldValue.increment(1);
        updates["weeklyCount"] = admin.firestore.FieldValue.increment(1);
        updates["streakCount"] = admin.firestore.FieldValue.increment(1);
      }

      txn.update(userRef, updates);
    });
  });

// Daily reset - set all dailyCount = 0 at midnight UTC
exports.resetDaily = functions.pubsub
  .schedule("0 0 * * *") // every day 00:00 UTC
  .onRun(async () => {
    const usersRef = db.collection("users");
    const batchSize = 300; // page through
    let last: FirebaseFirestore.QueryDocumentSnapshot | null = null;
    while (true) {
      let q = usersRef.orderBy(admin.firestore.FieldPath.documentId()).limit(batchSize);
      if (last) q = q.startAfter(last.id);
      const snap = await q.get();
      if (snap.empty) break;

      const batch = db.batch();
      snap.docs.forEach(doc => batch.update(doc.ref, { dailyCount: 0 }));
      await batch.commit();
      last = snap.docs[snap.docs.length - 1];
    }
  });

// Weekly reset - set all weeklyCount = 0 on Sundays at 23:59 UTC
exports.resetWeekly = functions.pubsub
  .schedule("59 23 * * 0") // Sundays 23:59 UTC
  .onRun(async () => {
    const usersRef = db.collection("users");
    const batchSize = 300;
    let last: FirebaseFirestore.QueryDocumentSnapshot | null = null;
    while (true) {
      let q = usersRef.orderBy(admin.firestore.FieldPath.documentId()).limit(batchSize);
      if (last) q = q.startAfter(last.id);
      const snap = await q.get();
      if (snap.empty) break;

      const batch = db.batch();
      snap.docs.forEach(doc => batch.update(doc.ref, { weeklyCount: 0 }));
      await batch.commit();
      last = snap.docs[snap.docs.length - 1];
    }
  });
