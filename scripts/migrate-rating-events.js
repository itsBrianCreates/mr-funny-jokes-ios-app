/**
 * Rating Events Migration Script
 *
 * Migrates rating_events from 5-point scale to binary format:
 *   - Rating 4 or 5 -> 5 (Hilarious)
 *   - Rating 1 or 2 -> 1 (Horrible)
 *   - Rating 3 -> DELETE document entirely
 *
 * Usage:
 *   node migrate-rating-events.js              # Full migration
 *   node migrate-rating-events.js --dry-run    # Simulate without changes
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

const COLLECTION_NAME = 'rating_events';
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
 * Fetch all rating events from Firestore
 */
async function fetchAllRatingEvents(db) {
  log.info(`Fetching all documents from '${COLLECTION_NAME}' collection...`);

  const snapshot = await db.collection(COLLECTION_NAME).get();
  const events = [];

  snapshot.forEach(doc => {
    events.push({
      id: doc.id,
      ...doc.data()
    });
  });

  log.info(`Found ${events.length} rating events in the collection`);
  return events;
}

/**
 * Determine the migration action for a rating value.
 * Returns: { action: 'update'|'delete'|'skip', newRating?: number }
 */
function migrateRating(currentRating) {
  if (currentRating === 5 || currentRating === 1) {
    return { action: 'skip' }; // Already binary
  }
  if (currentRating === 4) {
    return { action: 'update', newRating: 5 }; // -> Hilarious
  }
  if (currentRating === 2) {
    return { action: 'update', newRating: 1 }; // -> Horrible
  }
  if (currentRating === 3) {
    return { action: 'delete' }; // Neutral -> remove
  }
  // Unexpected value, skip
  return { action: 'skip' };
}

/**
 * Run the migration
 */
async function migrate(db, events) {
  const updates = [];   // { id, oldRating, newRating }
  const deletes = [];   // { id, rating }
  let skippedCount = 0;

  for (const event of events) {
    const rating = event.rating;
    const result = migrateRating(rating);

    if (result.action === 'update') {
      updates.push({ id: event.id, oldRating: rating, newRating: result.newRating });
    } else if (result.action === 'delete') {
      deletes.push({ id: event.id, rating });
    } else {
      skippedCount++;
    }
  }

  const totalChanges = updates.length + deletes.length;

  if (totalChanges === 0) {
    log.info('No rating events need migration. All ratings are already binary.');
    return {
      total: events.length,
      remappedHilarious: 0,
      remappedHorrible: 0,
      deleted: 0,
      skipped: skippedCount
    };
  }

  log.divider();
  log.info(`${totalChanges} documents will be modified:`);
  log.info(`  ${updates.filter(u => u.newRating === 5).length} remapped to Hilarious (5)`);
  log.info(`  ${updates.filter(u => u.newRating === 1).length} remapped to Horrible (1)`);
  log.info(`  ${deletes.length} deleted (rating 3)`);
  log.info(`  ${skippedCount} skipped (already binary)`);
  log.divider();

  // Log individual changes
  for (const update of updates) {
    log.info(`  [UPDATE] ${update.id}: rating ${update.oldRating} -> ${update.newRating}`);
  }
  for (const del of deletes) {
    log.info(`  [DELETE] ${del.id}: rating ${del.rating} -> removed`);
  }

  if (DRY_RUN) {
    log.warn('DRY RUN - No changes written to Firestore');
  } else {
    log.info('Writing changes to Firestore...');

    // Combine updates and deletes into batches
    const allOperations = [
      ...updates.map(u => ({ type: 'update', ...u })),
      ...deletes.map(d => ({ type: 'delete', ...d }))
    ];

    for (let i = 0; i < allOperations.length; i += BATCH_SIZE) {
      const batch = db.batch();
      const chunk = allOperations.slice(i, i + BATCH_SIZE);

      for (const op of chunk) {
        const docRef = db.collection(COLLECTION_NAME).doc(op.id);

        if (op.type === 'update') {
          batch.update(docRef, { rating: op.newRating });
        } else if (op.type === 'delete') {
          batch.delete(docRef);
        }
      }

      await batch.commit();
      log.info(`  Committed batch ${Math.floor(i / BATCH_SIZE) + 1} (${chunk.length} operations)`);
    }

    log.success('All changes written successfully');
  }

  return {
    total: events.length,
    remappedHilarious: updates.filter(u => u.newRating === 5).length,
    remappedHorrible: updates.filter(u => u.newRating === 1).length,
    deleted: deletes.length,
    skipped: skippedCount
  };
}

/**
 * Main execution
 */
async function main() {
  log.divider();
  log.info('RATING EVENTS MIGRATION SCRIPT');
  log.info('Migrating from 5-point scale to binary (Hilarious=5, Horrible=1)');
  log.info(`Mode: ${DRY_RUN ? 'DRY RUN' : 'LIVE MIGRATION'}`);
  log.divider();

  try {
    const db = initializeFirebase();
    const events = await fetchAllRatingEvents(db);

    if (events.length === 0) {
      log.warn('No rating events found in the collection!');
      process.exit(0);
    }

    const result = await migrate(db, events);

    log.divider();
    log.success('MIGRATION SUMMARY');
    log.info(`  Total documents:       ${result.total}`);
    log.info(`  Remapped to Hilarious: ${result.remappedHilarious}`);
    log.info(`  Remapped to Horrible:  ${result.remappedHorrible}`);
    log.info(`  Deleted (rating 3):    ${result.deleted}`);
    log.info(`  Skipped (already ok):  ${result.skipped}`);
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
