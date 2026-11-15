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

// Jokes to add - Thanksgiving (22) and Halloween (24) batch (November 2026)
//
// Every joke has a "setup" (shown on the card) and a "punchline" (shown on tap).
// The script stores them as one `text` field with a blank line between the two,
// which is what the app and widget split on. A setup may stop mid-sentence
// ("Is it hot in here," / "or is it just you?"); the app adds the "…" itself.
// Knock-knock: setup is the first three lines, punchline is "X who?" plus the answer.
const JOKES_TO_ADD = [
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "technology"], "setup": "What did the turkey say to the computer?", "punchline": "Google, google, google!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "music"], "setup": "Why did the turkey join the band?", "punchline": "Because it had the drumsticks!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "wordplay"], "setup": "What kind of key can't open any door?", "punchline": "A turkey!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food"], "setup": "Why did the cranberries turn red?", "punchline": "Because they saw the turkey dressing!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "animals"], "setup": "What do you call a turkey on the day after Thanksgiving?", "punchline": "Lucky!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food"], "setup": "Why was the Thanksgiving soup so expensive?", "punchline": "It had 24 carrots!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food"], "setup": "What's the best thing to put into a pumpkin pie?", "punchline": "Your teeth!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "wordplay"], "setup": "Why did the Pilgrim's pants keep falling down?", "punchline": "Because his belt buckle was on his hat!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food", "wordplay"], "setup": "What's a turkey's favorite dessert?", "punchline": "Peach gobbler!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "wordplay"], "setup": "What always comes at the end of Thanksgiving?", "punchline": "The letter G!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "wordplay"], "setup": "If the Pilgrims were alive today, what would they be most famous for?", "punchline": "Their age!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "animals"], "setup": "Why did the turkey cross the road twice?", "punchline": "To prove he wasn't chicken!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "family", "wordplay"], "setup": "My family told me to stop telling Thanksgiving jokes.", "punchline": "I said I couldn't quit cold turkey."},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food"], "setup": "Why did the farmer run a steamroller over his potato field?", "punchline": "He wanted mashed potatoes for Thanksgiving!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["thanksgiving", "food"], "setup": "Knock, knock.\nWho's there?\nNorma Lee.", "punchline": "Norma Lee who?\nNorma Lee I don't eat this much, but it's Thanksgiving!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["thanksgiving", "food"], "setup": "Knock, knock.\nWho's there?\nArthur.", "punchline": "Arthur who?\nArthur any leftovers?"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["thanksgiving", "food"], "setup": "Knock, knock.\nWho's there?\nGladys.", "punchline": "Gladys who?\nGladys Thanksgiving. Pass the pie!"},
  {"character": "mr_love", "type": "pickup_line", "tags": ["thanksgiving", "food"], "setup": "Are you pumpkin pie?", "punchline": "Because I've been saving room for you all day."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["thanksgiving"], "setup": "Forget the wishbone,", "punchline": "you're already everything I wished for."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["thanksgiving", "family"], "setup": "Every Thanksgiving, I get seated at the kids' table.", "punchline": "I'm 43."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["thanksgiving", "family"], "setup": "What am I thankful for this year?", "punchline": "That this dinner only happens once."},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["thanksgiving", "animals"], "setup": "Why did the turkey bring toilet paper to Thanksgiving dinner?", "punchline": "Because he was a party pooper!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "wordplay"], "setup": "Why are ghosts such bad liars?", "punchline": "You can see right through them!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "food"], "setup": "What's a vampire's favorite fruit?", "punchline": "A neck-tarine!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "health"], "setup": "Why did the vampire read the newspaper?", "punchline": "He heard it had great circulation!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "food", "wordplay"], "setup": "What do you call a witch at the beach?", "punchline": "A sand-witch!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "travel"], "setup": "Why don't mummies take vacations?", "punchline": "They're afraid they'll relax and unwind!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "wordplay"], "setup": "What room does a ghost not need?", "punchline": "A living room!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "wordplay"], "setup": "How do you fix a broken jack-o'-lantern?", "punchline": "With a pumpkin patch!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "music"], "setup": "What kind of music do mummies love?", "punchline": "Wrap music!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "wordplay"], "setup": "Why are skeletons so calm?", "punchline": "Because nothing gets under their skin!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "wordplay"], "setup": "What do you call two witches who live together?", "punchline": "Broom-mates!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "food"], "setup": "Where do ghosts buy their food?", "punchline": "At the ghost-ery store!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "school"], "setup": "Why did the zombie stay home from school?", "punchline": "He felt rotten!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "thanksgiving", "animals"], "setup": "What do you get when you cross a turkey with a ghost?", "punchline": "A poultry-geist!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "food"], "setup": "What's a ghost's favorite dessert?", "punchline": "I scream!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "food"], "setup": "What do skeletons order at a restaurant?", "punchline": "Spare ribs!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["halloween", "music"], "setup": "What instrument does a skeleton play?", "punchline": "The trom-bone!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["halloween"], "setup": "Knock, knock.\nWho's there?\nBoo.", "punchline": "Boo who?\nDon't cry, it's only Halloween!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["halloween"], "setup": "Knock, knock.\nWho's there?\nIvana.", "punchline": "Ivana who?\nIvana suck your blood!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["halloween", "food"], "setup": "Knock, knock.\nWho's there?\nWitch.", "punchline": "Witch who?\nWitch one of you has the candy?"},
  {"character": "mr_love", "type": "pickup_line", "tags": ["halloween"], "setup": "If you were a pumpkin,", "punchline": "you'd be the pick of the patch."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["halloween"], "setup": "Are you a ghost?", "punchline": "Because you've been haunting my dreams."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["halloween"], "setup": "I went to the Halloween party as myself.", "punchline": "Everyone said it was the scariest costume there."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["halloween"], "setup": "Nice Halloween mask.", "punchline": "Oh. You're not wearing one?"},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["halloween"], "setup": "What did the roll of toilet paper dress up as for Halloween?", "punchline": "A mummy!"}
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
  'weather', 'holidays', 'halloween', 'thanksgiving', 'christmas', 'family', 'travel', 'wordplay', 'religious'];

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
