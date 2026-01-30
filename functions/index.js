/**
 * Cloud Functions for Mr. Funny Jokes - Rankings Aggregation
 *
 * Migrated from scripts/aggregate-weekly-rankings.js
 *
 * Exports:
 * - aggregateRankings: Scheduled function (daily at midnight ET)
 * - triggerAggregation: HTTP endpoint for manual triggering
 *
 * Rating logic:
 * - Ratings 4-5 = "hilarious"
 * - Ratings 1-2 = "horrible"
 * - Rating 3 = neutral (not counted)
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

// Initialize at module scope (not inside handler) for better cold start performance
initializeApp();
const db = getFirestore();

// Configuration constants (match existing script)
const RATING_EVENTS_COLLECTION = "rating_events";
const WEEKLY_RANKINGS_COLLECTION = "weekly_rankings";
const TOP_N = 10;

/**
 * Get current ISO week ID in Eastern Time (e.g., "2026-W04")
 * Ported from existing aggregate-weekly-rankings.js
 */
function getCurrentWeekId() {
  const now = new Date();

  // Convert to Eastern Time
  const eastern = new Date(now.toLocaleString("en-US", { timeZone: "America/New_York" }));

  // Get ISO week number
  const startOfYear = new Date(eastern.getFullYear(), 0, 1);
  const days = Math.floor((eastern - startOfYear) / (24 * 60 * 60 * 1000));
  const weekNumber = Math.ceil((days + startOfYear.getDay() + 1) / 7);

  return `${eastern.getFullYear()}-W${String(weekNumber).padStart(2, "0")}`;
}

/**
 * Get week start and end dates for a given week ID
 */
function getWeekDateRange(weekId) {
  const [year, weekPart] = weekId.split("-W");
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
 * Fetch rating events for a week from Firestore
 */
async function fetchRatingEvents(weekId) {
  const snapshot = await db.collection(RATING_EVENTS_COLLECTION)
    .where("week_id", "==", weekId)
    .get();

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
 * Sort and rank top N jokes by count
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
async function saveWeeklyRankings(weekId, rankings) {
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

  await db.collection(WEEKLY_RANKINGS_COLLECTION).doc(weekId).set(document);
}

/**
 * Core aggregation logic - shared by scheduled and HTTP triggers
 */
async function runAggregation(weekId = null) {
  const targetWeek = weekId || getCurrentWeekId();
  logger.info(`Processing week: ${targetWeek}`);

  const events = await fetchRatingEvents(targetWeek);
  logger.info(`Found ${events.length} rating events`);

  if (events.length === 0) {
    logger.warn("No rating events found for this week");
  }

  const { hilariousCounts, horribleCounts, totalHilarious, totalHorrible } = aggregateRatings(events);
  const hilariousTop10 = rankTopN(hilariousCounts);
  const horribleTop10 = rankTopN(horribleCounts);

  logger.info(`Top ${hilariousTop10.length} hilarious jokes identified`);
  logger.info(`Top ${horribleTop10.length} horrible jokes identified`);

  await saveWeeklyRankings(targetWeek, {
    hilarious: hilariousTop10,
    horrible: horribleTop10,
    totalHilarious,
    totalHorrible
  });

  logger.info(`Saved weekly rankings for ${targetWeek}`);

  return {
    weekId: targetWeek,
    eventsProcessed: events.length,
    hilariousTop10Count: hilariousTop10.length,
    horribleTop10Count: horribleTop10.length,
    totalHilariousRatings: totalHilarious,
    totalHorribleRatings: totalHorrible
  };
}

// ============================================
// SCHEDULED FUNCTION: Daily at midnight ET
// ============================================
exports.aggregateRankings = onSchedule({
  schedule: "0 0 * * *",           // Daily at midnight
  timeZone: "America/New_York",    // Eastern Time
  retryCount: 3,                   // Retry on failure
  memory: "256MiB"                 // Sufficient for Firestore queries
}, async (event) => {
  logger.info("Scheduled aggregation started");
  try {
    const result = await runAggregation();
    logger.info("Scheduled aggregation complete", result);
  } catch (error) {
    logger.error("Scheduled aggregation failed", { error: error.message, stack: error.stack });
    throw error; // Re-throw to trigger retry
  }
});

// ============================================
// HTTP FUNCTION: Manual trigger endpoint
// ============================================
exports.triggerAggregation = onRequest(async (req, res) => {
  logger.info("Manual aggregation triggered", {
    method: req.method,
    query: req.query
  });

  // Optional: Allow specifying a week via query param
  const weekId = req.query.week || null;

  try {
    const result = await runAggregation(weekId);
    res.status(200).json({
      success: true,
      message: "Aggregation complete",
      result
    });
  } catch (error) {
    logger.error("Manual aggregation failed", { error: error.message });
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});
