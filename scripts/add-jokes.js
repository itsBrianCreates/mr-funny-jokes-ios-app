/**
 * Add Jokes to Firestore Script
 *
 * Adds new jokes to the Firebase Firestore database with duplicate checking.
 *
 * Usage:
 *   node add-jokes.js                 # Add jokes (with duplicate check)
 *   node add-jokes.js --dry-run       # Simulate without making changes
 *   node add-jokes.js --force         # Skip duplicate check (not recommended)
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
const COLLECTION_NAME = 'jokes';
const BATCH_SIZE = 500; // Firestore batch limit is 500
const FIREBASE_PROJECT_ID = 'mr-funny-jokes';

// Parse command line arguments
const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const FORCE = args.includes('--force');

// Logging utilities
const log = {
  info: (msg) => console.log(`[INFO] ${new Date().toISOString()} - ${msg}`),
  warn: (msg) => console.log(`[WARN] ${new Date().toISOString()} - ${msg}`),
  error: (msg) => console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`),
  success: (msg) => console.log(`[SUCCESS] ${new Date().toISOString()} - ${msg}`),
  divider: () => console.log('='.repeat(70))
};

// Jokes to add - Mr. Love pickup lines (63) batch (November 2026)
//
// Every joke has a "setup" (shown on the card) and a "punchline" (shown on tap).
// The script stores them as one `text` field with a blank line between the two,
// which is what the app and widget split on. A setup may stop mid-sentence
// ("Is it hot in here," / "or is it just you?"); the app adds the "…" itself.
// Knock-knock: setup is the first three lines, punchline is "X who?" plus the answer.
const JOKES_TO_ADD = [
  {"character": "mr_love", "type": "pickup_line", "tags": ["animals", "wordplay"], "setup": "Are you a bee?", "punchline": "Because I think you're un-bee-lievable."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["animals", "wordplay"], "setup": "Are you an owl?", "punchline": "Because owl always be here for you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["animals", "wordplay"], "setup": "Are you an otter?", "punchline": "Because you're otter this world."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["animals", "wordplay"], "setup": "Are you a bear?", "punchline": "Because I can't bear to be away from you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["animals"], "setup": "If you were a penguin,", "punchline": "I'd bring you the best pebble on the beach."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["animals"], "setup": "If you were a dog,", "punchline": "you'd win best in show."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["food", "wordplay"], "setup": "Are you a pizza?", "punchline": "Because you've stolen a pizza my heart."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["food", "wordplay"], "setup": "Are you an olive?", "punchline": "Because olive you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["food", "wordplay"], "setup": "Are you a muffin?", "punchline": "Because I've got muffin but love for you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["food", "wordplay"], "setup": "Do you like tacos?", "punchline": "Because I'd love to taco 'bout our future."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["food", "wordplay"], "setup": "You must be tea,", "punchline": "because you suit me to a tea."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["food"], "setup": "Are you maple syrup?", "punchline": "Because you're sweet and I'm stuck on you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["food"], "setup": "Are you a cherry?", "punchline": "Because you're the cherry on top of my day."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["food", "romantic"], "setup": "I don't share my fries with just anyone,", "punchline": "but for you I'd hand over the whole basket."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["science", "wordplay"], "setup": "Are you a carbon sample?", "punchline": "Because I'd love to date you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["science", "wordplay"], "setup": "Are you made of oxygen and neon?", "punchline": "Because you're the ONe."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["science"], "setup": "Are you gravity?", "punchline": "Because I'm drawn to you no matter where I stand."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["science"], "setup": "Are you a comet?", "punchline": "Because someone like you only comes around once in a lifetime."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["science"], "setup": "Are you the moon?", "punchline": "Because you brighten even my darkest nights."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["technology", "wordplay"], "setup": "Are you Bluetooth?", "punchline": "Because I feel like we're paired."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["technology"], "setup": "Are you a screenshot?", "punchline": "Because I want to save this moment."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["technology"], "setup": "Are you a notification?", "punchline": "Because my heart lights up every time you pop up."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["technology", "romantic"], "setup": "Are you a good morning text?", "punchline": "Because you just made my whole day."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["school", "wordplay"], "setup": "Are you a highlighter?", "punchline": "Because you're the bright spot of my day."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["school", "wordplay"], "setup": "You must be a ruler,", "punchline": "because you measure up to everything I hoped for."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["school", "science"], "setup": "My feelings for you are like pi:", "punchline": "they go on forever."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["sports", "wordplay"], "setup": "Do you play baseball?", "punchline": "Because you're a real catch."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["sports", "wordplay"], "setup": "Do you bowl?", "punchline": "Because you've bowled me over."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["sports"], "setup": "In tennis, love means nothing.", "punchline": "With you, it means everything."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["sports"], "setup": "If charm were a sport,", "punchline": "you'd take home the gold."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["music"], "setup": "Are you a song?", "punchline": "Because I can't get you out of my head."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["music", "wordplay"], "setup": "Are you a guitar?", "punchline": "Because you're tugging at my heartstrings."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["music", "wordplay"], "setup": "Are you a drummer?", "punchline": "Because my heart skips a beat whenever you're near."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["travel"], "setup": "Are you a compass?", "punchline": "Because I'd be lost without you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["travel"], "setup": "Are you a vacation?", "punchline": "Because I've been needing you all year."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["travel"], "setup": "Are you a window seat?", "punchline": "Because you're exactly what I was hoping for."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["weather"], "setup": "Are you a rainbow?", "punchline": "Because you bring color to my cloudiest days."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["nature"], "setup": "Are you a sunflower?", "punchline": "Because I keep turning toward you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["nature"], "setup": "Are you a four-leaf clover?", "punchline": "Because I feel lucky just finding you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["nature", "wordplay"], "setup": "Are you a garden?", "punchline": "Because I'm really digging you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["work"], "setup": "Are you the weekend?", "punchline": "Because I look forward to you all week."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["work", "food"], "setup": "Are you a coffee break?", "punchline": "Because you're the best part of my workday."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["movies", "wordplay"], "setup": "Are you a sequel?", "punchline": "Because I'd love to see you again."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["movies"], "setup": "Are you the end credits?", "punchline": "Because I'd stay until the very end for you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["movies", "food"], "setup": "Are you popcorn?", "punchline": "Because the movie's no good without you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["movies"], "setup": "If life were a movie,", "punchline": "you'd be my favorite scene."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["health"], "setup": "You must be vitamin D,", "punchline": "because you're my daily dose of sunshine."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["health"], "setup": "Is your smile contagious?", "punchline": "Because I caught it the second you walked in."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["family"], "setup": "I told my mom about you.", "punchline": "She's already setting an extra place at dinner."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["family", "food"], "setup": "Are you my grandma's cooking?", "punchline": "Because nothing else compares."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["christmas"], "setup": "If you were a Christmas tree,", "punchline": "you'd be the one in Rockefeller Center."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["christmas"], "setup": "I must be on the nice list,", "punchline": "because Santa brought me you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["christmas"], "setup": "Are you Christmas morning?", "punchline": "Because I've been waiting for you all year."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["christmas"], "setup": "Is that mistletoe above us,", "punchline": "or am I just hoping?"},
  {"character": "mr_love", "type": "pickup_line", "tags": ["christmas", "wordplay"], "setup": "Are you a string of Christmas lights?", "punchline": "Because my heart's all tangled up in you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["christmas", "wordplay"], "setup": "You must be a snow globe,", "punchline": "because you've shaken up my whole world."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["christmas", "food"], "setup": "Are you hot cocoa?", "punchline": "Because you make winter my favorite season."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["christmas", "food"], "setup": "Are you a gingerbread cookie?", "punchline": "Because you're sweet with just a little spice."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["romantic"], "setup": "Are you a puzzle piece?", "punchline": "Because I think you're what's been missing."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["romantic"], "setup": "You must be my favorite sweater,", "punchline": "because you feel like home."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["romantic"], "setup": "I'm not usually superstitious,", "punchline": "but I think you're my lucky charm."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["romantic"], "setup": "Got a minute?", "punchline": "I'd like to spend a few thousand more with you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["romantic", "wordplay"], "setup": "Excuse me, I think you dropped something:", "punchline": "my jaw."}
];

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
    // Try Application Default Credentials (ADC) for cloud environments
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

const VALID_CHARACTERS = ['mr_funny', 'mr_potty', 'mr_bad', 'mr_love', 'mr_sad'];
const VALID_TYPES = ['dad_joke', 'knock_knock', 'pickup_line'];
const VALID_TAGS = ['animals', 'food', 'work', 'school', 'sports', 'music', 'technology', 'science', 'health',
  'weather', 'nature', 'holidays', 'halloween', 'thanksgiving', 'christmas', 'family', 'travel', 'romantic', 'movies',
  'wordplay', 'religious'];

/**
 * Check each joke and build its stored text: setup, blank line, punchline.
 * A joke without a punchline would show its whole text on the card, so it is rejected.
 */
