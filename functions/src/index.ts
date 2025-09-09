import * as functions from "firebase-functions"; // Gen1 API
import * as admin from "firebase-admin";
if (!admin.apps.length) admin.initializeApp();

export const onCompletionCreateV5 = functions.firestore
  .document("completions/{completionId}")
  .onCreate(async (snap, ctx) => {
    console.log("🔥 onCompletionCreateV5 (Gen1) LIVE");
    const data = (snap.data() as { userId?: string; challengeId?: string }) || {};
    const uid = data.userId;
    if (!uid) { console.warn("Missing userId on completion", data); return; }
    if (!data.challengeId || data.challengeId.trim() === "") {
      console.warn("Empty challengeId; continuing anyway", { uid, completionId: ctx.params.completionId });
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);

    await db.runTransaction(async (tx) => {
      const userDoc = await tx.get(userRef);
      const nowTs = admin.firestore.Timestamp.now();

      let totalCount = 1;
      let streakCount = 1;

      if (userDoc.exists) {
        const d = userDoc.data() || {};
        const last = d.lastCompleted as admin.firestore.Timestamp | undefined;
        const prevTotal = (d.totalCount as number) ?? 0;
        const prevStreak = (d.streakCount as number) ?? 0;

        const sameDay = (a: admin.firestore.Timestamp, b: admin.firestore.Timestamp) => {
          const A = a.toDate(), B = b.toDate();
          return A.getUTCFullYear() === B.getUTCFullYear()
              && A.getUTCMonth() === B.getUTCMonth()
              && A.getUTCDate() === B.getUTCDate();
        };
        const yesterday = (a: admin.firestore.Timestamp, b: admin.firestore.Timestamp) => {
          const B = b.toDate();
          const prev = new Date(Date.UTC(B.getUTCFullYear(), B.getUTCMonth(), B.getUTCDate() - 1));
          const A = a.toDate();
          return A.getUTCFullYear() === prev.getUTCFullYear()
              && A.getUTCMonth() === prev.getUTCMonth()
              && A.getUTCDate() === prev.getUTCDate();
        };

        totalCount = prevTotal + 1;

        if (last) {
          if (sameDay(last, nowTs)) {
            tx.update(userRef, { lastCompleted: nowTs, totalCount });
            return;
          } else if (yesterday(last, nowTs)) {
            streakCount = prevStreak + 1;
          } else {
            streakCount = 1;
          }
        }
      }

      tx.set(userRef, { userId: uid, lastCompleted: nowTs, totalCount, streakCount }, { merge: true });
    });
  });