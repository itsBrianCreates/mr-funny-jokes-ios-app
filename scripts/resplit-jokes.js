#!/usr/bin/env node
/**
 * Re-split joke text so a blank line marks where the punchline starts.
 *
 * Only the `text` field (and `updated_at`) of existing documents is written.
 * Document IDs, ratings, likes and popularity are untouched, so saved jokes,
 * user ratings and the rankings keep pointing at the same jokes.
 *
 * Usage:
 *   node resplit-jokes.js <plan.json> --backup <file.json>            (dry run)
 *   node resplit-jokes.js <plan.json> --backup <file.json> --apply
 *
 * plan.json: [{ "id": "<doc id>", "old": "<current text>", "text": "<new text>" }]
 * A document whose current text no longer matches "old" is skipped.
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
  console.error('Usage: node resplit-jokes.js <plan.json> --backup <file.json> [--apply]');
  process.exit(1);
}

initializeApp({ credential: cert(JSON.parse(readFileSync(join(__dirname, 'serviceAccountKey.json'), 'utf8'))) });
const db = getFirestore();
const plan = JSON.parse(readFileSync(planPath, 'utf8'));

const snapshot = await db.collection('jokes').get();
const current = new Map(snapshot.docs.map(doc => [doc.id, doc.data()]));

if (!existsSync(backupPath)) {
  writeFileSync(backupPath, JSON.stringify(snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })), null, 1));
  console.log(`Backed up ${snapshot.size} jokes to ${backupPath}`);
}

const collapse = s => s.replace(/\s+/g, ' ').trim();
const updates = [];
for (const entry of plan) {
  const doc = current.get(entry.id);
  if (!doc) { console.warn(`SKIP ${entry.id}: not found`); continue; }
  if (doc.text !== entry.old) { console.warn(`SKIP ${entry.id}: text changed since the plan was made`); continue; }
  // The wording must be identical; only whitespace may differ
  const sameWords = collapse(entry.text) === collapse(doc.text) ||
    collapse(entry.text.replace('\n\n', '')) === collapse(doc.text);
  if (!sameWords) { console.warn(`SKIP ${entry.id}: plan changes the wording`); continue; }
  updates.push(entry);
}

console.log(`${updates.length} of ${plan.length} planned updates are valid. ${APPLY ? 'Applying…' : 'Dry run, nothing written.'}`);

if (APPLY) {
  for (let i = 0; i < updates.length; i += 400) {
    const batch = db.batch();
    for (const entry of updates.slice(i, i + 400)) {
      batch.update(db.collection('jokes').doc(entry.id), { text: entry.text, updated_at: FieldValue.serverTimestamp() });
    }
    await batch.commit();
    console.log(`Committed ${Math.min(i + 400, updates.length)}/${updates.length}`);
  }
}
