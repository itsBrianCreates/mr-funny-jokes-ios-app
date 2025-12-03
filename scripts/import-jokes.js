import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Load service account key
const serviceAccountPath = join(__dirname, '..', 'firebase-key.json');

if (!existsSync(serviceAccountPath)) {
  console.error('Error: firebase-key.json not found!');
  console.error(`Expected location: ${serviceAccountPath}`);
  console.error('\nTo fix this:');
  console.error('1. Go to Firebase Console > Project Settings > Service accounts');
  console.error('2. Click "Generate new private key"');
  console.error('3. Save the file as "firebase-key.json" in the project root');
  process.exit(1);
}

const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));

// Initialize Firebase Admin
initializeApp({
  credential: cert(serviceAccount),
  projectId: 'mr-funny-jokes'
});

const db = getFirestore();

// Sample jokes data - 20 jokes across 5 characters (4 jokes each)
const jokes = [
  // Mr. Funny - Dad Jokes (4 jokes)
  {
    id: 'dad_001',
    text: 'Why don\'t scientists trust atoms? Because they make up everything!',
    type: 'dad_joke',
    character: 'mr_funny',
    tags: ['science'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'dad_002',
    text: 'What do you call a fake noodle? An impasta!',
    type: 'dad_joke',
    character: 'mr_funny',
    tags: ['food'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'dad_003',
    text: 'Why did the scarecrow win an award? Because he was outstanding in his field!',
    type: 'dad_joke',
    character: 'mr_funny',
    tags: ['work', 'animals'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'dad_004',
    text: 'I used to hate facial hair, but then it grew on me.',
    type: 'dad_joke',
    character: 'mr_funny',
    tags: ['health'],
    sfw: true,
    source: 'classic'
  },

  // Mr. Bad - Dark Jokes (4 jokes)
  {
    id: 'bad_001',
    text: 'Why don\'t skeletons fight each other? They don\'t have the guts.',
    type: 'dark_joke',
    character: 'mr_bad',
    tags: ['health'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'bad_002',
    text: 'I have a fish that can breakdance! Only for 20 seconds though, and only once.',
    type: 'dark_joke',
    character: 'mr_bad',
    tags: ['animals'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'bad_003',
    text: 'My grandfather has the heart of a lion and a lifetime ban from the zoo.',
    type: 'dark_joke',
    character: 'mr_bad',
    tags: ['family', 'animals'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'bad_004',
    text: 'I told my wife she was drawing her eyebrows too high. She looked surprised.',
    type: 'dark_joke',
    character: 'mr_bad',
    tags: ['family'],
    sfw: true,
    source: 'classic'
  },

  // Mr. Sad - Sad Jokes (4 jokes)
  {
    id: 'sad_001',
    text: 'Why did the calendar feel lonely? Because its days were numbered.',
    type: 'sad_joke',
    character: 'mr_sad',
    tags: ['work'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'sad_002',
    text: 'What did the ocean say to the shore? Nothing, it just waved goodbye.',
    type: 'sad_joke',
    character: 'mr_sad',
    tags: ['travel'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'sad_003',
    text: 'Why don\'t eggs tell jokes? They\'d crack up and fall apart.',
    type: 'sad_joke',
    character: 'mr_sad',
    tags: ['food'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'sad_004',
    text: 'I stayed up all night wondering where the sun went. Then it dawned on me.',
    type: 'sad_joke',
    character: 'mr_sad',
    tags: ['science'],
    sfw: true,
    source: 'classic'
  },

  // Mr. Potty - Potty Jokes (4 jokes)
  {
    id: 'potty_001',
    text: 'Why did the toilet paper roll down the hill? To get to the bottom!',
    type: 'potty_joke',
    character: 'mr_potty',
    tags: ['health'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'potty_002',
    text: 'What do you call a bear with no teeth? A gummy bear!',
    type: 'potty_joke',
    character: 'mr_potty',
    tags: ['animals', 'food'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'potty_003',
    text: 'Why did the chicken go to the bathroom? To get to the other side!',
    type: 'potty_joke',
    character: 'mr_potty',
    tags: ['animals'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'potty_004',
    text: 'What do you call a dinosaur that crashes their car? Tyrannosaurus Wrecks!',
    type: 'potty_joke',
    character: 'mr_potty',
    tags: ['animals', 'travel'],
    sfw: true,
    source: 'classic'
  },

  // Mr. Love - Pickup Lines (4 jokes)
  {
    id: 'love_001',
    text: 'Are you a magician? Because whenever I look at you, everyone else disappears!',
    type: 'pickup_line',
    character: 'mr_love',
    tags: ['tech'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'love_002',
    text: 'Do you have a map? Because I just got lost in your eyes!',
    type: 'pickup_line',
    character: 'mr_love',
    tags: ['travel'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'love_003',
    text: 'Is your name Google? Because you have everything I\'ve been searching for!',
    type: 'pickup_line',
    character: 'mr_love',
    tags: ['tech'],
    sfw: true,
    source: 'classic'
  },
  {
    id: 'love_004',
    text: 'Are you a Wi-Fi signal? Because I\'m feeling a connection!',
    type: 'pickup_line',
    character: 'mr_love',
    tags: ['tech'],
    sfw: true,
    source: 'classic'
  }
];

async function importJokes() {
  console.log('Starting joke import...\n');

  const batch = db.batch();
  const jokesRef = db.collection('jokes');
  const now = Timestamp.now();

  for (const joke of jokes) {
    const docRef = jokesRef.doc(joke.id);
    batch.set(docRef, {
      text: joke.text,
      type: joke.type,
      character: joke.character,
      tags: joke.tags,
      sfw: joke.sfw,
      source: joke.source,
      created_at: now,
      rating_count: 0,
      rating_sum: 0,
      rating_avg: 0,
      likes: 0,
      dislikes: 0,
      popularity_score: 0
    });
    console.log(`Prepared: ${joke.id} (${joke.character}) - ${joke.type}`);
  }

  await batch.commit();
  console.log(`\nSuccessfully imported ${jokes.length} jokes to Firestore!`);

  // Print summary
  const characterCounts = {};
  const typeCounts = {};

  for (const joke of jokes) {
    characterCounts[joke.character] = (characterCounts[joke.character] || 0) + 1;
    typeCounts[joke.type] = (typeCounts[joke.type] || 0) + 1;
  }

  console.log('\n--- Summary ---');
  console.log('By Character:');
  for (const [char, count] of Object.entries(characterCounts)) {
    console.log(`  ${char}: ${count} jokes`);
  }

  console.log('\nBy Type:');
  for (const [type, count] of Object.entries(typeCounts)) {
    console.log(`  ${type}: ${count} jokes`);
  }
}

importJokes()
  .then(() => {
    console.log('\nImport complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Error importing jokes:', error);
    process.exit(1);
  });
