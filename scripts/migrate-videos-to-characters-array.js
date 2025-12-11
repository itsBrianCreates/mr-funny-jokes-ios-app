/**
 * Migration Script: Add 'characters' array to existing videos
 *
 * This script updates all existing video documents in Firestore to include
 * the new 'characters' array field based on their existing 'character' field.
 *
 * Usage:
 *   node migrate-videos-to-characters-array.js             # Run migration
 *   node migrate-videos-to-characters-array.js --dry-run   # Preview changes without modifying
 *
 * Requirements:
 *   - Firebase service account key file: ./serviceAccountKey.json
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const COLLECTION_NAME = 'videos';
const BATCH_SIZE = 500;

// Parse command line arguments
const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');

// Logging utilities
const log = {
  info: (msg) => console.log(`[INFO] ${msg}`),
  warn: (msg) => console.log(`[WARN] ${msg}`),
  error: (msg) => console.error(`[ERROR] ${msg}`),
  success: (msg) => console.log(`[SUCCESS] ${msg}`),
  divider: () => console.log('='.repeat(60))
};

/**
 * Initialize Firebase Admin SDK
 */
function initializeFirebase() {
  const serviceAccountPath = join(__dirname, 'serviceAccountKey.json');

  if (!existsSync(serviceAccountPath)) {
    throw new Error(
      'Service account key not found!\n' +
      'Please place serviceAccountKey.json in the scripts/ directory.'
    );
  }

  const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));

  initializeApp({
    credential: cert(serviceAccount)
  });

  log.info(`Connected to project: ${serviceAccount.project_id}`);
  return getFirestore();
}

/**
 * Migrate videos to include characters array
 */
async function migrateVideos(db) {
  log.divider();
  log.info('MIGRATING VIDEOS TO CHARACTERS ARRAY FORMAT');
  log.divider();

  if (DRY_RUN) {
    log.warn('DRY RUN MODE - No changes will be made\n');
  }

  // Fetch all videos
  const snapshot = await db.collection(COLLECTION_NAME).get();
  log.info(`Found ${snapshot.size} total videos\n`);

  const needsMigration = [];
  const alreadyMigrated = [];
  const errors = [];

  // Check each document
  snapshot.forEach(doc => {
    const data = doc.data();

    if (data.characters && Array.isArray(data.characters) && data.characters.length > 0) {
      alreadyMigrated.push({ id: doc.id, title: data.title });
    } else if (data.character) {
      needsMigration.push({
        id: doc.id,
        title: data.title,
        character: data.character
      });
    } else {
      errors.push({ id: doc.id, title: data.title, reason: 'No character field' });
    }
  });

  log.info(`Already migrated: ${alreadyMigrated.length}`);
  log.info(`Needs migration: ${needsMigration.length}`);
  if (errors.length > 0) {
    log.warn(`Errors: ${errors.length}`);
  }
  console.log('');

  if (needsMigration.length === 0) {
    log.success('All videos are already migrated!');
    return { migrated: 0, skipped: alreadyMigrated.length, errors: errors.length };
  }

  // Preview migrations
  log.info('Videos to migrate:');
  needsMigration.forEach(video => {
    log.info(`  - "${video.title}" (${video.id}): character="${video.character}" → characters=["${video.character}"]`);
  });
  console.log('');

  if (DRY_RUN) {
    log.warn('DRY RUN - No changes made');
    return { migrated: 0, skipped: alreadyMigrated.length, errors: errors.length };
  }

  // Perform migration in batches
  let migratedCount = 0;

  for (let i = 0; i < needsMigration.length; i += BATCH_SIZE) {
    const batchVideos = needsMigration.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const video of batchVideos) {
      const docRef = db.collection(COLLECTION_NAME).doc(video.id);
      batch.update(docRef, {
        characters: [video.character],
        updated_at: FieldValue.serverTimestamp()
      });
    }

    await batch.commit();
    migratedCount += batchVideos.length;
    log.info(`Migrated batch ${Math.floor(i / BATCH_SIZE) + 1}: ${batchVideos.length} videos`);
  }

  return { migrated: migratedCount, skipped: alreadyMigrated.length, errors: errors.length };
}

/**
 * Main execution
 */
async function main() {
  log.divider();
  log.info('VIDEO MIGRATION SCRIPT');
  log.info(`Mode: ${DRY_RUN ? 'DRY RUN' : 'LIVE'}`);
  log.divider();

  try {
    const db = initializeFirebase();
    const result = await migrateVideos(db);

    log.divider();
    log.success('MIGRATION COMPLETE!');
    log.info(`  Migrated: ${result.migrated}`);
    log.info(`  Already up-to-date: ${result.skipped}`);
    if (result.errors > 0) {
      log.warn(`  Errors: ${result.errors}`);
    }
    log.divider();

  } catch (error) {
    log.error(`Migration failed: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

main();
