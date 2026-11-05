/**
 * Holiday Tag Migration Script
 *
 * Migrates jokes with the generic "holidays" tag to specific holiday tags
 * (christmas, halloween, thanksgiving) based on joke text content.
 *
 * Usage:
 *   node migrate-holiday-tags.js              # Full migration
 *   node migrate-holiday-tags.js --dry-run    # Simulate without changes
 *
 * Requirements:
 *   - Firebase service account key file: ./serviceAccountKey.json
 *   - Or set GOOGLE_APPLICATION_CREDENTIALS environment variable
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const COLLECTION_NAME = 'jokes';
const BATCH_SIZE = 500;

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');

// Logging utilities
const log = {
  info: (msg) => console.log(`[INFO] ${new Date().toISOString()} - ${msg}`),
  warn: (msg) => console.log(`[WARN] ${new Date().toISOString()} - ${msg}`),
  error: (msg) => console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`),
  success: (msg) => console.log(`[SUCCESS] ${new Date().toISOString()} - ${msg}`),
  divider: () => console.log('='.repeat(70))
};

// Keyword patterns (matched case-insensitively against joke text)
const CHRISTMAS_KEYWORDS = [
  'santa', 'reindeer', 'elves', 'elf', 'christmas', 'stocking',
  'rudolph', 'north pole', 'ho ho ho', 'mistletoe', 'snowman',
  'grinch', 'jingle', 'carol', 'december 25', 'xmas', 'noel',
  'scrooge', 'frosty', 'nutcracker', 'sleigh', 'jesus', 'nativity',
  'manger', 'bethlehem', 'wise men'
];

const HALLOWEEN_KEYWORDS = [
  'ghost', 'skeleton', 'vampire', 'witch', 'zombie', 'pumpkin',
  'halloween', 'haunted', 'trick or treat', 'candy corn', 'werewolf',
  'mummy', 'frankenstein', 'spooky', 'jack-o-lantern', 'costume',
  'cobweb', 'cauldron', 'goblin', 'ghoul'
];

const THANKSGIVING_KEYWORDS = [
  'thanksgiving', 'turkey', 'pilgrim', 'gratitude', 'thankful',
  'cornucopia', 'stuffing', 'cranberry', 'feast', 'gobble',
  'mayflower', 'plymouth'
];

/**
 * Initialize Firebase Admin SDK
 */
function initializeFirebase() {
  log.info('Initializing Firebase Admin SDK...');

  const serviceAccountPath = join(__dirname, 'serviceAccountKey.json');

  if (existsSync(serviceAccountPath)) {
    log.info(`Loading service account from: ${serviceAccountPath}`);
    const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));

    initializeApp({
      credential: cert(serviceAccount)
    });

    log.info(`Connected to project: ${serviceAccount.project_id}`);
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    log.info(`Using GOOGLE_APPLICATION_CREDENTIALS: ${process.env.GOOGLE_APPLICATION_CREDENTIALS}`);
    initializeApp();
  } else {
    throw new Error(
      'No Firebase credentials found!\n' +
      'Please either:\n' +
      '  1. Place serviceAccountKey.json in the scripts/ directory\n' +
      '  2. Set GOOGLE_APPLICATION_CREDENTIALS environment variable\n\n' +
      'To get a service account key:\n' +
      '  1. Go to Firebase Console > Project Settings > Service Accounts\n' +
      '  2. Click "Generate new private key"\n' +
      '  3. Save the JSON file as scripts/serviceAccountKey.json'
    );
  }

  return getFirestore();
}

/**
 * Fetch all jokes from Firestore
 */
async function fetchAllJokes(db) {
  log.info(`Fetching all documents from '${COLLECTION_NAME}' collection...`);

  const snapshot = await db.collection(COLLECTION_NAME).get();
  const jokes = [];

  snapshot.forEach(doc => {
    jokes.push({
      id: doc.id,
      ...doc.data()
    });
  });

  log.info(`Found ${jokes.length} jokes in the collection`);
  return jokes;
}

/**
 * Check if text matches any keyword in a list (case-insensitive)
 */
function matchesKeywords(text, keywords) {
  const lower = text.toLowerCase();
  return keywords.some(keyword => lower.includes(keyword));
}

/**
 * Determine which specific holiday tag to assign based on joke text.
 * Returns the new tag name, or null if no specific holiday match.
 */
