/**
 * Aggregate Weekly Rankings Script
 *
 * Aggregates rating_events into weekly_rankings for the Top 10 jokes feature.
 *
 * Ratings 4-5 = "hilarious"
 * Ratings 1-2 = "horrible"
 *
 * Usage:
 *   node aggregate-weekly-rankings.js              # Aggregate current week
 *   node aggregate-weekly-rankings.js --dry-run    # Simulate without making changes
 *   node aggregate-weekly-rankings.js --week 2025-W04  # Aggregate specific week
 *
 * Requirements:
 *   - Firebase service account key file: ./serviceAccountKey.json
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { readFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const RATING_EVENTS_COLLECTION = 'rating_events';
const WEEKLY_RANKINGS_COLLECTION = 'weekly_rankings';
const FIREBASE_PROJECT_ID = 'mr-funny-jokes';
const TOP_N = 10; // Top 10 jokes

// Parse command line arguments
const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const weekArgIndex = args.indexOf('--week');
const SPECIFIC_WEEK = weekArgIndex !== -1 ? args[weekArgIndex + 1] : null;

// Logging utilities
const log = {
  info: (msg) => console.log(`[INFO] ${new Date().toISOString()} - ${msg}`),
  warn: (msg) => console.log(`[WARN] ${new Date().toISOString()} - ${msg}`),
  error: (msg) => console.error(`[ERROR] ${new Date().toISOString()} - ${msg}`),
  success: (msg) => console.log(`[SUCCESS] ${new Date().toISOString()} - ${msg}`),
  divider: () => console.log('='.repeat(70))
};

/**
 * Get current ISO week ID in Eastern Time (e.g., "2025-W04")
 */
function getCurrentWeekId() {
  const now = new Date();

  // Convert to Eastern Time
  const eastern = new Date(now.toLocaleString('en-US', { timeZone: 'America/New_York' }));

  // Get ISO week number
  const startOfYear = new Date(eastern.getFullYear(), 0, 1);
  const days = Math.floor((eastern - startOfYear) / (24 * 60 * 60 * 1000));
  const weekNumber = Math.ceil((days + startOfYear.getDay() + 1) / 7);

  return `${eastern.getFullYear()}-W${String(weekNumber).padStart(2, '0')}`;
}

/**
 * Get week start and end dates for a given week ID
 */
function getWeekDateRange(weekId) {
  const [year, weekPart] = weekId.split('-W');
  const weekNum = parseInt(weekPart, 10);

  // January 4th is always in week 1 of ISO calendar
  const jan4 = new Date(parseInt(year), 0, 4);
  const dayOfWeek = jan4.getDay() || 7; // Sunday = 7

  // Monday of week 1
  const week1Monday = new Date(jan4);
  week1Monday.setDate(jan4.getDate() - dayOfWeek + 1);

  // Monday of target week
  const weekStart = new Date(week1Monday);
  weekStart.setDate(week1Monday.getDate() + (weekNum - 1) * 7);
  weekStart.setHours(0, 0, 0, 0);

  // Sunday of target week (end)
  const weekEnd = new Date(weekStart);
  weekEnd.setDate(weekStart.getDate() + 6);
  weekEnd.setHours(23, 59, 59, 999);

  return { weekStart, weekEnd };
}

/**
 * Initialize Firebase Admin SDK
 */
function initializeFirebase() {
  const serviceAccountPath = join(__dirname, 'serviceAccountKey.json');

  if (!existsSync(serviceAccountPath)) {
    log.error('Service account key not found at: ' + serviceAccountPath);
    log.info('Please download from Firebase Console > Project Settings > Service Accounts');
    process.exit(1);
  }

  const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));

  initializeApp({
    credential: cert(serviceAccount),
    projectId: FIREBASE_PROJECT_ID
  });

  return getFirestore();
}

/**
 * Fetch all rating events for a specific week
 */
async function fetchRatingEvents(db, weekId) {
  log.info(`Fetching rating events for week: ${weekId}`);

  const snapshot = await db.collection(RATING_EVENTS_COLLECTION)
    .where('week_id', '==', weekId)
    .get();

  log.info(`Found ${snapshot.size} rating events`);
  return snapshot.docs.map(doc => doc.data());
}

