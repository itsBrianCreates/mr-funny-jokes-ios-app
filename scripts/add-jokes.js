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

// Jokes to add - punchline-reveal batch, 100 jokes (November 2026)
//
// Every joke has a "setup" (shown on the card) and a "punchline" (shown on tap).
// The script stores them as one `text` field with a blank line between the two,
// which is what the app and widget split on. A setup may stop mid-sentence
// ("Is it hot in here," / "or is it just you?"); the app adds the "…" itself.
// Knock-knock: setup is the first three lines, punchline is "X who?" plus the answer.
const JOKES_TO_ADD = [
  {"character": "mr_funny", "type": "dad_joke", "tags": ["wordplay"], "setup": "What do you call a can opener that doesn't work?", "punchline": "A can't opener!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["food", "health"], "setup": "Why did the cookie go to the doctor?", "punchline": "Because it felt crummy!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["wordplay"], "setup": "What did the left eye say to the right eye?", "punchline": "Between you and me, something smells!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["sports", "wordplay"], "setup": "What do you call a boomerang that won't come back?", "punchline": "A stick!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["wordplay"], "setup": "Why did the picture go to jail?", "punchline": "Because it was framed!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["animals", "sports", "food"], "setup": "What do you call a pig that does karate?", "punchline": "A pork chop!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["work", "wordplay"], "setup": "Why was the broom late?", "punchline": "It over-swept!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["travel", "wordplay"], "setup": "What did the traffic light say to the car?", "punchline": "Don't look! I'm about to change."},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["animals", "school"], "setup": "Why are fish so smart?", "punchline": "Because they live in schools!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["animals", "wordplay"], "setup": "What do you call a sleeping bull?", "punchline": "A bulldozer!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["food", "wordplay"], "setup": "How does a cucumber become a pickle?", "punchline": "It goes through a jarring experience!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["food", "wordplay"], "setup": "What did one plate say to the other plate?", "punchline": "Dinner is on me!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["school", "food"], "setup": "Why did the student eat his homework?", "punchline": "Because the teacher said it was a piece of cake!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["science", "wordplay"], "setup": "What kind of tree fits in your hand?", "punchline": "A palm tree!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["food", "wordplay"], "setup": "Why did the tomato turn red?", "punchline": "Because it saw the salad dressing!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["animals", "wordplay"], "setup": "Why do bees have sticky hair?", "punchline": "Because they use honeycombs!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["travel", "food", "wordplay"], "setup": "What do you call a train carrying bubblegum?", "punchline": "A chew-chew train!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["music", "school"], "setup": "Why did the music teacher need a ladder?", "punchline": "To reach the high notes!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["animals", "school", "wordplay"], "setup": "What do you call a dinosaur with an extensive vocabulary?", "punchline": "A thesaurus!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["animals", "food", "wordplay"], "setup": "Why don't oysters donate to charity?", "punchline": "Because they're shellfish!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["food", "wordplay"], "setup": "What has ears but cannot hear?", "punchline": "A cornfield!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["food", "work", "wordplay"], "setup": "I used to be a baker,", "punchline": "but I couldn't make enough dough."},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["food", "health", "wordplay"], "setup": "I'm on a seafood diet.", "punchline": "I see food and I eat it."},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["food", "wordplay"], "setup": "I would tell you a joke about pizza,", "punchline": "but it's a little cheesy."},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["school", "wordplay"], "setup": "Why was six afraid of seven?", "punchline": "Because seven eight nine!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["animals", "wordplay"], "setup": "What do you call two birds in love?", "punchline": "Tweethearts!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["technology", "wordplay"], "setup": "Why was the computer cold?", "punchline": "It left its Windows open!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["work", "wordplay"], "setup": "What do lawyers wear to court?", "punchline": "Lawsuits!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["animals", "wordplay"], "setup": "Where do cows go on Friday night?", "punchline": "To the moo-vies!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["animals", "weather", "wordplay"], "setup": "What do you call a bear caught in the rain?", "punchline": "A drizzly bear!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["animals", "music", "wordplay"], "setup": "Why couldn't the pony sing?", "punchline": "Because she was a little hoarse!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["technology", "wordplay"], "setup": "How do trees get on the internet?", "punchline": "They log in!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["animals", "family", "wordplay"], "setup": "What did the buffalo say when his son left for college?", "punchline": "Bison!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["sports", "wordplay"], "setup": "Why did the coach go to the bank?", "punchline": "To get his quarterback!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["food", "wordplay"], "setup": "Why do melons have weddings?", "punchline": "Because they cantaloupe!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["sports", "wordplay"], "setup": "What kind of shoes do ninjas wear?", "punchline": "Sneakers!"},
  {"character": "mr_funny", "type": "dad_joke", "tags": ["sports", "wordplay"], "setup": "I was wondering why the frisbee kept getting bigger.", "punchline": "Then it hit me."},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["food", "wordplay"], "setup": "Knock, knock.\nWho's there?\nLettuce.", "punchline": "Lettuce who?\nLettuce in, it's cold out here!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["wordplay"], "setup": "Knock, knock.\nWho's there?\nBoo.", "punchline": "Boo who?\nDon't cry, it's only a joke!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["wordplay"], "setup": "Knock, knock.\nWho's there?\nTank.", "punchline": "Tank who?\nYou're welcome!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["food", "wordplay"], "setup": "Knock, knock.\nWho's there?\nOlive.", "punchline": "Olive who?\nOlive you, and I miss you!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["health", "wordplay"], "setup": "Knock, knock.\nWho's there?\nAtch.", "punchline": "Atch who?\nBless you!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["wordplay"], "setup": "Knock, knock.\nWho's there?\nHarry.", "punchline": "Harry who?\nHarry up and answer the door!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["animals", "travel", "wordplay"], "setup": "Knock, knock.\nWho's there?\nAlpaca.", "punchline": "Alpaca who?\nAlpaca the suitcase, you load the car!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["food", "wordplay"], "setup": "Knock, knock.\nWho's there?\nCash.", "punchline": "Cash who?\nNo thanks, I prefer peanuts!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["food", "wordplay"], "setup": "Knock, knock.\nWho's there?\nIce cream.", "punchline": "Ice cream who?\nIce cream every time I see a spider!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["food", "wordplay"], "setup": "Knock, knock.\nWho's there?\nJustin.", "punchline": "Justin who?\nJustin time for dinner!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["school", "wordplay"], "setup": "Knock, knock.\nWho's there?\nBroken pencil.", "punchline": "Broken pencil who?\nNever mind, it's pointless."},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["food", "wordplay"], "setup": "Knock, knock.\nWho's there?\nFigs.", "punchline": "Figs who?\nFigs the doorbell, it's not working!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["wordplay"], "setup": "Knock, knock.\nWho's there?\nDishes.", "punchline": "Dishes who?\nDishes the police, open up!"},
  {"character": "mr_funny", "type": "knock_knock", "tags": ["music", "wordplay"], "setup": "Knock, knock.\nWho's there?\nA little old lady.", "punchline": "A little old lady who?\nI didn't know you could yodel!"},
  {"character": "mr_love", "type": "pickup_line", "tags": ["food", "wordplay"], "setup": "If you were a fruit,", "punchline": "you'd be a fine-apple."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["wordplay"], "setup": "Is your name Chapstick?", "punchline": "Because you're da balm!"},
  {"character": "mr_love", "type": "pickup_line", "tags": ["health"], "setup": "Do you have a Band-Aid?", "punchline": "I just scraped my knee falling for you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["animals", "wordplay"], "setup": "Are you a cat?", "punchline": "Because you're purr-fect."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["weather"], "setup": "Is it hot in here,", "punchline": "or is it just you?"},
  {"character": "mr_love", "type": "pickup_line", "tags": ["work", "wordplay"], "setup": "Are you an electrician?", "punchline": "Because you're lighting up my day."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["sports", "wordplay"], "setup": "Do you play soccer?", "punchline": "Because you look like a keeper."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["science", "wordplay"], "setup": "Are you a volcano?", "punchline": "Because I lava you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["wordplay"], "setup": "If beauty were time,", "punchline": "you'd be an eternity."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["science"], "setup": "Are you a star?", "punchline": "Because your beauty lights up the room."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["weather", "wordplay"], "setup": "I must be a snowflake,", "punchline": "because I've fallen for you."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["health", "wordplay"], "setup": "Are you my appendix?", "punchline": "Because I have a funny feeling I should take you out."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["food", "wordplay"], "setup": "You must be made of cheese,", "punchline": "because you're looking Gouda tonight."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["food", "wordplay"], "setup": "Are you a donut?", "punchline": "Because I find you a-dough-rable."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["weather", "health"], "setup": "Do you have a sunburn,", "punchline": "or are you always this hot?"},
  {"character": "mr_love", "type": "pickup_line", "tags": ["wordplay"], "setup": "Is your name Ariel?", "punchline": "Because we mermaid for each other."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["food", "wordplay"], "setup": "Are you a banana?", "punchline": "Because I find you a-peeling."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["health"], "setup": "I'm no organ donor,", "punchline": "but I'd happily give you my heart."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["animals", "travel", "wordplay"], "setup": "Are you Australian?", "punchline": "Because you meet all of my koala-fications."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["animals", "wordplay"], "setup": "If you were a chicken,", "punchline": "you'd be impeccable."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["school", "wordplay"], "setup": "Are you a 90-degree angle?", "punchline": "Because you're looking right."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["wordplay"], "setup": "Is your name Waldo?", "punchline": "Because someone like you is hard to find."},
  {"character": "mr_love", "type": "pickup_line", "tags": ["science", "wordplay"], "setup": "Do you like science?", "punchline": "Because I've got my ion you."},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["wordplay"], "setup": "What did one toilet say to the other?", "punchline": "You look a bit flushed!"},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["animals", "wordplay"], "setup": "Why did Tigger look in the toilet?", "punchline": "He was looking for Pooh!"},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["wordplay"], "setup": "Why couldn't the toilet paper cross the road?", "punchline": "It got stuck in a crack!"},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["wordplay"], "setup": "What's the best hand in bathroom poker?", "punchline": "A royal flush!"},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["animals", "travel", "wordplay"], "setup": "Where do bees go to the bathroom?", "punchline": "At the BP station!"},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["travel", "wordplay"], "setup": "What nationality are you when you're in the bathroom?", "punchline": "European!"},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["animals", "wordplay"], "setup": "What do you call a dinosaur that farts?", "punchline": "A blast from the past!"},
  {"character": "mr_potty", "type": "dad_joke", "tags": ["school", "wordplay"], "setup": "Why did the fart miss graduation?", "punchline": "It got expelled!"},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["work"], "setup": "My boss says I have a preoccupation with vengeance.", "punchline": "We'll see about that."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["health"], "setup": "I told my doctor I broke my arm in two places.", "punchline": "He told me to stop going to those places."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["wordplay"], "setup": "I'd agree with you,", "punchline": "but then we'd both be wrong."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["family"], "setup": "I'm not arguing.", "punchline": "I'm just explaining why I'm right."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["science"], "setup": "Light travels faster than sound.", "punchline": "That's why some people seem bright until they speak."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["technology"], "setup": "I'm not lazy.", "punchline": "I'm on energy-saving mode."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["family"], "setup": "Some people bring joy wherever they go.", "punchline": "You bring it whenever you go."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["school"], "setup": "I'd explain it to you,", "punchline": "but I left my crayons at home."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["wordplay"], "setup": "Everyone has the right to be stupid.", "punchline": "You're just abusing the privilege."},
  {"character": "mr_bad", "type": "dad_joke", "tags": ["wordplay"], "setup": "I never forget a face,", "punchline": "but in your case I'll make an exception."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["food", "work"], "setup": "My wallet is like an onion.", "punchline": "Opening it makes me cry."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["weather", "wordplay"], "setup": "I tried to catch fog yesterday.", "punchline": "Mist."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["health"], "setup": "My bed and I love each other,", "punchline": "but my alarm clock keeps trying to break us up."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["work"], "setup": "I'm great at multitasking.", "punchline": "I can waste time, be unproductive, and procrastinate all at once."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["food", "health"], "setup": "I'm on a 30-day diet.", "punchline": "So far I've lost 15 days."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["work"], "setup": "I started out with nothing,", "punchline": "and I still have most of it."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["health"], "setup": "People ask why I'm always smiling.", "punchline": "It's because I have no idea what's going on."},
  {"character": "mr_sad", "type": "dad_joke", "tags": ["school"], "setup": "I asked the librarian for a book about hope.", "punchline": "She said it was checked out indefinitely."}
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
