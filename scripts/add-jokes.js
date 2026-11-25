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

// Jokes to add - Christmas batch (45) (November 2026)
//
// Every joke has a "setup" (shown on the card) and a "punchline" (shown on tap).
// The script stores them as one `text` field with a blank line between the two,
// which is what the app and widget split on. A setup may stop mid-sentence
// ("Is it hot in here," / "or is it just you?"); the app adds the "…" itself.
// Knock-knock: setup is the first three lines, punchline is "X who?" plus the answer.
const JOKES_TO_ADD = [
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"What happened to the man who stole an Advent calendar?","punchline":"He got 25 days!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas"],"setup":"What goes \"Oh, oh, oh\"?","punchline":"Santa walking backwards!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","travel","wordplay"],"setup":"What do you call Santa when he ends up at the South Pole?","punchline":"A lost Claus!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","movies","wordplay"],"setup":"What do you call a Christmas tree that only shows up in action movies?","punchline":"Spruce Willis!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","technology","wordplay"],"setup":"What do you get when you cross a Christmas tree with an iPad?","punchline":"A pineapple!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"What's another name for an artificial Christmas tree?","punchline":"Faux fir!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas"],"setup":"What looks like half a Christmas tree?","punchline":"The other half!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","work","wordplay"],"setup":"What did the Christmas tree do after its bank closed?","punchline":"It started its own branch!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","health","wordplay"],"setup":"What do Christmas trees get when they go numb?","punchline":"Pines and needles!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"What do Christmas trees wear to the pool?","punchline":"Trunks!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","animals","wordplay"],"setup":"What do angry mice send each other in December?","punchline":"Cross-mouse cards!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","sports","wordplay"],"setup":"How did Scrooge win the football game?","punchline":"The Ghost of Christmas passed!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"What kind of cars do elves drive?","punchline":"Toy-otas!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"Why did the elf sleep in the fireplace?","punchline":"He wanted to sleep like a log!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"What do elves keep inside their pointy shoes?","punchline":"Their mistle-toes!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","weather"],"setup":"What did the snowflake say to the fallen leaf?","punchline":"\"You're so last season.\""},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","religious","movies"],"setup":"What movie do the Three Wise Men watch every Christmas?","punchline":"A Star Is Born."},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","weather","wordplay"],"setup":"What did Santa say when he got back to the North Pole?","punchline":"\"There's snow place like home!\""},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","food","wordplay"],"setup":"Why was the candy cane so expensive?","punchline":"It was in mint condition!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","animals"],"setup":"Can you name all of Santa's reindeer?","punchline":"No need. They already have names!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","music","technology"],"setup":"Why does Santa use Spotify?","punchline":"He loves anything that comes Wrapped."},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","animals"],"setup":"Why do reindeer wear bells?","punchline":"Because their horns don't work!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","food","wordplay"],"setup":"What did the salt say to the pepper at Christmas dinner?","punchline":"\"Seasoning's greetings!\""},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","weather","animals"],"setup":"What did Santa ask Rudolph about the weather?","punchline":"\"Is it going to rain, dear?\""},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","food","wordplay"],"setup":"What does Santa eat for breakfast?","punchline":"Mistle-toast!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","technology","wordplay"],"setup":"What do elves post on Instagram?","punchline":"Elf-ies!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","travel","wordplay"],"setup":"What did Santa do when his sleigh broke down?","punchline":"He got it mistle-towed!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","animals","wordplay"],"setup":"How does Rudolph know when Christmas is coming?","punchline":"He checks his calen-deer!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","animals","wordplay"],"setup":"What did the beaver say to the Christmas tree?","punchline":"\"Nice gnawing you!\""},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","sports","wordplay"],"setup":"What's an elf's favorite sport?","punchline":"North Pole vaulting!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","animals","wordplay"],"setup":"Where does a reindeer go when it loses its tail?","punchline":"A re-tail store!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","wordplay"],"setup":"What do you get when you cross Santa with a detective?","punchline":"Santa Clues!"},
  {"character":"mr_funny","type":"dad_joke","tags":["christmas","weather","wordplay"],"setup":"Where do Santa and the elves keep their money?","punchline":"In a snowbank!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","music"],"setup":"Knock, knock.\nWho's there?\nDexter.","punchline":"Dexter who?\nDexter halls with boughs of holly!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas"],"setup":"Knock, knock.\nWho's there?\nAlaska.","punchline":"Alaska who?\nAlaska Santa for a new bike!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","music"],"setup":"Knock, knock.\nWho's there?\nHonda.","punchline":"Honda who?\nHonda first day of Christmas, my true love gave to me…"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas"],"setup":"Knock, knock.\nWho's there?\nHo ho.","punchline":"Ho ho who?\nYour Santa impression needs a little work."},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas"],"setup":"Knock, knock.\nWho's there?\nDoughnut.","punchline":"Doughnut who?\nDoughnut open till Christmas!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas"],"setup":"Knock, knock.\nWho's there?\nIrish.","punchline":"Irish who?\nIrish you a Merry Christmas!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas","animals"],"setup":"Knock, knock.\nWho's there?\nRabbit.","punchline":"Rabbit who?\nRabbit up carefully — it's a present!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas"],"setup":"Knock, knock.\nWho's there?\nCoal.","punchline":"Coal who?\nCoal me if you hear Santa coming!"},
  {"character":"mr_funny","type":"knock_knock","tags":["christmas"],"setup":"Knock, knock.\nWho's there?\nNoah.","punchline":"Noah who?\nNoah good Christmas joke?"},
  {"character":"mr_potty","type":"knock_knock","tags":["christmas"],"setup":"Knock, knock.\nWho's there?\nCentipede.","punchline":"Centipede who?\nCentipede on the Christmas tree!"},
  {"character":"mr_bad","type":"dad_joke","tags":["christmas","work"],"setup":"What does Santa do when his elves misbehave?","punchline":"He gives them the sack."},
  {"character":"mr_bad","type":"dad_joke","tags":["christmas"],"setup":"What do you get if Santa comes down the chimney while the fire is lit?","punchline":"Crisp Kringle."},
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
