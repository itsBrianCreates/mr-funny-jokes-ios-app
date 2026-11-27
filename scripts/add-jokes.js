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

// Jokes to add - Christmas batch 2 (35) (November 2026)
//
// Every joke has a "setup" (shown on the card) and a "punchline" (shown on tap).
// The script stores them as one `text` field with a blank line between the two,
// which is what the app and widget split on. A setup may stop mid-sentence
// ("Is it hot in here," / "or is it just you?"); the app adds the "…" itself.
// Knock-knock: setup is the first three lines, punchline is "X who?" plus the answer.
const JOKES_TO_ADD = [
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"Why is everyone at the North Pole so thirsty?","punchline":"No well!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","food"],"setup":"What did the snowman say to the pushy carrot?","punchline":"\"Get out of my face!\""},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","music","wordplay"],"setup":"What do they sing at a snowman's birthday party?","punchline":"\"Freeze a jolly good fellow!\""},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","religious","wordplay"],"setup":"What did the wise men say after handing over the gold and frankincense?","punchline":"\"Wait, there's myrrh!\""},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","technology","wordplay"],"setup":"What does Rudolph want for Christmas?","punchline":"A Pony sleigh station!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","music","animals"],"setup":"Which carol does Santa sing in the desert?","punchline":"\"O Camel Ye Faithful.\""},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"Who does Santa call when his sleigh breaks down?","punchline":"The Abominable Towman!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","movies","wordplay"],"setup":"Who is Santa's favorite actor?","punchline":"Willem Dafoe-ho-ho!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","weather"],"setup":"Which of Santa's friends is the most chill?","punchline":"Jack Frost."},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"Why did Santa get a parking ticket on Christmas Eve?","punchline":"He left his sleigh in a snow parking zone!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","school","wordplay"],"setup":"What was the Christmas tree's favorite subject in high school?","punchline":"Treegonometree!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","school","wordplay"],"setup":"Where do young trees learn to be Christmas trees?","punchline":"Elementree school!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","school","wordplay"],"setup":"Why did the Christmas tree fail its algebra test?","punchline":"Every question had it stumped!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","technology","wordplay"],"setup":"How do Christmas trees check their email?","punchline":"They log on!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","health","wordplay"],"setup":"Why did the Christmas tree go to the dentist?","punchline":"It needed a root canal!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","movies","wordplay"],"setup":"What did Luke Skywalker say after planting a Christmas tree farm?","punchline":"\"May the forest be with you!\""},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"How do Christmas trees get ready for a night out?","punchline":"They spruce up!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","food","wordplay"],"setup":"What is a Christmas tree's favorite candy?","punchline":"Orna-mints!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"Why are Christmas trees so fond of the past?","punchline":"Because the present's beneath them."},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"What do you call cutting down a Christmas tree?","punchline":"Christmas chopping!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","music","wordplay"],"setup":"Who is a Christmas tree's favorite singer?","punchline":"Spruce Springsteen!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"What did one Christmas tree say to the other?","punchline":"\"Lighten up!\""},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","nature","wordplay"],"setup":"Which month does a Christmas tree hate the most?","punchline":"Sep-timber!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","music","religious"],"setup":"Knock, knock.\nWho's there?\nWayne.","punchline":"Wayne who?\nWayne in a manger, no crib for a bed…"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas"],"setup":"Knock, knock.\nWho's there?\nYah.","punchline":"Yah who?\nWow, you're really excited about Christmas!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","wordplay"],"setup":"Knock, knock.\nWho's there?\nAvery.","punchline":"Avery who?\nAvery merry Christmas to you!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","wordplay"],"setup":"Knock, knock.\nWho's there?\nGladys.","punchline":"Gladys who?\nGladys Christmas — aren't you?"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","food","wordplay"],"setup":"Knock, knock.\nWho's there?\nJustin.","punchline":"Justin who?\nJustin time for Christmas cookies!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","wordplay"],"setup":"Knock, knock.\nWho's there?\nSanta.","punchline":"Santa who?\nSanta Christmas card to you — did you get it?"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","wordplay"],"setup":"Knock, knock.\nWho's there?\nDewey.","punchline":"Dewey who?\nDewey know how long it is until Santa gets here?"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","music","wordplay"],"setup":"Knock, knock.\nWho's there?\nHoward.","punchline":"Howard who?\nHoward you like to sing Christmas carols with me?"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","wordplay"],"setup":"Knock, knock.\nWho's there?\nHarry.","punchline":"Harry who?\nHarry up and open your present!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","wordplay"],"setup":"Knock, knock.\nWho's there?\nLuke.","punchline":"Luke who?\nLuke at all those presents!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","music","wordplay"],"setup":"Knock, knock.\nWho's there?\nTinsel.","punchline":"Tinsel who?\nTinsel the season to be jolly!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas"],"setup":"Knock, knock.\nWho's there?\nInterrupting Santa.","punchline":"Interrupting Santa wh—\nHo ho ho! Merry Christmas!"},
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
