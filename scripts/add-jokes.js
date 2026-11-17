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

// Jokes to add - Thanksgiving batch (45) (November 2026)
//
// Every joke has a "setup" (shown on the card) and a "punchline" (shown on tap).
// The script stores them as one `text` field with a blank line between the two,
// which is what the app and widget split on. A setup may stop mid-sentence
// ("Is it hot in here," / "or is it just you?"); the app adds the "…" itself.
// Knock-knock: setup is the first three lines, punchline is "X who?" plus the answer.
const JOKES_TO_ADD = [
  // Mr. Funny
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "animals", "food"], "setup": "What do you call a running turkey?", "punchline": "Fast food!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food"], "setup": "What did the turkey say before it was roasted?", "punchline": "\"Boy, I'm stuffed!\""},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "religious", "wordplay"], "setup": "Why can't you take a turkey to church?", "punchline": "They use fowl language."},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "technology"], "setup": "What sound does a turkey's phone make?", "punchline": "Wing, wing, wing!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "animals", "food"], "setup": "What do you get when you cross a turkey with a centipede?", "punchline": "Drumsticks for everyone!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "music", "wordplay"], "setup": "What kind of music did the Pilgrims like?", "punchline": "Plymouth Rock!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "wordplay"], "setup": "If April showers bring May flowers, what do May flowers bring?", "punchline": "Pilgrims!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "animals"], "setup": "Why do turkeys always go \"gobble, gobble\"?", "punchline": "Because they never learned table manners."},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "family", "wordplay"], "setup": "What did the mother turkey say to her misbehaving kids?", "punchline": "\"If your father could see you now, he'd turn over in his gravy!\""},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "wordplay"], "setup": "What should you wear to Thanksgiving dinner?", "punchline": "A har-vest!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food", "wordplay"], "setup": "What do sweet potatoes wear to bed?", "punchline": "Their yammies!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food", "health"], "setup": "Why did the pumpkin pie go to the dentist?", "punchline": "It needed a filling!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "school", "wordplay"], "setup": "What do you get when you divide the circumference of a pumpkin by its diameter?", "punchline": "Pumpkin pi!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "animals"], "setup": "What did the turkey say to the turkey hunter?", "punchline": "\"Quack, quack!\""},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "animals", "wordplay"], "setup": "Why did the police arrest the turkey?", "punchline": "They suspected fowl play."},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "music"], "setup": "What's the best dance to do on Thanksgiving?", "punchline": "The turkey trot!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food"], "setup": "What smells the best at Thanksgiving dinner?", "punchline": "Your nose!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "travel", "wordplay"], "setup": "How did the Mayflower show that it liked America?", "punchline": "It hugged the shore!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food"], "setup": "What did the gravy say to the mashed potatoes?", "punchline": "\"Don't worry, I've got you covered.\""},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food", "wordplay"], "setup": "I was going to bring sweet potatoes to Thanksgiving, but I sat on them.", "punchline": "Now I'm bringing squash."},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "animals"], "setup": "Which side of a turkey has the most feathers?", "punchline": "The outside!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food", "wordplay"], "setup": "What role do green beans play at Thanksgiving dinner?", "punchline": "The casse-role!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food", "wordplay"], "setup": "What did the corn say when it got a compliment?", "punchline": "\"Aw, shucks!\""},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "animals"], "setup": "How do you keep a turkey in suspense?", "punchline": "I'll tell you after dinner."},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "weather", "wordplay"], "setup": "What do you call it when it rains turkeys?", "punchline": "Fowl weather!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "animals"], "setup": "Can a turkey jump higher than a house?", "punchline": "Of course. A house can't jump!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "food"], "setup": "What's the best way to stuff a turkey?", "punchline": "Take him out for pizza and ice cream!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["thanksgiving", "family"], "setup": "My dad said he'd carve the turkey this year.", "punchline": "So far it's a pretty good statue.", "source": "original"},

  // Mr. Funny knock-knocks
  {"character": "mr_funny", "type": "knock_knock", "tags": ["thanksgiving", "food"], "setup": "Knock, knock.\nWho's there?\nTamara.", "punchline": "Tamara who?\nTamara we'll eat all the leftovers!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["thanksgiving", "food"], "setup": "Knock, knock.\nWho's there?\nHarry.", "punchline": "Harry who?\nHarry up, the turkey's getting cold!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["thanksgiving", "food"], "setup": "Knock, knock.\nWho's there?\nDewey.", "punchline": "Dewey who?\nDewey have to wait much longer to eat?"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["thanksgiving", "food"], "setup": "Knock, knock.\nWho's there?\nLuke.", "punchline": "Luke who?\nLuke at all that food!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["thanksgiving", "food"], "setup": "Knock, knock.\nWho's there?\nPhillip.", "punchline": "Phillip who?\nPhillip your plate and dig in!"},

  // Mr. Potty
  {"character": "mr_potty", "type": "dad_joke", "tags": ["thanksgiving", "animals"], "setup": "Why did the turkey run to the bathroom?", "punchline": "He really had to gobble-gobble-go!"},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["thanksgiving", "food", "family"], "setup": "What's the loudest part of Thanksgiving dinner?", "punchline": "About an hour after the green beans.", "source": "original"},

  // Mr. Bad
  {"character": "mr_bad", "type": "dad_joke", "tags": ["thanksgiving", "animals"], "setup": "What are turkeys thankful for on Thanksgiving?", "punchline": "Vegetarians."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["thanksgiving", "family"], "setup": "Thanksgiving is when the family gets together to remember what they have in common.", "punchline": "Mostly grudges.", "source": "original"},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["thanksgiving", "family", "food"], "setup": "I asked for a small slice of pie.", "punchline": "My aunt said, \"Well, that would be a first.\"", "source": "original"},

  // Mr. Sad
  {"character": "mr_sad", "type": "dad_joke", "tags": ["thanksgiving"], "setup": "I'm so thankful for my friends this Thanksgiving.", "punchline": "Both of them canceled.", "source": "original"},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["thanksgiving", "food"], "setup": "I cooked Thanksgiving dinner for twelve this year.", "punchline": "It's just me. The leftovers should last until Christmas.", "source": "original"},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["thanksgiving", "family"], "setup": "We went around the table saying what we're thankful for.", "punchline": "They skipped me.", "source": "original"},

  // Mr. Love
  {"character": "mr_love", "type": "pickup_line", "tags": ["thanksgiving", "food"], "setup": "Are you gravy?", "punchline": "Because you make everything better.", "source": "original"},
  {"character": "mr_love", "type": "pickup_line", "tags": ["thanksgiving", "food"], "setup": "Are you Thanksgiving leftovers?", "punchline": "Because I'll be thinking about you all week.", "source": "original"},
  {"character": "mr_love", "type": "pickup_line", "tags": ["thanksgiving", "food"], "setup": "If you were a side dish,", "punchline": "you'd be the main course.", "source": "original"},
  {"character": "mr_love", "type": "pickup_line", "tags": ["thanksgiving", "romantic"], "setup": "I'm thankful for a lot this year,", "punchline": "but you're at the top of the list.", "source": "original"},
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