function prepareJokes(jokes) {
  const problems = [];
  const prepared = jokes.map((joke, index) => {
    const setup = (joke.setup || '').trim();
    const punchline = (joke.punchline || '').trim();
    const label = `#${index + 1} "${setup.substring(0, 30)}"`;
    if (!setup || !punchline) problems.push(`${label}: needs both a setup and a punchline`);
    if (/\n\s*\n/.test(setup) || /\n\s*\n/.test(punchline)) problems.push(`${label}: no blank lines inside setup or punchline`);
    if (!VALID_CHARACTERS.includes(joke.character)) problems.push(`${label}: unknown character "${joke.character}"`);
    if (!VALID_TYPES.includes(joke.type)) problems.push(`${label}: unknown type "${joke.type}"`);
    const tags = joke.tags || [];
    if (tags.length < 1 || tags.length > 3 || tags.some(tag => !VALID_TAGS.includes(tag))) problems.push(`${label}: needs 1-3 valid tags`);
    if (joke.type === 'knock_knock' && setup.split('\n').length !== 3) problems.push(`${label}: knock-knock setup must be three lines`);
    return { ...joke, text: `${setup}\n\n${punchline}` };
  });
  if (problems.length > 0) {
    throw new Error(`Invalid jokes:\n  ${problems.join('\n  ')}`);
  }
  return prepared;
}

