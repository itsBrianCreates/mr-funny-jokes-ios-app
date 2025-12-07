/**
 * Set Daily Joke Script
 *
 * Sets the joke of the day in the daily_jokes collection for a specific date.
 * The daily_jokes collection stores a reference (joke_id) to a joke document
 * that should be shown as the Joke of the Day.
 *
 * Usage:
 *   node set-daily-joke.js <joke_id>                    # Set joke for today
 *   node set-daily-joke.js <joke_id> --date 2025-12-07  # Set joke for specific date
 *   node set-daily-joke.js --list                       # List all daily jokes
 *   node set-daily-joke.js --dry-run <joke_id>          # Simulate without making changes
 *
 * Requirements:
 *   - Firebase service account key file: ./serviceAccountKey.json
 *   - Or set GOOGLE_APPLICATION_CREDENTIALS environment variable
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const DAILY_JOKES_COLLECTION = 'daily_jokes';
const JOKES_COLLECTION = 'jokes';
const FIREBASE_PROJECT_ID = 'mr-funny-jokes';

// Parse command line arguments
const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const LIST_MODE = args.includes('--list');
const dateIndex = args.indexOf('--date');
const targetDate = dateIndex !== -1 ? args[dateIndex + 1] : null;

// Get joke ID (first argument that doesn't start with --)
const jokeId = args.find(arg => !arg.startsWith('--') && arg !== targetDate);

// Logging utilities
const log = {
  info: (msg) => console.log(`[INFO] ${new Date().toISOString()} - ${msg}`),
  warn: (msg) => console.log(`[WARN] ${new Date().toISOString()} - ${msg}`),
  error: (msg) => console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`),
  success: (msg) => console.log(`[SUCCESS] ${new Date().toISOString()} - ${msg}`),
  divider: () => console.log('='.repeat(70))
};

/**
 * Format date as YYYY-MM-DD string (Eastern Time)
 */
function formatDate(date) {
  // Use Eastern Time for consistency with the iOS app
  const options = { timeZone: 'America/New_York', year: 'numeric', month: '2-digit', day: '2-digit' };
  const parts = new Intl.DateTimeFormat('en-CA', options).formatToParts(date);
  const year = parts.find(p => p.type === 'year').value;
  const month = parts.find(p => p.type === 'month').value;
  const day = parts.find(p => p.type === 'day').value;
  return `${year}-${month}-${day}`;
}

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
    log.info('Attempting to use Application Default Credentials...');
    try {
      initializeApp({
        projectId: FIREBASE_PROJECT_ID
      });
      log.info(`Successfully initialized with Application Default Credentials for project: ${FIREBASE_PROJECT_ID}`);
    } catch (adcError) {
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
  }

  return getFirestore();
}

/**
 * Verify that a joke exists in the database
 */
async function verifyJokeExists(db, jokeId) {
  log.info(`Verifying joke exists: ${jokeId}`);

  const jokeDoc = await db.collection(JOKES_COLLECTION).doc(jokeId).get();

  if (!jokeDoc.exists) {
    return null;
  }

  return jokeDoc.data();
}

/**
 * Set the joke of the day for a specific date
 */
async function setDailyJoke(db, jokeId, dateStr) {
  log.divider();
  log.info(`SETTING DAILY JOKE FOR ${dateStr}`);
  log.divider();

  // Verify the joke exists
  const jokeData = await verifyJokeExists(db, jokeId);

  if (!jokeData) {
    throw new Error(`Joke with ID "${jokeId}" not found in the database`);
  }

  log.info(`Found joke: "${jokeData.text?.substring(0, 50)}..."`);

  if (DRY_RUN) {
    log.warn('DRY RUN MODE - No changes will be made');
    return { success: true, dateStr, jokeId, jokeText: jokeData.text };
  }

  // Set the daily joke document
  const dailyJokeRef = db.collection(DAILY_JOKES_COLLECTION).doc(dateStr);

  await dailyJokeRef.set({
    joke_id: jokeId,
    set_at: FieldValue.serverTimestamp(),
    joke_preview: jokeData.text?.substring(0, 100) || 'Unknown joke'
  });

  log.success(`Daily joke set for ${dateStr}`);

  return { success: true, dateStr, jokeId, jokeText: jokeData.text };
}

/**
 * List all configured daily jokes
 */
async function listDailyJokes(db) {
  log.divider();
  log.info('LISTING ALL DAILY JOKES');
  log.divider();

  const snapshot = await db.collection(DAILY_JOKES_COLLECTION)
    .orderBy('__name__', 'desc')
    .limit(30)
    .get();

  if (snapshot.empty) {
    log.warn('No daily jokes configured yet');
    return;
  }

  log.info(`Found ${snapshot.size} daily joke(s):\n`);

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const date = doc.id;
    const jokeId = data.joke_id || 'N/A';
    const preview = data.joke_preview || 'No preview available';

    console.log(`  ${date}: ${jokeId}`);
    console.log(`    Preview: "${preview.substring(0, 60)}${preview.length > 60 ? '...' : ''}"\n`);
  }
}

/**
 * Main execution
 */
async function main() {
  log.divider();
  log.info('SET DAILY JOKE SCRIPT');
  log.info(`Mode: ${LIST_MODE ? 'LIST' : DRY_RUN ? 'DRY RUN' : 'SET'}`);
  log.divider();

  try {
    const db = initializeFirebase();

    if (LIST_MODE) {
      await listDailyJokes(db);
      return;
    }

    if (!jokeId) {
      log.error('No joke ID provided!');
      console.log('\nUsage:');
      console.log('  node set-daily-joke.js <joke_id>                    # Set joke for today');
      console.log('  node set-daily-joke.js <joke_id> --date 2025-12-07  # Set joke for specific date');
      console.log('  node set-daily-joke.js --list                       # List all daily jokes');
      console.log('  node set-daily-joke.js --dry-run <joke_id>          # Simulate without making changes');
      process.exit(1);
    }

    // Determine target date
    let dateStr;
    if (targetDate) {
      // Validate date format
      if (!/^\d{4}-\d{2}-\d{2}$/.test(targetDate)) {
        throw new Error(`Invalid date format: "${targetDate}". Expected YYYY-MM-DD`);
      }
      dateStr = targetDate;
    } else {
      dateStr = formatDate(new Date());
    }

    log.info(`Target date: ${dateStr}`);
    log.info(`Joke ID: ${jokeId}`);

    const result = await setDailyJoke(db, jokeId, dateStr);

    log.divider();
    log.success('OPERATION COMPLETE!');
    log.info(`  Date: ${result.dateStr}`);
    log.info(`  Joke ID: ${result.jokeId}`);
    log.info(`  Joke: "${result.jokeText?.substring(0, 50)}..."`);
    if (DRY_RUN) {
      log.warn('  This was a DRY RUN - no actual changes were made');
    }
    log.divider();

  } catch (error) {
    log.error(`Failed to set daily joke: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

// Run the script
main();