function detectHoliday(text) {
  if (matchesKeywords(text, CHRISTMAS_KEYWORDS)) return 'christmas';
  if (matchesKeywords(text, HALLOWEEN_KEYWORDS)) return 'halloween';
  if (matchesKeywords(text, THANKSGIVING_KEYWORDS)) return 'thanksgiving';
  return null;
}

/**
 * Compute new tags array for a joke. Returns null if no change needed.
 */
function computeNewTags(joke) {
  const tags = joke.tags || [];
  if (!tags.includes('holidays')) return null;

  const text = joke.text || '';
  const holidayTag = detectHoliday(text);

  if (!holidayTag) return null; // Keep generic "holidays"

  // Replace "holidays" with the specific holiday tag
  const newTags = tags.map(t => (t === 'holidays' ? holidayTag : t));

  // Deduplicate in case the specific tag already existed
  return [...new Set(newTags)];
}

/**
 * Run the migration
 */
async function migrate(db, jokes) {
  const changes = [];

  for (const joke of jokes) {
    const newTags = computeNewTags(joke);
    if (newTags) {
      changes.push({ id: joke.id, text: joke.text, oldTags: joke.tags, newTags });
    }
  }

  if (changes.length === 0) {
    log.info('No jokes need tag migration.');
    return { christmas: 0, halloween: 0, thanksgiving: 0, unchanged: jokes.filter(j => (j.tags || []).includes('holidays')).length };
  }

  log.divider();
  log.info(`${changes.length} jokes will be updated:`);
  log.divider();

  const counts = { christmas: 0, halloween: 0, thanksgiving: 0 };

  for (const change of changes) {
    const added = change.newTags.find(t => ['christmas', 'halloween', 'thanksgiving'].includes(t) && !change.oldTags.includes(t));
    const replaced = change.oldTags.includes('holidays') && !change.newTags.includes('holidays');
    const tag = replaced ? change.newTags.find(t => ['christmas', 'halloween', 'thanksgiving'].includes(t)) : added;

    if (tag) counts[tag]++;

    const preview = change.text.length > 60 ? change.text.substring(0, 60) + '...' : change.text;
    log.info(`  [${change.id}] holidays -> ${tag} | "${preview}"`);
  }

  if (DRY_RUN) {
    log.warn('DRY RUN - No changes written to Firestore');
  } else {
    log.info('Writing changes to Firestore...');

    for (let i = 0; i < changes.length; i += BATCH_SIZE) {
      const batch = db.batch();
      const chunk = changes.slice(i, i + BATCH_SIZE);

      for (const change of chunk) {
        const docRef = db.collection(COLLECTION_NAME).doc(change.id);
        batch.update(docRef, { tags: change.newTags });
      }

      await batch.commit();
      log.info(`  Committed batch ${Math.floor(i / BATCH_SIZE) + 1} (${chunk.length} docs)`);
    }

    log.success('All changes written successfully');
  }

  const unchangedHoliday = jokes.filter(j => {
    const tags = j.tags || [];
    return tags.includes('holidays') && !changes.find(c => c.id === j.id);
  }).length;

  return { ...counts, unchanged: unchangedHoliday };
}

/**
 * Main execution
 */
async function main() {
  log.divider();
  log.info('HOLIDAY TAG MIGRATION SCRIPT');
  log.info(`Mode: ${DRY_RUN ? 'DRY RUN' : 'LIVE MIGRATION'}`);
  log.divider();

  try {
    const db = initializeFirebase();
    const jokes = await fetchAllJokes(db);

    if (jokes.length === 0) {
      log.warn('No jokes found in the collection!');
      process.exit(1);
    }

    const holidayJokes = jokes.filter(j => (j.tags || []).includes('holidays'));
    log.info(`Found ${holidayJokes.length} jokes with "holidays" tag`);

    const result = await migrate(db, jokes);

    log.divider();
    log.success('MIGRATION SUMMARY');
    log.info(`  christmas:    ${result.christmas}`);
    log.info(`  halloween:    ${result.halloween}`);
    log.info(`  thanksgiving: ${result.thanksgiving}`);
    log.info(`  unchanged:    ${result.unchanged} (kept generic "holidays")`);
    if (DRY_RUN) {
      log.warn('  This was a DRY RUN - no actual changes were made');
    }
    log.divider();

  } catch (error) {
    log.error(`Migration failed: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

main();
