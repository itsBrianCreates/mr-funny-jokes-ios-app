#!/usr/bin/env node
/**
 * Merge stray joke tags into the official ones, so topic browsing in the app
 * finds every joke.
 *
 * Only the `tags` field (and `updated_at`) of existing documents is written.
 * `updated_at` must move: installed apps sync only jokes whose `updated_at`
 * changed. Document IDs, text and ratings are untouched.
 *
 * Usage:
 *   node normalize-tags.js --backup <file.json>            (dry run)
 *   node normalize-tags.js --backup <file.json> --apply
 */
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

// Stray tag -> official tag. A tag mapped to null is dropped: it describes the
// joke's style, not a subject anyone would browse by.
const RENAME = {
  tech: 'technology',
  romance: 'romantic',
  relationships: 'romantic',
  sweet: 'romantic',
  mental_health: 'health',
  clever: null,
  classic: null,
};

// Tags the app or the joke scripts know about. Anything else left after the
// renames is reported, not changed.
const OFFICIAL = new Set([
  'animals', 'food', 'work', 'school', 'sports', 'music', 'technology', 'science',
  'health', 'weather', 'holidays', 'halloween', 'thanksgiving', 'christmas',
  'family', 'travel', 'wordplay', 'religious', 'romantic', 'nature', 'movies',
]);

const __dirname = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const backupPath = args[args.indexOf('--backup') + 1];
const APPLY = args.includes('--apply');

if (!args.includes('--backup') || !backupPath) {
  console.error('Usage: node normalize-tags.js --backup <file.json> [--apply]');
  process.exit(1);
}

initializeApp({ credential: cert(JSON.parse(readFileSync(join(__dirname, 'serviceAccountKey.json'), 'utf8'))) });
const db = getFirestore();
const snapshot = await db.collection('jokes').get();

if (APPLY && !existsSync(backupPath)) {
  writeFileSync(backupPath, JSON.stringify(snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })), null, 1));
  console.log(`Backed up ${snapshot.size} jokes to ${backupPath}`);
}

const updates = [];
const changes = {};
const leftovers = {};

for (const doc of snapshot.docs) {
  const oldTags = Array.isArray(doc.data().tags) ? doc.data().tags : [];
  const newTags = [];
  for (const tag of oldTags) {
    const mapped = tag in RENAME ? RENAME[tag] : tag;
    if (mapped !== tag) {
      const label = `${tag} -> ${mapped ?? '(dropped)'}`;
      changes[label] = (changes[label] || 0) + 1;
    }
    if (mapped && !newTags.includes(mapped)) newTags.push(mapped);
  }
  for (const tag of newTags) {
    if (!OFFICIAL.has(tag)) leftovers[tag] = (leftovers[tag] || 0) + 1;
  }
  // Never leave a joke with no tags because its only tag was a dropped one
  if (newTags.length === 0 && oldTags.length > 0) continue;
  if (JSON.stringify(newTags) !== JSON.stringify(oldTags)) {
    updates.push({ id: doc.id, tags: newTags });
  }
}

console.log(`${snapshot.size} jokes read.`);
console.log('Tag changes:', changes);
console.log('Left as they are (not official, no rule):', leftovers);
console.log(`${updates.length} jokes to update. ${APPLY ? 'Applying…' : 'Dry run, nothing written.'}`);

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