/**
 * Normalize text for duplicate checks: case, punctuation and line breaks don't count
 */
function normalizeText(text) {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

/**
 * Fetch all existing joke texts for duplicate checking
 */
async function fetchExistingJokeTexts(db) {
  log.info(`Fetching existing jokes from '${COLLECTION_NAME}' collection for duplicate check...`);

  const snapshot = await db.collection(COLLECTION_NAME).get();
  const existingTexts = new Set();

  snapshot.forEach(doc => {
    const data = doc.data();
    if (data.text) {
      existingTexts.add(normalizeText(data.text));
    }
  });

  log.info(`Found ${existingTexts.size} existing jokes in the collection`);
  return existingTexts;
}

/**
 * Check for duplicates and return non-duplicate jokes
 */
function filterDuplicates(jokesToAdd, existingTexts) {
  const newJokes = [];
  const duplicates = [];

  for (const joke of jokesToAdd) {
    const normalizedText = normalizeText(joke.text);
    if (existingTexts.has(normalizedText)) {
      duplicates.push(joke);
    } else {
      existingTexts.add(normalizedText); // also catches repeats within this batch
      newJokes.push(joke);
    }
  }

  return { newJokes, duplicates };
}

/**
 * Add jokes to Firestore using batch writes
 */
async function addJokes(db, jokes) {
  if (jokes.length === 0) {
    log.info('No jokes to add');
    return { added: 0 };
  }

  log.divider();
  log.info(`ADDING ${jokes.length} JOKES TO FIRESTORE`);
  log.divider();

  if (DRY_RUN) {
    log.warn('DRY RUN MODE - No changes will be made');
  }

  const addedJokes = [];

  for (let i = 0; i < jokes.length; i += BATCH_SIZE) {
    const batchJokes = jokes.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const joke of batchJokes) {
      // Create new document reference with auto-generated ID
      const newDocRef = db.collection(COLLECTION_NAME).doc();

      // Prepare the document data with server timestamps
      const jokeData = {
        text: joke.text,
        type: joke.type,
        character: joke.character,
        tags: joke.tags || [],
        sfw: joke.sfw ?? true,
        source: joke.source || 'classic',
        created_at: FieldValue.serverTimestamp(),
        updated_at: FieldValue.serverTimestamp(),
        rating_count: joke.rating_count || 0,
        rating_sum: joke.rating_sum || 0,
        rating_avg: joke.rating_avg || 0,
        likes: joke.likes || 0,
        dislikes: joke.dislikes || 0,
        popularity_score: joke.popularity_score || 0
      };

      if (!DRY_RUN) {
        batch.set(newDocRef, jokeData);
      }

      addedJokes.push({
        id: newDocRef.id,
        text: joke.text.substring(0, 50) + (joke.text.length > 50 ? '...' : '')
      });

      log.info(`  Adding: ${newDocRef.id} - "${joke.text.replace(/\s+/g, ' ').substring(0, 60)}..."`);
    }

    if (!DRY_RUN) {
      await batch.commit();
      log.info(`  Committed batch ${Math.floor(i / BATCH_SIZE) + 1}`);
    }
  }

  log.success(`Added ${addedJokes.length} new jokes`);

  return { added: addedJokes.length, jokes: addedJokes };
}

