#!/usr/bin/env node
/**
 * Fix the tags on specific jokes, in place.
 *
 * Tags show up in the app as topic chips and decide which topic page a joke is on,
 * so a wrong tag is a visible mistake. This applies a reviewed list of corrections.
 *
 * Only the `tags` field (and `updated_at`) of existing documents is written.
 * `updated_at` must move: installed apps sync only jokes whose `updated_at`
 * changed. Document IDs, text and ratings are untouched.
 *
 * Usage:
 *   node retag-jokes.js <plan.json> --backup <file.json>            (dry run)
 *   node retag-jokes.js <plan.json> --backup <file.json> --apply
 *
 * plan.json: [{ "id": "<doc id>", "remove": ["tag"], "add": ["tag"], "note": "why" }]
 * A joke left with no tags gets "wordplay", the catch-all.
 */
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const planPath = args[0];
const backupPath = args[args.indexOf('--backup') + 1];
const APPLY = args.includes('--apply');

if (!planPath || !args.includes('--backup') || !backupPath) {
  console.error('Usage: node retag-jokes.js <plan.json> --backup <file.json> [--apply]');
  process.exit(1);
}

initializeApp({ credential: cert(JSON.parse(readFileSync(join(__dirname, 'serviceAccountKey.json'), 'utf8'))) });
const db = getFirestore();
const plan = JSON.parse(readFileSync(planPath, 'utf8'));

const snapshot = await db.collection('jokes').get();
const current = new Map(snapshot.docs.map(doc => [doc.id, doc.data()]));

if (APPLY && !existsSync(backupPath)) {
  writeFileSync(backupPath, JSON.stringify(snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })), null, 1));
  console.log(`Backed up ${snapshot.size} jokes to ${backupPath}`);
}

const updates = [];
for (const entry of plan) {
  const doc = current.get(entry.id);
  if (!doc) { console.warn(`SKIP ${entry.id}: not found`); continue; }

  const oldTags = Array.isArray(doc.tags) ? doc.tags : [];
  const missing = (entry.remove || []).filter(tag => !oldTags.includes(tag));
  if (missing.length) { console.warn(`SKIP ${entry.id}: no longer tagged ${missing.join(', ')}`); continue; }

  let newTags = oldTags.filter(tag => !(entry.remove || []).includes(tag));
  for (const tag of entry.add || []) {
    if (!newTags.includes(tag)) newTags.push(tag);
  }
  if (newTags.length === 0) newTags = ['wordplay'];

  if (JSON.stringify(newTags) === JSON.stringify(oldTags)) continue;
  updates.push({ id: entry.id, tags: newTags });
  const text = String(doc.text).replace(/\s+/g, ' ').slice(0, 50);
  console.log(`${entry.id.slice(0, 6)}  [${oldTags.join(', ')}] -> [${newTags.join(', ')}]  ${text}`);
}

console.log(`${updates.length} of ${plan.length} planned changes are valid. ${APPLY ? 'Applying…' : 'Dry run, nothing written.'}`);

if (APPLY) {
  for (let i = 0; i < updates.length; i += 400) {
    const batch = db.batch();
    for (const entry of updates.slice(i, i + 400)) {
      batch.update(db.collection('jokes').doc(entry.id), { tags: entry.tags, updated_at: FieldValue.serverTimestamp() });
    }
    await batch.commit();
    console.log(`Committed ${Math.min(i + 400, updates.length)}/${updates.length}`);
  }
}
