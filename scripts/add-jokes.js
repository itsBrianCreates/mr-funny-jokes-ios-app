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

// Jokes to add - Christmas batch (39) (November 2026)
//
// Every joke has a "setup" (shown on the card) and a "punchline" (shown on tap).
// The script stores them as one `text` field with a blank line between the two,
// which is what the app and widget split on. A setup may stop mid-sentence
// ("Is it hot in here," / "or is it just you?"); the app adds the "…" itself.
// Knock-knock: setup is the first three lines, punchline is "X who?" plus the answer.
const JOKES_TO_ADD = [
  // Mr. Funny
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "animals", "wordplay"], "setup": "What do you call a cat on the beach at Christmas?", "punchline": "Sandy Claws!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "food", "wordplay"], "setup": "What's the most popular wine at Christmas dinner?", "punchline": "\"But I don't like Brussels sprouts!\""},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "weather"], "setup": "What did one snowman say to the other snowman?", "punchline": "\"Do you smell carrots?\""},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "school", "wordplay"], "setup": "What do Santa's elves do after school?", "punchline": "Their gnome-work!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "wordplay"], "setup": "How does Christmas Day end?", "punchline": "With the letter Y!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "school", "wordplay"], "setup": "What do you call Santa's little helpers?", "punchline": "Subordinate clauses."},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "family", "weather"], "setup": "What do snowmen call their kids?", "punchline": "Chill-dren!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "wordplay"], "setup": "What did the stamp say to the Christmas card?", "punchline": "\"Stick with me and we'll go places!\""},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "health"], "setup": "What do you get if you eat the Christmas decorations?", "punchline": "Tinsel-itis!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "animals", "wordplay"], "setup": "What do reindeer hang on their Christmas trees?", "punchline": "Horn-aments!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "wordplay"], "setup": "Why are Advent calendars so hard to find in late December?", "punchline": "Their days are numbered!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas"], "setup": "What did the Christmas tree say to the ornament?", "punchline": "\"Quit hanging around!\""},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "animals", "wordplay"], "setup": "What's green, covered in tinsel, and goes \"ribbit\"?", "punchline": "Mistle-toad!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "animals", "food"], "setup": "How do you make a slow reindeer fast?", "punchline": "Stop feeding it!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas"], "setup": "What do you call an elf wearing earmuffs?", "punchline": "Anything you want — he can't hear you!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "wordplay"], "setup": "How does Santa keep track of every fireplace he visits?", "punchline": "He keeps a log."},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["christmas", "animals", "wordplay"], "setup": "Who delivers presents to baby sharks at Christmas?", "punchline": "Santa Jaws!"},
  // Mr. Funny knock-knocks
  {"character": "mr_funny", "type": "knock_knock", "tags": ["christmas"], "setup": "Knock, knock.\nWho's there?\nMary.", "punchline": "Mary who?\nMary Christmas!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["christmas", "animals"], "setup": "Knock, knock.\nWho's there?\nOlive.", "punchline": "Olive who?\nOlive the other reindeer!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["christmas", "weather"], "setup": "Knock, knock.\nWho's there?\nYule.", "punchline": "Yule who?\nYule be sorry if you don't let me in — it's freezing out here!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["christmas"], "setup": "Knock, knock.\nWho's there?\nElf.", "punchline": "Elf who?\nElf me wrap these presents!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["christmas", "music"], "setup": "Knock, knock.\nWho's there?\nHannah.", "punchline": "Hannah who?\nHannah partridge in a pear tree!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["christmas", "weather"], "setup": "Knock, knock.\nWho's there?\nSnow.", "punchline": "Snow who?\nSnow time to chat — Santa's on his way!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["christmas"], "setup": "Knock, knock.\nWho's there?\nHolly.", "punchline": "Holly who?\nHolly-days are here — open up!"},
  // Mr. Potty
  {"character": "mr_potty", "type": "dad_joke", "tags": ["christmas", "weather"], "setup": "Why was the snowman digging through the bag of carrots?", "punchline": "He was picking his nose!"},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["christmas", "music", "food"], "setup": "What's the worst carol to hear after Christmas dinner?", "punchline": "\"Jingle Smells.\""},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["christmas", "food", "health"], "setup": "What do you call Santa after he eats every cookie on Christmas Eve?", "punchline": "Santa Claus-tipated."},
  // Mr. Bad
  {"character": "mr_bad", "type": "dad_joke", "tags": ["christmas", "health", "wordplay"], "setup": "What did Santa say to the guy smoking on his roof?", "punchline": "\"Put that out — it's bad for my elf.\""},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["christmas"], "setup": "What do you get for being on the naughty list?", "punchline": "Coal. Which, with today's heating bills, is honestly a great gift."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["christmas", "work"], "setup": "Why is Christmas just like a day at the office?", "punchline": "You do all the work, and the fat guy in the suit gets all the credit."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["christmas", "thanksgiving", "animals", "food"], "setup": "What did the turkey say when it heard about Christmas dinner?", "punchline": "\"Seriously? I just survived Thanksgiving!\""},
  // Mr. Sad
  {"character": "mr_sad", "type": "dad_joke", "tags": ["christmas", "weather"], "setup": "Why was the snowman so quiet at the Christmas party?", "punchline": "He knew he'd be gone by spring."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["christmas", "family"], "setup": "My kids got me a \"World's Best Dad\" mug for Christmas.", "punchline": "The sticker said 75% off."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["christmas"], "setup": "Why did the Christmas tree feel so empty on December 26th?", "punchline": "Everyone just took the presents and left."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["christmas", "food"], "setup": "Every year I leave out milk and cookies for Santa.", "punchline": "Every year the cookies disappear, and so does any sign of my presents."},
  // Mr. Love
  {"character": "mr_love", "type": "pickup_line", "tags": ["christmas", "romantic"], "setup": "Let's skip the mistletoe.", "punchline": "I don't need an excuse to kiss you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["christmas", "romantic"], "setup": "You're at the top of my Christmas list,", "punchline": "and I've checked it twice."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["christmas", "romantic"], "setup": "Do you hear that?", "punchline": "My heart just grew three sizes."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["christmas", "romantic", "weather"], "setup": "Are you a snowflake?", "punchline": "Because there's no one else quite like you."}
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
