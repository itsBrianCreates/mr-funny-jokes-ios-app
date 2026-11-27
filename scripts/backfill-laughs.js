#!/usr/bin/env node
/**
 * Carries Hilarious votes from before 1.4 into each joke's laugh count.
 *
 * Before 1.4 a Hilarious rating was only logged to `rating_events`; nothing wrote
 * the joke's `likes` field, which is what the Laugh button shows. This sets
 * `likes` to the number of devices that rated the joke Hilarious.
 *
 * It sets the number rather than adding to it, so running it twice is safe.
 * `updated_at` is left alone: counts are read live and must not trigger a catalog sync.
 *
 * Usage:
 *   node backfill-laughs.js           # Dry run: prints what would change
 *   node backfill-laughs.js --apply   # Backs up current values, then writes
 *   node backfill-laughs.js --horrible [--apply]   # Same for Horrible votes (`dislikes`)
 */

import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { readFileSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
initializeApp({ credential: cert(JSON.parse(readFileSync(join(__dirname, "serviceAccountKey.json"), "utf8"))) });
const db = getFirestore();

const APPLY = process.argv.includes("--apply");
// --horrible fills `dislikes` from Horrible votes; the default fills `likes` from Hilarious ones
const HORRIBLE = process.argv.includes("--horrible");
const FIELD = HORRIBLE ? "dislikes" : "likes";
const IS_VOTE = (rating) => (HORRIBLE ? rating <= 2 : rating >= 4);

async function main() {
  const [events, jokes] = await Promise.all([
    db.collection("rating_events").get(),
    db.collection("jokes").get(),
  ]);

  // One vote per device per joke, however many weeks they voted in
  const devicesByJoke = {};
  events.forEach((doc) => {
    const event = doc.data();
    if (IS_VOTE(event.rating) && event.joke_id && event.device_id) {
      (devicesByJoke[event.joke_id] ||= new Set()).add(event.device_id);
    }
  });

  const changes = [];
  jokes.forEach((doc) => {
    const laughs = devicesByJoke[doc.id]?.size || 0;
    const current = doc.data()[FIELD] || 0;
    // Never lower a count: a joke may have laughs that logged no event
    if (laughs > current) {
      changes.push({ id: doc.id, from: current, to: laughs, ref: doc.ref });
    }
  });

  const total = changes.reduce((sum, change) => sum + (change.to - change.from), 0);
  console.log(`${FIELD}: ${changes.length} jokes to update, ${total} votes added`);
  console.log(`Highest: ${Math.max(0, ...changes.map((change) => change.to))}`);

  if (!APPLY) {
    console.log("Dry run. Pass --apply to write.");
    return;
  }

  const backupPath = join(__dirname, `${FIELD}-backup-${new Date().toISOString().replace(/[:.]/g, "-")}.json`);
  writeFileSync(backupPath, JSON.stringify(changes.map(({ id, from, to }) => ({ id, from, to })), null, 2));
  console.log(`Backup: ${backupPath}`);

  for (let start = 0; start < changes.length; start += 400) {
    const batch = db.batch();
    for (const change of changes.slice(start, start + 400)) {
      batch.update(change.ref, { [FIELD]: change.to });
    }
    await batch.commit();
  }
  console.log("Done.");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