/**
 * Aggregate ratings into hilarious and horrible counts
 */
function aggregateRatings(events) {
  const hilariousCounts = {}; // joke_id -> count of 4-5 ratings
  const horribleCounts = {};  // joke_id -> count of 1-2 ratings

  let totalHilarious = 0;
  let totalHorrible = 0;

  for (const event of events) {
    const jokeId = event.joke_id;
    const rating = event.rating;

    if (rating >= 4) {
      // Hilarious (4-5)
      hilariousCounts[jokeId] = (hilariousCounts[jokeId] || 0) + 1;
      totalHilarious++;
    } else if (rating <= 2) {
      // Horrible (1-2)
      horribleCounts[jokeId] = (horribleCounts[jokeId] || 0) + 1;
      totalHorrible++;
    }
    // Rating 3 is neutral, not counted
  }

  return { hilariousCounts, horribleCounts, totalHilarious, totalHorrible };
}

/**
 * Sort and rank top N jokes
 */
function rankTopN(counts, n = TOP_N) {
  const sorted = Object.entries(counts)
    .map(([jokeId, count]) => ({ jokeId, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, n);

  return sorted.map((entry, index) => ({
    joke_id: entry.jokeId,
    count: entry.count,
    rank: index + 1
  }));
}

/**
 * Save weekly rankings to Firestore
 */
async function saveWeeklyRankings(db, weekId, rankings) {
  const { weekStart, weekEnd } = getWeekDateRange(weekId);

  const document = {
    week_id: weekId,
    week_start: Timestamp.fromDate(weekStart),
    week_end: Timestamp.fromDate(weekEnd),
    hilarious: rankings.hilarious,
    horrible: rankings.horrible,
    total_hilarious_ratings: rankings.totalHilarious,
    total_horrible_ratings: rankings.totalHorrible,
    computed_at: FieldValue.serverTimestamp()
  };

  if (DRY_RUN) {
    log.info('[DRY RUN] Would save document:');
    console.log(JSON.stringify(document, null, 2));
    return;
  }

  await db.collection(WEEKLY_RANKINGS_COLLECTION).doc(weekId).set(document);
  log.success(`Saved weekly rankings for ${weekId}`);
}

/**
 * Main execution
 */
async function main() {
  log.divider();
  log.info('Weekly Rankings Aggregation Script');
  log.divider();

  if (DRY_RUN) {
    log.warn('DRY RUN MODE - No changes will be made');
  }

  const db = initializeFirebase();
  const weekId = SPECIFIC_WEEK || getCurrentWeekId();

  log.info(`Processing week: ${weekId}`);

  // Fetch rating events
  const events = await fetchRatingEvents(db, weekId);

  if (events.length === 0) {
    log.warn('No rating events found for this week');
    log.info('The weekly rankings document will have empty arrays');
  }

  // Aggregate ratings
  const { hilariousCounts, horribleCounts, totalHilarious, totalHorrible } = aggregateRatings(events);

  log.info(`Total hilarious ratings (4-5): ${totalHilarious}`);
  log.info(`Total horrible ratings (1-2): ${totalHorrible}`);

  // Rank top 10
  const hilariousTop10 = rankTopN(hilariousCounts);
  const horribleTop10 = rankTopN(horribleCounts);

  log.info(`Top ${hilariousTop10.length} hilarious jokes:`);
  hilariousTop10.forEach(j => log.info(`  #${j.rank}: ${j.joke_id} (${j.count} votes)`));

  log.info(`Top ${horribleTop10.length} horrible jokes:`);
  horribleTop10.forEach(j => log.info(`  #${j.rank}: ${j.joke_id} (${j.count} votes)`));

  // Save to Firestore
  await saveWeeklyRankings(db, weekId, {
    hilarious: hilariousTop10,
    horrible: horribleTop10,
    totalHilarious,
    totalHorrible
  });

  log.divider();
  log.success('Aggregation complete!');
}

main().catch(err => {
  log.error('Script failed: ' + err.message);
  console.error(err);
  process.exit(1);
});
