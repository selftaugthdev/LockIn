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

  const data = snap.data() as { userId?: string; challengeId?: string; challengeTitle?: string; customAura?: number } | undefined;
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
    let auraPoints = 0;

    // Calculate aura points for this challenge
    if (data?.challengeId) {
      console.log("🔍 Challenge ID:", data.challengeId);
      console.log("🔍 Custom Aura from completion:", data.customAura);
      
      // Use customAura from completion data if available
      if (data.customAura) {
        auraPoints = data.customAura;
        console.log("✅ Using customAura from completion data:", auraPoints);
      } else {
        // Check if it's a custom challenge
        if (!data.challengeId.startsWith("preloaded_") && !data.challengeId.startsWith("sample_")) {
          // Try to get custom challenge data
          try {
            const customChallengeQuery = db.collection("customChallenges")
              .where("id", "==", data.challengeId)
              .where("userId", "==", uid)
              .limit(1);
            
            const customSnapshot = await customChallengeQuery.get();
            if (!customSnapshot.empty) {
              const customData = customSnapshot.docs[0].data();
              auraPoints = customData.customAura || 20; // Default to 20 for custom challenges
            } else {
              auraPoints = 20; // Default aura for custom challenges
            }
          } catch (error) {
            console.warn("Error fetching custom challenge data:", error);
            auraPoints = 20; // Default aura for custom challenges
          }
        } else {
          // Preloaded challenge - calculate based on difficulty (assuming difficulty is in challengeId or we can estimate)
          auraPoints = 20; // Default for preloaded challenges
        }
      }
    }

    if (userDoc.exists) {
      const d = userDoc.data() || {};
      const last = d.lastCompleted as Timestamp | undefined;
      const prevTotal = (d.totalCount as number) ?? 0;
      const prevStreak = (d.streakCount as number) ?? 0;
      const prevAura = (d.totalAura as number) ?? 0;

      if (last && isSameUtcDay(last, nowTs)) {
        // Same UTC day: do NOT bump totals or streaks, but still add aura
        tx.update(userRef, { 
          lastCompleted: nowTs,
          totalAura: prevAura + auraPoints
        });
        return;
      }

      // New day → bump totals
      totalCount = prevTotal + 1;
      streakCount = last && isYesterdayUtc(last, nowTs) ? prevStreak + 1 : 1;
    }

    const finalAura = (userDoc.exists ? (userDoc.data()?.totalAura as number) ?? 0 : 0) + auraPoints;
    console.log("🔍 Final aura calculation:", finalAura, "(previous:", (userDoc.data()?.totalAura as number) ?? 0, "+ new:", auraPoints, ")");
    
    tx.set(userRef, {
      userId: uid,
      lastCompleted: nowTs,
      totalCount,
      streakCount,
      totalAura: finalAura,
    }, { merge: true });
  });
});