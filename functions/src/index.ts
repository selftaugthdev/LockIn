// Gen2 + Node 20
import { setGlobalOptions } from "firebase-functions/v2";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";

// Region for Firestore in nam5 (US multi-region) ⇒ us-central1
setGlobalOptions({ region: "us-central1", timeoutSeconds: 60 });

initializeApp();

const db = getFirestore();

function isSameUtcDay(a: Timestamp, b: Timestamp): boolean {
  const A = a.toDate(), B = b.toDate();
  return A.getUTCFullYear() === B.getUTCFullYear()
      && A.getUTCMonth() === B.getUTCMonth()
      && A.getUTCDate() === B.getUTCDate();
}
function isYesterdayUtc(a: Timestamp, b: Timestamp): boolean {
  const B = b.toDate();
  const prev = new Date(Date.UTC(B.getUTCFullYear(), B.getUTCMonth(), B.getUTCDate() - 1));
  const A = a.toDate();
  return A.getUTCFullYear() === prev.getUTCFullYear()
      && A.getUTCMonth() === prev.getUTCMonth()
      && A.getUTCDate() === prev.getUTCDate();
}

// Keep the name NEW to avoid any Gen1 residue firing in parallel
export const onCompletionCreateV6 = onDocumentCreated("completions/{completionId}", async (event) => {
  console.log("🚀 onCompletionCreateV6 (Gen2/Node20)");

  const snap = event.data;
  if (!snap) return;

  const data = snap.data() as { userId?: string; challengeId?: string } | undefined;
  const uid = data?.userId;
  if (!uid) { console.warn("Missing userId on completion", data); return; }
  if (!data?.challengeId || data.challengeId.trim() === "") {
    console.warn("Empty challengeId; continuing anyway", { uid, completionId: event.params.completionId });
  }

  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const userDoc = await tx.get(userRef);
    const nowTs = Timestamp.now();

    let totalCount = 1;
    let streakCount = 1;

    if (userDoc.exists) {
      const d = userDoc.data() || {};
      const last = d.lastCompleted as Timestamp | undefined;
      const prevTotal = (d.totalCount as number) ?? 0;
      const prevStreak = (d.streakCount as number) ?? 0;

      if (last && isSameUtcDay(last, nowTs)) {
        // Same UTC day: do NOT bump totals or streaks
        tx.update(userRef, { lastCompleted: nowTs }); // optional refresh
        return;
      }

      // New day → bump totals
      totalCount = prevTotal + 1;
      streakCount = last && isYesterdayUtc(last, nowTs) ? prevStreak + 1 : 1;
    }

    tx.set(userRef, {
      userId: uid,
      lastCompleted: nowTs,
      totalCount,
      streakCount,
    }, { merge: true });
  });
});