/**
 * Main execution
 */
async function main() {
  log.divider();
  log.info('ADD JOKES TO FIRESTORE SCRIPT');
  log.info(`Mode: ${DRY_RUN ? 'DRY RUN' : FORCE ? 'FORCE (skip duplicate check)' : 'NORMAL'}`);
  log.info(`Jokes to add: ${JOKES_TO_ADD.length}`);
  log.divider();

  try {
    // Initialize Firebase
    const db = initializeFirebase();

    const preparedJokes = prepareJokes(JOKES_TO_ADD);
    let jokesToAdd = preparedJokes;
    let duplicates = [];

    // Check for duplicates unless --force is used
    if (!FORCE) {
      const existingTexts = await fetchExistingJokeTexts(db);
      const filtered = filterDuplicates(preparedJokes, existingTexts);
      jokesToAdd = filtered.newJokes;
      duplicates = filtered.duplicates;

      if (duplicates.length > 0) {
        log.divider();
        log.warn(`DUPLICATES FOUND: ${duplicates.length} joke(s) already exist in the database`);
        log.divider();
        for (const dup of duplicates) {
          log.warn(`  SKIPPING: "${dup.text.substring(0, 50)}..."`);
        }
      }
    }

    // Add non-duplicate jokes
    const result = await addJokes(db, jokesToAdd);

    log.divider();
    log.success('OPERATION COMPLETE!');
    log.info(`  Total jokes provided: ${JOKES_TO_ADD.length}`);
    log.info(`  Duplicates skipped: ${duplicates.length}`);
    log.info(`  New jokes added: ${result.added}`);
    if (DRY_RUN) {
      log.warn('  This was a DRY RUN - no actual changes were made');
    }
    log.divider();

  } catch (error) {
    log.error(`Failed to add jokes: ${error.message}`);
    console.error(error);
    process.exit(1);
  }
}

// Run the script
main();
