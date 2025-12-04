/**
 * Firestore Jokes Migration Script
 *
 * Migrates jokes from category-based IDs (bad_001, dad_001, etc.)
 * to auto-generated Firestore IDs.
 *
 * Usage:
 *   node migrate-joke-ids.js                 # Full migration
 *   node migrate-joke-ids.js --backup-only   # Only create backup
 *   node migrate-joke-ids.js --verify-only   # Only verify current state
 *   node migrate-joke-ids.js --dry-run       # Simulate migration without changes
 *
 * Requirements:
 *   - Firebase service account key file: ./serviceAccountKey.json
 *   - Or set GOOGLE_APPLICATION_CREDENTIALS environment variable
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const COLLECTION_NAME = 'jokes';
const BATCH_SIZE = 500; // Firestore batch limit is 500

// Skeleton joke fix configuration
const SKELETON_JOKE_FIX = {
  text: "Why don't skeletons fight each other? They don't have the guts.",
  newCharacter: 'mr_funny',
  newType: 'dad_joke'
};

// Parse command line arguments
const args = process.argv.slice(2);
const BACKUP_ONLY = args.includes('--backup-only');
const VERIFY_ONLY = args.includes('--verify-only');
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

  // Try to load service account from file
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
 * Create a backup of all jokes
 */
function createBackup(jokes) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupFilename = `jokes-backup-${timestamp}.json`;
  const backupPath = join(__dirname, backupFilename);

  log.info(`Creating backup: ${backupFilename}`);

  // Convert Firestore Timestamps to serializable format
  const serializedJokes = jokes.map(joke => {
    const serialized = { ...joke };

    // Convert Timestamp objects to ISO strings
    if (joke.created_at && joke.created_at.toDate) {
      serialized.created_at = joke.created_at.toDate().toISOString();
    }
    if (joke.updated_at && joke.updated_at.toDate) {
      serialized.updated_at = joke.updated_at.toDate().toISOString();
    }

    return serialized;
  });

  const backupData = {
    exportDate: new Date().toISOString(),
    totalJokes: jokes.length,
    jokes: serializedJokes
  };

  writeFileSync(backupPath, JSON.stringify(backupData, null, 2));
  log.success(`Backup saved to: ${backupPath}`);

  return backupPath;
}

/**
 * Check if a joke ID is category-based (needs migration)
 */
function isCategoryBasedId(id) {
  // Category-based IDs follow pattern: category_NNN (e.g., bad_001, dad_001)
  const pattern = /^(bad|dad|love|potty|sad)_\d{3}$/;
  return pattern.test(id);
}

/**
 * Verify the current state of the collection
 */
async function verifyCollection(jokes) {
  log.divider();
  log.info('VERIFICATION REPORT');
  log.divider();

  const categoryBased = jokes.filter(j => isCategoryBasedId(j.id));
  const autoGenerated = jokes.filter(j => !isCategoryBasedId(j.id));

  log.info(`Total jokes: ${jokes.length}`);
  log.info(`Category-based IDs (need migration): ${categoryBased.length}`);
  log.info(`Auto-generated IDs (already migrated): ${autoGenerated.length}`);

  // Check for migrated_from field
  const withMigratedFrom = jokes.filter(j => j.migrated_from);
  log.info(`Jokes with 'migrated_from' field: ${withMigratedFrom.length}`);

  // Category breakdown
  log.divider();
  log.info('CATEGORY BREAKDOWN:');

  const byType = {};
  const byCharacter = {};

  jokes.forEach(joke => {
    byType[joke.type] = (byType[joke.type] || 0) + 1;
    byCharacter[joke.character] = (byCharacter[joke.character] || 0) + 1;
  });

  log.info('By type:');
  Object.entries(byType).sort().forEach(([type, count]) => {
    log.info(`  ${type}: ${count}`);
  });

  log.info('By character:');
  Object.entries(byCharacter).sort().forEach(([char, count]) => {
    log.info(`  ${char}: ${count}`);
  });

  // Check for the skeleton joke
  const skeletonJoke = jokes.find(j => j.text && j.text.includes("skeletons fight"));
  if (skeletonJoke) {
    log.divider();
    log.info('SKELETON JOKE STATUS:');
    log.info(`  ID: ${skeletonJoke.id}`);
    log.info(`  Character: ${skeletonJoke.character}`);
    log.info(`  Type: ${skeletonJoke.type}`);
    if (skeletonJoke.character === 'mr_funny' && skeletonJoke.type === 'dad_joke') {
      log.success('  Status: Already correctly categorized!');
    } else {
      log.warn(`  Status: Needs fix (should be mr_funny/dad_joke)`);
    }
  }

  log.divider();

  return {
    total: jokes.length,
    categoryBased: categoryBased.length,
    autoGenerated: autoGenerated.length,
    needsMigration: categoryBased.length > 0
  };
}

