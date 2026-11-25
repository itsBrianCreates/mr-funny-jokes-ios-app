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

// Jokes to add - Thanksgiving batch (44) (November 2026)
//
// Every joke has a "setup" (shown on the card) and a "punchline" (shown on tap).
// The script stores them as one `text` field with a blank line between the two,
// which is what the app and widget split on. A setup may stop mid-sentence
// ("Is it hot in here," / "or is it just you?"); the app adds the "…" itself.
// Knock-knock: setup is the first three lines, punchline is "X who?" plus the answer.
const JOKES_TO_ADD = [
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","food","wordplay"],"setup":"What do you call a sad cranberry?","punchline":"A blueberry!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","animals","wordplay"],"setup":"What happened when the turkey got into a fight?","punchline":"He got the stuffing knocked out of him!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","animals"],"setup":"Where do you find a turkey with no legs?","punchline":"Exactly where you left it!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","food","wordplay"],"setup":"What did the leftovers say when they got wrapped up and put in the fridge?","punchline":"\"Foiled again!\""},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","animals"],"setup":"Why did the turkey cross the road?","punchline":"It was the chicken's day off!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","food"],"setup":"Why did the Pilgrims eat turkey on Thanksgiving?","punchline":"Because they couldn't fit a moose in the oven!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","food","wordplay"],"setup":"What's the smallest unit of measurement in a Pilgrim cookbook?","punchline":"The Pilgram!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","food"],"setup":"How do you make a turkey float?","punchline":"Root beer, a scoop of ice cream, and a turkey!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","animals","wordplay"],"setup":"What does a turkey drink from?","punchline":"A gobble-let!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","music","wordplay"],"setup":"Where does a turkey go to dance?","punchline":"The Butter Ball!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","animals","food"],"setup":"What do you get when a turkey lays an egg on top of a barn?","punchline":"An eggroll!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","food"],"setup":"What did the hipster say the day after Thanksgiving?","punchline":"\"I liked the leftovers before they were cool.\""},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","food","wordplay"],"setup":"Why is the butter always the life of Thanksgiving dinner?","punchline":"It's on a roll!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","animals","wordplay"],"setup":"What sound does a limping turkey make?","punchline":"Wobble, wobble!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","school"],"setup":"My teacher asked what I'm thankful for this Thanksgiving.","punchline":"I said, \"That I'm not a turkey!\""},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","music","wordplay"],"setup":"What kind of music do the Thanksgiving parade balloons hate?","punchline":"Pop!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","food","wordplay"],"setup":"What did the Pilgrims use to bake cookies?","punchline":"May-flour!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","music","food"],"setup":"What's the best song to play while cooking a turkey?","punchline":"\"All About That Baste.\""},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","christmas","school"],"setup":"When does Christmas come before Thanksgiving?","punchline":"In the dictionary!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","food","wordplay"],"setup":"Why is corn the best listener at Thanksgiving dinner?","punchline":"It's all ears!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","animals"],"setup":"Why do turkeys lay eggs?","punchline":"Because if they dropped them, they'd break!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","food"],"setup":"How many cooks does it take to stuff a turkey?","punchline":"Just one, but you really have to squeeze him in!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","animals","music"],"setup":"What do you get when you cross a turkey with a banjo?","punchline":"A turkey that can pluck itself!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","wordplay"],"setup":"What kind of tan did the Pilgrims get at the beach?","punchline":"A Puri-tan!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","food","family"],"setup":"How do you know when the Thanksgiving turkey is done?","punchline":"The smoke alarm tells you."},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","food"],"setup":"What do you call leftover turkey on Friday, Saturday and Sunday?","punchline":"Breakfast, lunch and dinner."},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","travel"],"setup":"Where did the Pilgrims land when they got to America?","punchline":"On their feet!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","school","wordplay"],"setup":"If Pilgrims traveled on the Mayflower, what do college students travel on?","punchline":"Scholar ships!"},
  {"character":"mr_funny","type":"dad_joke","tags":["thanksgiving","health","wordplay"],"setup":"What's the most popular workout on Thanksgiving?","punchline":"The fork lift!"},
  {"character":"mr_funny","type":"knock_knock","tags":["thanksgiving","food"],"setup":"Knock, knock.\nWho's there?\nAida.","punchline":"Aida who?\nAida lot more than I should have!"},
  {"character":"mr_funny","type":"knock_knock","tags":["thanksgiving","food"],"setup":"Knock, knock.\nWho's there?\nWaddle.","punchline":"Waddle who?\nWaddle I do with all these leftovers?"},
  {"character":"mr_funny","type":"knock_knock","tags":["thanksgiving","food"],"setup":"Knock, knock.\nWho's there?\nPossum.","punchline":"Possum who?\nPossum gravy on my potatoes, please!"},
  {"character":"mr_funny","type":"knock_knock","tags":["thanksgiving","food"],"setup":"Knock, knock.\nWho's there?\nWanda.","punchline":"Wanda who?\nWanda help me finish this pie?"},
  {"character":"mr_funny","type":"knock_knock","tags":["thanksgiving","food"],"setup":"Knock, knock.\nWho's there?\nDon.","punchline":"Don who?\nDon eat all the turkey — save some for me!"},
  {"character":"mr_bad","type":"dad_joke","tags":["thanksgiving","animals"],"setup":"What's the difference between a turkey and a chicken?","punchline":"Chickens get to celebrate Thanksgiving."},
  {"character":"mr_bad","type":"dad_joke","tags":["thanksgiving","family"],"setup":"What's the best thing to bring to Thanksgiving dinner?","punchline":"An excuse to leave early."},
  {"character":"mr_bad","type":"dad_joke","tags":["thanksgiving","family","food"],"setup":"My grandma's stuffing recipe is a family secret.","punchline":"We'd all like it to stay that way."},
  {"character":"mr_bad","type":"dad_joke","tags":["thanksgiving","animals"],"setup":"Why wasn't the turkey nervous about open mic night?","punchline":"It gets roasted every year."},
  {"character":"mr_potty","type":"dad_joke","tags":["thanksgiving","animals","wordplay"],"setup":"What do you call it when a turkey toots?","punchline":"A fowl smell!"},
  {"character":"mr_potty","type":"dad_joke","tags":["thanksgiving"],"setup":"What did the toilet say the morning after Thanksgiving?","punchline":"\"I'm not thankful for any of this.\""},
  {"character":"mr_love","type":"pickup_line","tags":["thanksgiving","romantic","food"],"setup":"Are you cranberry sauce?","punchline":"Because you're the sweetest thing at this table."},
  {"character":"mr_love","type":"pickup_line","tags":["thanksgiving","romantic","food"],"setup":"If you were a Thanksgiving pie,","punchline":"you'd be a cutie pie."},
  {"character":"mr_sad","type":"dad_joke","tags":["thanksgiving"],"setup":"I broke the wishbone by myself this year.","punchline":"I still lost."},
  {"character":"mr_sad","type":"dad_joke","tags":["thanksgiving","food"],"setup":"I hosted Friendsgiving this year.","punchline":"Great turnout. The turkey showed up."},
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
