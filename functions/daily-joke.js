/**
 * Joke of the Day picker.
 *
 * The app and the widget read `daily_jokes/<YYYY-MM-DD>` (the date in Eastern Time)
 * and show the joke its `joke_id` names. With no document for the day each install
 * picks a random joke of its own, so people see different jokes of the day.
 *
 * `ensureDailyJokes` makes sure today and the next few days each have a document.
 * - A day that already has one is left alone, so `scripts/set-daily-joke.js` still
 *   works as a manual override.
 * - A pick is a random joke that has a punchline, is in season on that day, and has
 *   not been the joke of the day in the last 365 days.
 * - A day this picker filled whose joke has since been deleted is picked again.
 *
 * Preview the next picks without writing anything (reads production):
 *   node functions/daily-joke.js
 * Write them (production):
 *   node functions/daily-joke.js --apply
 */

const { FieldValue } = require("firebase-admin/firestore");

const DAILY_JOKES_COLLECTION = "daily_jokes";
const JOKES_COLLECTION = "jokes";
const TIME_ZONE = "America/New_York";

/** Days kept filled, today included, so one missed run leaves no gap */
const DAYS_AHEAD = 7;
/** A joke is not the joke of the day twice within this many days */
const NO_REPEAT_DAYS = 365;
/** If every joke was used in the last year, only this many days are kept apart */
const MIN_REPEAT_DAYS = 30;
/** Marks documents this picker wrote, as opposed to ones set by hand */
const PICKED_BY = "auto";

// ---------- Dates (plain YYYY-MM-DD strings, Eastern Time) ----------

/** Today's date in Eastern Time, e.g. "2026-11-27". Matches the app and the widget. */
function easternDateString(now = new Date()) {
  // en-CA formats as YYYY-MM-DD
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: TIME_ZONE, year: "numeric", month: "2-digit", day: "2-digit",
  }).format(now);
}

function toUtcDate(dateString) {
  const [year, month, day] = dateString.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day));
}