/**
 * Migrate jokes to auto-generated IDs
 */
async function migrateJokes(db, jokes) {
  const jokesToMigrate = jokes.filter(j => isCategoryBasedId(j.id));

  if (jokesToMigrate.length === 0) {
    log.info('No jokes need migration - all already have auto-generated IDs');
    return { migrated: 0, deleted: 0 };
  }

  log.divider();
  log.info(`MIGRATION: ${jokesToMigrate.length} jokes to migrate`);
  log.divider();

  if (DRY_RUN) {
    log.warn('DRY RUN MODE - No changes will be made');
  }

  const migrationResults = [];
  const currentTime = Timestamp.now();

  // Step 1: Create new documents with auto-generated IDs
  log.info('Step 1: Creating new documents with auto-generated IDs...');

  for (let i = 0; i < jokesToMigrate.length; i += BATCH_SIZE) {
    const batchJokes = jokesToMigrate.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const joke of batchJokes) {
      // Create new document reference with auto-generated ID
      const newDocRef = db.collection(COLLECTION_NAME).doc();

      // Prepare the new document data
      const newJokeData = {
        text: joke.text,
        type: joke.type,
        character: joke.character,
        tags: joke.tags || [],
        sfw: joke.sfw ?? true,
        source: joke.source || '',
        created_at: joke.created_at || currentTime,
        updated_at: currentTime,
        migrated_from: joke.id,
        rating_count: joke.rating_count || 0,
        rating_sum: joke.rating_sum || 0,
        rating_avg: joke.rating_avg || 0,
        likes: joke.likes || 0,
        dislikes: joke.dislikes || 0,
        popularity_score: joke.popularity_score || 0
      };

      // Fix the skeleton joke if this is it
      if (joke.text && joke.text.includes("skeletons fight")) {
        log.info(`  Fixing skeleton joke: ${joke.id} -> mr_funny/dad_joke`);
        newJokeData.character = SKELETON_JOKE_FIX.newCharacter;
        newJokeData.type = SKELETON_JOKE_FIX.newType;
      }

      if (!DRY_RUN) {
        batch.set(newDocRef, newJokeData);
      }

      migrationResults.push({
        oldId: joke.id,
        newId: newDocRef.id,
        text: joke.text.substring(0, 50) + '...'
      });

      log.info(`  Migrating: ${joke.id} -> ${newDocRef.id}`);
    }

    if (!DRY_RUN) {
      await batch.commit();
      log.info(`  Committed batch ${Math.floor(i / BATCH_SIZE) + 1}`);
    }
  }

  log.success(`Created ${migrationResults.length} new documents`);

  // Step 2: Verify the new documents exist
  log.info('Step 2: Verifying new documents...');

  if (!DRY_RUN) {
    const newSnapshot = await db.collection(COLLECTION_NAME).get();
    const newCount = newSnapshot.size;
    const expectedCount = jokes.length + jokesToMigrate.length;

    log.info(`  Current document count: ${newCount}`);
    log.info(`  Expected count (before deletion): ${expectedCount}`);

    if (newCount !== expectedCount) {
      throw new Error(
        `Document count mismatch! Expected ${expectedCount}, got ${newCount}. ` +
        'Aborting migration. New documents have been created but old ones NOT deleted.'
      );
    }

    // Verify each new document has migrated_from field
    let verifiedCount = 0;
    for (const result of migrationResults) {
      const doc = await db.collection(COLLECTION_NAME).doc(result.newId).get();
      if (doc.exists && doc.data().migrated_from === result.oldId) {
        verifiedCount++;
      } else {
        log.error(`  Failed to verify: ${result.newId}`);
      }
    }

    if (verifiedCount !== migrationResults.length) {
      throw new Error(
        `Verification failed! Only ${verifiedCount}/${migrationResults.length} documents verified. ` +
        'Aborting deletion phase.'
      );
    }

    log.success(`Verified all ${verifiedCount} new documents`);
  }

  // Step 3: Delete old documents
  log.info('Step 3: Deleting old category-based documents...');

  let deletedCount = 0;

  for (let i = 0; i < jokesToMigrate.length; i += BATCH_SIZE) {
    const batchJokes = jokesToMigrate.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const joke of batchJokes) {
      if (!DRY_RUN) {
        batch.delete(db.collection(COLLECTION_NAME).doc(joke.id));
      }
      deletedCount++;
      log.info(`  Deleting: ${joke.id}`);
    }

    if (!DRY_RUN) {
      await batch.commit();
      log.info(`  Deleted batch ${Math.floor(i / BATCH_SIZE) + 1}`);
    }
  }

  log.success(`Deleted ${deletedCount} old documents`);

  // Step 4: Final verification
  log.info('Step 4: Final verification...');

  if (!DRY_RUN) {
    const finalSnapshot = await db.collection(COLLECTION_NAME).get();
    const finalCount = finalSnapshot.size;
    const expectedFinal = jokes.length;

    log.info(`  Final document count: ${finalCount}`);
    log.info(`  Expected count: ${expectedFinal}`);

    if (finalCount !== expectedFinal) {
      log.error(`Document count mismatch! Expected ${expectedFinal}, got ${finalCount}`);
    } else {
      log.success('Document count verified!');
    }

    // Verify no category-based IDs remain
    let categoryBasedRemaining = 0;
    finalSnapshot.forEach(doc => {
      if (isCategoryBasedId(doc.id)) {
        categoryBasedRemaining++;
        log.warn(`  Category-based ID still exists: ${doc.id}`);
      }
    });

    if (categoryBasedRemaining === 0) {
      log.success('All category-based IDs have been migrated!');
    } else {
      log.warn(`${categoryBasedRemaining} category-based IDs still remain`);
    }
  }

  // Save migration log
  const migrationLogPath = join(__dirname, `migration-log-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
  writeFileSync(migrationLogPath, JSON.stringify({
    date: new Date().toISOString(),
    dryRun: DRY_RUN,
    migratedCount: migrationResults.length,
    deletedCount: deletedCount,
    results: migrationResults
  }, null, 2));
  log.info(`Migration log saved to: ${migrationLogPath}`);

  return { migrated: migrationResults.length, deleted: deletedCount };
}

/**
 * Main execution
 */
async function main() {
  log.divider();
  log.info('FIRESTORE JOKES MIGRATION SCRIPT');
  log.info(`Mode: ${BACKUP_ONLY ? 'BACKUP ONLY' : VERIFY_ONLY ? 'VERIFY ONLY' : DRY_RUN ? 'DRY RUN' : 'FULL MIGRATION'}`);
  log.divider();

  try {
    // Initialize Firebase
    const db = initializeFirebase();

    // Fetch all jokes
    const jokes = await fetchAllJokes(db);

    if (jokes.length === 0) {
      log.warn('No jokes found in the collection!');
      process.exit(1);
    }

    // Always create a backup first
    const backupPath = createBackup(jokes);

    if (BACKUP_ONLY) {
      log.success('Backup complete. Exiting.');
      process.exit(0);
    }

    // Verify current state
    const verifyResult = await verifyCollection(jokes);

    if (VERIFY_ONLY) {
      log.success('Verification complete. Exiting.');
      process.exit(0);
    }

    // Check if migration is needed
    if (!verifyResult.needsMigration) {
      log.success('No migration needed - all jokes already have auto-generated IDs!');
      process.exit(0);
    }

    // Perform migration
    const migrationResult = await migrateJokes(db, jokes);

    log.divider();
    log.success('MIGRATION COMPLETE!');
    log.info(`  Migrated: ${migrationResult.migrated} jokes`);
    log.info(`  Deleted: ${migrationResult.deleted} old documents`);
    log.info(`  Backup: ${backupPath}`);
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

// Run the script
main();
