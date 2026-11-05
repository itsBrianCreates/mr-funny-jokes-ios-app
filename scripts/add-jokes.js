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

// Jokes to add - Mixed batch (March 27 2026)
const JOKES_TO_ADD = [
  // --- mr_funny (6 jokes) ---
  {
    "character": "mr_funny",
    "text": "What do you call a polite snake? A civil serpent!",
    "type": "dad_joke",
    "tags": ["animals", "wordplay"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_funny",
    "text": "I used to play piano by ear, but now I use my hands!",
    "type": "dad_joke",
    "tags": ["music", "wordplay"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_funny",
    "text": "Why do seagulls fly over the sea? Because if they flew over the bay, they'd be bagels!",
    "type": "dad_joke",
    "tags": ["animals", "food", "wordplay"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_funny",
    "text": "What do you call fake spaghetti? An impasta!",
    "type": "dad_joke",
    "tags": ["food", "wordplay"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_funny",
    "text": "Why did the giraffe refuse to play hide-and-seek? Because he was always spotted!",
    "type": "dad_joke",
    "tags": ["animals", "wordplay"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_funny",
    "text": "I only know 25 letters of the alphabet. I don't know Y.",
    "type": "dad_joke",
    "tags": ["wordplay"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  // --- mr_potty (8 jokes) ---
  {
    "character": "mr_potty",
    "text": "Poop jokes aren't my favorite kind of jokes… but they're a solid number two!",
    "type": "potty_joke",
    "tags": ["bathroom"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_potty",
    "text": "What kind of dog lives in the toilet? A poo-dle!",
    "type": "potty_joke",
    "tags": ["animals", "bathroom"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_potty",
    "text": "How many people does it take to make the bathroom smell? Just a phew!",
    "type": "potty_joke",
    "tags": ["bathroom"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_potty",
    "text": "What is a bathroom fairy called? Stinker-bella!",
    "type": "potty_joke",
    "tags": ["bathroom"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_potty",
    "text": "What does Superman call his bathroom? The Super Bowl!",
    "type": "potty_joke",
    "tags": ["bathroom"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_potty",
    "text": "Why do ducks have feathers? To cover their butt quacks!",
    "type": "potty_joke",
    "tags": ["animals", "bathroom"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_potty",
    "text": "What do you get when a king farts? Noble gas!",
    "type": "potty_joke",
    "tags": ["bathroom"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_potty",
    "text": "Why do cops sit on the toilet all day? Because it's their duty!",
    "type": "potty_joke",
    "tags": ["bathroom"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  // --- mr_bad (6 jokes) ---
  {
    "character": "mr_bad",
    "text": "My parents raised me as an only child, which really pissed off my sister!",
    "type": "dark_joke",
    "tags": ["family"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_bad",
    "text": "As I get older, I remember all the people I lost along the way. Maybe a career as a tour guide was not the right choice!",
    "type": "dark_joke",
    "tags": ["life"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_bad",
    "text": "The guy who stole my diary just died. My thoughts are with his family.",
    "type": "dark_joke",
    "tags": ["life"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_bad",
    "text": "I childproofed my house. Somehow they still got in!",
    "type": "dark_joke",
    "tags": ["family"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_bad",
    "text": "My grief counselor died, but he was so good at his job that I don't even care!",
    "type": "dark_joke",
    "tags": ["life"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_bad",
    "text": "My mother told me, \"One man's trash is another man's treasure.\" Terrible way to learn I'm adopted!",
    "type": "dark_joke",
    "tags": ["family"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  // --- mr_love (8 jokes) ---
  {
    "character": "mr_love",
    "text": "If you were a vegetable, you'd be a cute-cumber!",
    "type": "pickup_line",
    "tags": ["romantic", "food"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_love",
    "text": "Are you a campfire? Because you're hot and I want s'more!",
    "type": "pickup_line",
    "tags": ["romantic", "food"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_love",
    "text": "Are you a keyboard? Because you're just my type!",
    "type": "pickup_line",
    "tags": ["romantic", "technology"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_love",
    "text": "Are you a plot twist? Because I didn't see you coming!",
    "type": "pickup_line",
    "tags": ["romantic", "clever"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_love",
    "text": "If you were a burger at McDonald's, you'd be McGorgeous!",
    "type": "pickup_line",
    "tags": ["romantic", "food"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_love",
    "text": "Are you the square root of -1? Because you can't be real!",
    "type": "pickup_line",
    "tags": ["romantic", "science"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_love",
    "text": "Can I tie your shoes? I don't want you falling for anyone else!",
    "type": "pickup_line",
    "tags": ["romantic", "clever"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_love",
    "text": "Your hands look heavy — can I hold them for you?",
    "type": "pickup_line",
    "tags": ["romantic", "sweet"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  // --- mr_sad (9 jokes) ---
  {
    "character": "mr_sad",
    "text": "I'm terrified of elevators. I'm taking steps to avoid them.",
    "type": "sad_joke",
    "tags": ["life"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_sad",
    "text": "Parallel lines have so much in common. It's a shame they'll never meet.",
    "type": "sad_joke",
    "tags": ["life"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_sad",
    "text": "I threw a boomerang a few years ago. Now I live in constant fear.",
    "type": "sad_joke",
    "tags": ["life"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_sad",
    "text": "I'm the human equivalent of a typo.",
    "type": "sad_joke",
    "tags": ["self_worth"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_sad",
    "text": "I'm very familiar with paranormal activity. I keep getting ghosted!",
    "type": "sad_joke",
    "tags": ["relationships"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_sad",
    "text": "Do mood swings count as exercise?",
    "type": "sad_joke",
    "tags": ["life"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_sad",
    "text": "People say I'm creative and I couldn't agree more because I create most of my own problems!",
    "type": "sad_joke",
    "tags": ["self_worth"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_sad",
    "text": "Every day is Friday when you're unemployed.",
    "type": "sad_joke",
    "tags": ["life"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_sad",
    "text": "I said \"hello\" to darkness my old friend, and it told me that it doesn't want to be my friend.",
    "type": "sad_joke",
    "tags": ["life", "sadness"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  },
  {
    "character": "mr_sad",
    "text": "I'm only posting on social media so everyone else can feel better about themselves. You're welcome.",
    "type": "sad_joke",
    "tags": ["technology", "self_worth"],
    "sfw": true,
    "source": "classic",
    "likes": 0, "dislikes": 0, "rating_sum": 0, "rating_count": 0, "rating_avg": 0, "popularity_score": 0
  }
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
      // Normalize text for comparison (lowercase, trim whitespace)
      existingTexts.add(data.text.toLowerCase().trim());
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
    const normalizedText = joke.text.toLowerCase().trim();
    if (existingTexts.has(normalizedText)) {
      duplicates.push(joke);
    } else {
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

      log.info(`  Adding: ${newDocRef.id} - "${joke.text.substring(0, 40)}..."`);
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

    let jokesToAdd = JOKES_TO_ADD;
    let duplicates = [];

    // Check for duplicates unless --force is used
    if (!FORCE) {
      const existingTexts = await fetchExistingJokeTexts(db);
      const filtered = filterDuplicates(JOKES_TO_ADD, existingTexts);
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