function addDays(dateString, days) {
  const date = toUtcDate(dateString);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function daysBetween(earlier, later) {
  return Math.round((toUtcDate(later) - toUtcDate(earlier)) / 86400000);
}

// ---------- Seasons (the feed seasons in SeasonalHelper.swift) ----------

/** Day of the month of Thanksgiving: the fourth Thursday of November */
function thanksgivingDay(year) {
  const firstWeekday = new Date(Date.UTC(year, 10, 1)).getUTCDay(); // 0 = Sunday
  const firstThursday = 1 + ((4 - firstWeekday + 7) % 7);
  return firstThursday + 21;
}

function isInSeason(tag, dateString) {
  const [year, month, day] = dateString.split("-").map(Number);
  switch (tag) {
    case "christmas": return month === 11 || month === 12;
    case "thanksgiving": return month === 11 && day <= thanksgivingDay(year);
    case "halloween": return month === 10;
    default: return true;
  }
}

const SEASONAL_TAGS = ["christmas", "thanksgiving", "halloween"];

/** A holiday joke outside every one of its seasons. Same rule as `Joke.isOutOfSeason`. */
function isOutOfSeason(tags, dateString) {
  const seasonal = (tags || []).filter((tag) => SEASONAL_TAGS.includes(tag));
  if (seasonal.length === 0) return false;
  return !seasonal.some((tag) => isInSeason(tag, dateString));
}

// ---------- Picking ----------

/** Setup, blank line, punchline: the joke opens on a tap, which the full screen view needs */
function hasPunchline(text) {
  if (typeof text !== "string") return false;
  const parts = text.split(/\n\s*\n/);
  return parts.length >= 2 && parts[0].trim() !== "" && parts.slice(1).join("").trim() !== "";
}

/**
 * Picks the joke for one day.
 * @param {Array<{id: string, text: string, tags: string[]}>} jokes the whole catalog
 * @param {Map<string, string>} usedOn joke ID -> the date nearest to `dateString` it is the joke of the day
 * @returns the joke, or null when the catalog has nothing usable
 */
function pickJoke(jokes, dateString, usedOn, random = Math.random) {
  const usable = jokes.filter((joke) => hasPunchline(joke.text) && !isOutOfSeason(joke.tags, dateString));
  const apart = (joke) => {
    const date = usedOn.get(joke.id);
    return date === undefined ? Infinity : Math.abs(daysBetween(date, dateString));
  };

  let pool = usable.filter((joke) => apart(joke) > NO_REPEAT_DAYS);
  if (pool.length === 0) pool = usable.filter((joke) => apart(joke) > MIN_REPEAT_DAYS);
  if (pool.length === 0) pool = usable;
  if (pool.length === 0) return null;
  return pool[Math.floor(random() * pool.length)];
}

/** Keeps, for each joke, the use nearest to the day being picked */
function recordUse(usedOn, jokeId, date, forDate) {
  const known = usedOn.get(jokeId);
  if (known === undefined || Math.abs(daysBetween(date, forDate)) < Math.abs(daysBetween(known, forDate))) {
    usedOn.set(jokeId, date);
  }
}

/**
 * Makes sure today and the following days each have a joke of the day.
 * @returns {{date: string, jokeId: string, preview: string, action: string}[]} one row per day
 */
async function ensureDailyJokes(db, { now = new Date(), days = DAYS_AHEAD, dryRun = false, random = Math.random } = {}) {
  const today = easternDateString(now);
  const dates = Array.from({ length: days }, (_, offset) => addDays(today, offset));

  const [jokesSnapshot, dailySnapshot] = await Promise.all([
    db.collection(JOKES_COLLECTION).select("text", "tags").get(),
    db.collection(DAILY_JOKES_COLLECTION).get(),
  ]);
  const jokes = jokesSnapshot.docs.map((doc) => ({ id: doc.id, text: doc.get("text"), tags: doc.get("tags") }));
  const jokeIds = new Set(jokes.map((joke) => joke.id));
  const daily = new Map(dailySnapshot.docs.map((doc) => [doc.id, doc.data()]));

  const results = [];
  for (const date of dates) {
    const existing = daily.get(date);
    if (existing && typeof existing.joke_id === "string") {
      const missing = !jokeIds.has(existing.joke_id);
      if (!missing || existing.picked_by !== PICKED_BY) {
        // Set by hand, or still good: never replaced
        results.push({
          date, jokeId: existing.joke_id, preview: existing.joke_preview || "",
          action: missing ? "kept (joke not found, set by hand)" : "kept",
        });
        continue;
      }
    }

    const usedOn = new Map();
    for (const [usedDate, data] of daily) {
      if (usedDate !== date && typeof data.joke_id === "string") recordUse(usedOn, data.joke_id, usedDate, date);
    }
    const joke = pickJoke(jokes, date, usedOn, random);
    if (!joke) {
      results.push({ date, jokeId: "", preview: "", action: "no usable joke" });
      continue;
    }

    const preview = joke.text.substring(0, 100);
    const data = { joke_id: joke.id, joke_preview: preview, picked_by: PICKED_BY };
    if (!dryRun) {
      const ref = db.collection(DAILY_JOKES_COLLECTION).doc(date);
      const stored = { ...data, set_at: FieldValue.serverTimestamp() };
      if (existing) {
        await ref.set(stored);
      } else {
        try {
          // create() fails if someone set the day in the meantime, so a hand-set joke wins
          await ref.create(stored);
        } catch (error) {
          if (error.code !== 6 && error.code !== "already-exists") throw error;
          results.push({ date, jokeId: "", preview: "", action: "kept (set while picking)" });
          continue;
        }
      }
    }
    // Later days in this run must not pick the same joke
    daily.set(date, data);
    results.push({ date, jokeId: joke.id, preview, action: existing ? "replaced (joke was deleted)" : "picked" });
  }
  return results;
}

module.exports = {
  ensureDailyJokes, pickJoke, hasPunchline, isOutOfSeason, isInSeason, thanksgivingDay,
  easternDateString, addDays, daysBetween, DAYS_AHEAD, NO_REPEAT_DAYS,
};

// ---------- Command line: preview, or fill with --apply ----------

if (require.main === module) {
  const path = require("path");
  const fs = require("fs");
  const { initializeApp, cert } = require("firebase-admin/app");
  const { getFirestore } = require("firebase-admin/firestore");

  const apply = process.argv.includes("--apply");
  const keyPath = path.join(__dirname, "..", "scripts", "serviceAccountKey.json");
  if (fs.existsSync(keyPath)) {
    initializeApp({ credential: cert(JSON.parse(fs.readFileSync(keyPath, "utf8"))) });
  } else {
    initializeApp({ projectId: "mr-funny-jokes" });
  }

  ensureDailyJokes(getFirestore(), { dryRun: !apply })
    .then((results) => {
      console.log(apply ? "Joke of the day, written:" : "Joke of the day, preview only (nothing written):");
      for (const row of results) {
        const setup = row.preview.split("\n")[0];
        console.log(`  ${row.date}  ${row.action.padEnd(8)}  ${row.jokeId.padEnd(20)}  ${setup}`);
      }
      process.exit(0);
    })
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
