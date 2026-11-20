/**
 * Remove Duplicate Jokes Script
 *
 * Merges each group of duplicate jokes into one document and deletes the other copies.
 * For each group in DUPLICATE_GROUPS:
 *   - Keeps one copy: a starter joke (shipped in StarterJokes.json) if the group has one,
 *     otherwise the copy with the most rating events, then the highest rating_count,
 *     then the oldest.
 *   - Moves rating events from the other copies onto the kept one, so rankings keep
 *     the votes. Events are one per device per joke per week, so if a device rated
 *     both copies in the same week, only its vote on the kept copy counts.
 *   - Adds the other copies' likes, dislikes and ratings to the kept copy, merges their
 *     tags, and bumps updated_at so installed apps pick up the change on their next sync.
 *   - Points any daily_jokes entry that uses a deleted copy at the kept one.
 *   - Deletes the other copies. Installed apps drop them at their weekly full re-download.
 *
 * Usage:
 *   node remove-duplicate-jokes.js            # Dry run: print the plan, change nothing
 *   node remove-duplicate-jokes.js --apply    # Back up, then merge and delete
 *
 * --apply first writes every deleted joke, moved rating event and changed daily_jokes
 * entry to jokes-backup-duplicates-<timestamp>.json, so they can be restored with the
 * same document IDs.
 *
 * Not repaired: people who saved a deleted copy on their phone lose it from the Me tab
 * (saves are stored on the device by document ID). That is why the kept copy is the one
 * people have rated most.
 *
 * Requirements:
 *   - Firebase service account key file: ./serviceAccountKey.json
 *   - Or set GOOGLE_APPLICATION_CREDENTIALS environment variable
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const JOKES = 'jokes';
const RATING_EVENTS = 'rating_events';
const DAILY_JOKES = 'daily_jokes';
const FIREBASE_PROJECT_ID = 'mr-funny-jokes';
const STARTER_JOKES_PATH = join(__dirname, '..', 'MrFunnyJokes', 'MrFunnyJokes', 'StarterJokes.json');

const APPLY = process.argv.slice(2).includes('--apply');

// Groups of documents that are the same joke (found November 2026 by comparing all
// 799 jokes: same text, or the same setup and punchline reworded). Every group is a
// single character. `joke` is the first copy's text, for reading only.
//
// Left alone on purpose: jokes that share a pun but are different jokes ("Frostbite"
// from a snowman + vampire vs a snowman + dog), a character's own twist on another's
// joke (Mr. Sad's ocean "waved goodbye"), and the boomerang joke, which is filed
// under both Mr. Bad and Mr. Sad.
const DUPLICATE_GROUPS = [
  { joke: "The guy who stole my diary just died. / My thoughts are with his family.", ids: ["1KBRgMuzYyUlL8Rby9Vy", "fu2ATDdpWWTyF9REI5lU"] },
  { joke: "Are you a campfire? / Because you're hot and I want s'more!", ids: ["3W4H5n8NCsqs7ArckgR3", "PnCTui552KRXOXfSjvnl"] },
  { joke: "What do you call a vegetarian with diarrhea? / A salad shooter!", ids: ["9EfWQg646oUWaWIu1YJf", "Rd71k34n0DBNamgTVgZT"] },
  { joke: "Can I follow you home? / Cause my parents always told me to follow my dreams.", ids: ["Cih3xppDLvfqjJkcaIgJ", "N4L5lD0zsybFTSr2bBtF"] },
  { joke: "Are you sure you're not tired? / You've been running through my mind all day.", ids: ["D7ArgVTHrQrdFhFWFnaW", "rguyvhZh6hPmVYtf1xUS"] },
  { joke: "Well, here I am. / What are your other two wishes?", ids: ["E6QFx6AimBL93CJChe86", "GVG8DFX2z9XYIEEEqdpo"] },
  { joke: "If I could rearrange the alphabet, / I'd put \"U\" and \"I\" together.", ids: ["EHEnidDK07wL6DnIqQIw", "xRLph9wKSlMYsOlSn4NV"] },
  { joke: "Is there an airport nearby / or is it my heart taking off?", ids: ["EkwwdgufHSNeqwDp6Y6d", "kNGhZW9BqGUMDlXhEVVy"] },
  { joke: "I'm lost. / Can you give me directions to your heart?", ids: ["JjRMsuNI7ORzxeUykPWt", "ljBnbWlJ60y6FoWmPfG1"] },
  { joke: "I seem to have lost my phone number. / Can I have yours?", ids: ["UO7xzkxF2a9EY3LDvhwW", "u04l4TRDXTUlXpBTvLiW"] },
  { joke: "I don't trust stairs. / They're always up to something.", ids: ["W3HuXhSp9PsPkYtzelFC", "tJGTK5fRDUyfmACYO9ZD"] },
  { joke: "Life without you is like a broken pencil. / Pointless.", ids: ["WMpPhnNVdSVVoneBkEsd", "oc3JBnfPDFQzSIpIqSO2"] },
  { joke: "I used to play piano by ear, / but now I use my hands!", ids: ["XKmFgobOvlWCgIZQw3hA", "z22qaPKGv1G65yyykA1o"] },
  { joke: "What do you call a fake noodle? / An impasta!", ids: ["S5uSITKlASw7eK8q8JUo", "aq50syQh2ocfpXi2PSVV", "nZJ3YAINWWkyD9G9qarg"] },
  { joke: "Why did the scarecrow win an award? / Because he was outstanding in his field!", ids: ["cbIyAyz484gEGikT9En4", "wfngKwF1Pg4cOeV7mxyL"] },
  { joke: "I only know 25 letters of the alphabet. / I don't know Y.", ids: ["ch3kfFSb8GH0e9YNO57g", "hSAvxQ3unhWoTjPUREQb"] },
  { joke: "Are you a parking ticket? / Cause you've got fine written all over you.", ids: ["naEd0GBbGKmfM9kBkFeu", "sWgEdNrwGZbAzfvIpXJ9", "eciVZlIGpxYJVF7J0qb9"] },
  { joke: "Did you hear about the constipated mathematician? / He worked it out with a pencil!", ids: ["q7UDl1sgLe9Jb7ZxnOdP", "u4mZfw4xXnKea5sIOH4J"] },
  { joke: "What do you get when a king farts? / Noble gas!", ids: ["1TCozocF2C3dYbNGg5dM", "s1jCSHv3THjjXB0dCRuC"] },
  { joke: "What do you call Santa when he takes a break? / Santa Pause!", ids: ["81LX8Xrm7n59RXvLPUbE", "o0VVMhPvE4HAvhaNHRZ6", "t4lnhTCO5CdBAkH2jBqP"] },
  { joke: "Do you watch \"Star Wars\"? / Because Yoda only one for me.", ids: ["8QdyGlLEVtWA5iH5SCnz", "Bpc9GI6HR9zrhKjc6QWy"] },
  { joke: "What did one wall say to the other? / I'll meet you at the corner!", ids: ["FAy67C2GxwWgmqlZbn9r", "XiSY5ipiHdnvT46Q0FOy"] },
  { joke: "Is your name Wi-Fi? / Because I'm feeling a connection.", ids: ["Ii7PM6dzLhsqhwuH3kW2", "PcStYqbSR8J4w7IzaH5I", "DmZvdnLPiniLzJwdxFJ0"] },
  { joke: "Why are Christmas trees bad at knitting? / They always drop their needles!", ids: ["M2dMib3uBqY57t8abaEe", "iLDzfNY4r5FtgWfKQTKU"] },
  { joke: "How do you know Santa is real? / You can always sense his presents.", ids: ["PRqENS2kXjd1JsEotUsF", "b4NukuwmaYG1Yb46uIn8"] },
  { joke: "How does the moon style his hair? / Eclipse it!", ids: ["hH0KCaeesimkePWsYiUt", "hXefqBYNEyRIuHOO6lAl"] },
  { joke: "I must be in a museum, / because you truly are a work of art.", ids: ["1uBh2cjZmkSIsgJWIpyy", "xmPvf7YTg8vokJlTe8QO"] },
  { joke: "Poop jokes aren't my favorite kind of jokes… / but they're a solid number two!", ids: ["3Ya9KbrXhgOwn49vJUOL", "DU5BsBp5kVDPl3oK5tQQ"] },
  { joke: "Why do ducks have feathers? / To cover their butt quack!", ids: ["3syqy8zoozsE9sKtZnZC", "VzeQFfEQTxSwUWq3uB4O"] },
  { joke: "As I get older, I remember all the people I lost along the way. / Maybe being a tour guide wasn't for me.", ids: ["6JX9yXMX3taZnvwqz1bX", "g0DbIRv22dwK0UOsoHNC"] },
  { joke: "My grief counselor died. / He was so good I don't even care.", ids: ["7PoF4TP1lTZHL0EO8liT", "LqbzvpDy4jVqKGhf0Wot"] },
  { joke: "Are you from Tennessee? / Because you're the only 10 I see.", ids: ["GA0XEkKM9D9mMcVpJoGr", "bPg09c8aGqMBFAzG68Z5"] },
  { joke: "Want to hear a joke about construction? / I'm still working on it.", ids: ["GEEXTBQcuxlbZFcaQ2ON", "Zj1Yt7GRFUeYgDO8gVFz"] },
  { joke: "Are you Google? / Because you have everything I'm searching for.", ids: ["JdC9IZCBy98hl1DhG50z", "w7311z3MGbnNpviGM6ll"] },
  { joke: "Why do seagulls fly over the ocean? / Because if they flew over the bay, we'd call them bagels!", ids: ["Nx4RM8jbCg7zPiYA51XJ", "Zrb2gFwOWmzqqEjJMVrN"] },
  { joke: "What do you call a fish with no eyes? / Fshhhh!", ids: ["Okcds6hRzkM0Mgo5jXy0", "x9r1Kt3OowSaXRJx0YK7"] },
  { joke: "I childproofed my house. / Somehow they still got in!", ids: ["QlNm3F4VKwyTNRmzf40I", "cR2arVivd7aKOOnqmXne"] },
  { joke: "Are you made of copper and tellurium? / Because you're Cu-Te.", ids: ["SoHXKEoo8M0Nn6Cj4PJD", "oFB8o5smp4WfvmrUkOSl"] },
  { joke: "Do you believe in love at first sight? / Or should I pass by again?", ids: ["FjEF8KD9RifIKckk2pVc", "w0wkli5wrNYGVAj6uuKC", "bw5DVfzu9x1E5aGBiA8K"] },
  { joke: "Do you have a map? / Because I just got lost in your eyes!", ids: ["kVENV9W8moCdVul8PGiS", "trE29KODZJON7F6ni9cs"] },
  { joke: "Why did the Elf go to school? / To improve his elf-abet!", ids: ["Mmb3srNluswyQYkr1noO", "eFjQocMHOiAZ9KMvFopa"] },
  { joke: "What does Santa use to clean his sleigh? / Santa-tizer.", ids: ["QWPN1gtwPg7SahmTliXM", "m4c7tBTA6QyF2L6AsVYf"] },
];

const log = {
  info: (msg) => console.log(`[INFO] ${msg}`),
  warn: (msg) => console.log(`[WARN] ${msg}`),
  error: (msg) => console.error(`[ERROR] ${msg}`),
  success: (msg) => console.log(`[SUCCESS] ${msg}`),
  divider: () => console.log('='.repeat(70))
};

function initializeFirebase() {
  const serviceAccountPath = join(__dirname, 'serviceAccountKey.json');
  if (existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
    initializeApp({ credential: cert(serviceAccount) });
    log.info(`Connected to project: ${serviceAccount.project_id}`);
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    initializeApp();
    log.info(`Using GOOGLE_APPLICATION_CREDENTIALS: ${process.env.GOOGLE_APPLICATION_CREDENTIALS}`);
  } else {
    initializeApp({ projectId: FIREBASE_PROJECT_ID });
    log.info('Using Application Default Credentials');
  }
  return getFirestore();
}

function loadStarterIds() {
  const data = JSON.parse(readFileSync(STARTER_JOKES_PATH, 'utf8'));
  return new Set(data.jokes.map((j) => j.firestoreId));
}

const preview = (text) => (text || '').replace(/\n+/g, ' / ').slice(0, 70);

/** Starter joke first, then most rating events, then highest rating_count, then oldest. */
function pickKeeper(copies, starterIds) {
  return [...copies].sort((a, b) =>
    (starterIds.has(b.id) - starterIds.has(a.id)) ||
    (b.events.length - a.events.length) ||
    ((b.data.rating_count || 0) - (a.data.rating_count || 0)) ||
    (a.createTime.toMillis() - b.createTime.toMillis())
  )[0];
}

/** Reads a group from Firestore and works out what to change. Returns null to skip it. */
async function planGroup(db, group, starterIds) {
  const copies = [];
  for (const id of group.ids) {
    const snap = await db.collection(JOKES).doc(id).get();
    if (!snap.exists) continue; // already removed by an earlier run
    const events = await db.collection(RATING_EVENTS).where('joke_id', '==', id).get();
    const daily = await db.collection(DAILY_JOKES).where('joke_id', '==', id).get();
    copies.push({ id, data: snap.data(), createTime: snap.createTime, events: events.docs, daily: daily.docs });
  }

  if (copies.length < 2) return null;
  if (new Set(copies.map((c) => c.data.character)).size > 1) {
    log.warn(`Skipping "${group.joke}": copies belong to different characters`);
    return null;
  }
  if (copies.filter((c) => starterIds.has(c.id)).length > 1) {
    log.warn(`Skipping "${group.joke}": more than one copy is a starter joke`);
    return null;
  }

  const keeper = pickKeeper(copies, starterIds);
  const removed = copies.filter((c) => c !== keeper);

  // Rating events are keyed deviceId_jokeId_weekId. Move each onto the keeper unless
  // that device already has an event for the keeper in the same week.
  const taken = new Set(keeper.events.map((e) => `${e.data().device_id}|${e.data().week_id}`));
  const eventMoves = [];
  for (const copy of removed) {
    for (const event of copy.events) {
      const e = event.data();
      const key = `${e.device_id}|${e.week_id}`;
      const target = taken.has(key) ? null : `${e.device_id}_${keeper.id}_${e.week_id}`;
      if (target) taken.add(key);
      eventMoves.push({ from: event, target });
    }
  }

  const sum = (field) => copies.reduce((n, c) => n + (c.data[field] || 0), 0);
  const ratingCount = sum('rating_count');
  const ratingSum = sum('rating_sum');
  const tags = [...new Set(copies.flatMap((c) => c.data.tags || []))];

  return {
    group, keeper, removed, eventMoves,
    dailyMoves: removed.flatMap((c) => c.daily),
    keeperUpdate: {
      likes: sum('likes'),
      dislikes: sum('dislikes'),
      rating_count: ratingCount,
      rating_sum: ratingSum,
      rating_avg: ratingCount > 0 ? ratingSum / ratingCount : 0,
      tags,
      updated_at: FieldValue.serverTimestamp()
    }
  };
}

function printPlan(plan, starterIds) {
  const { keeper, removed, eventMoves, dailyMoves } = plan;
  const label = (c) => `${c.id}  ${c.events.length} rating events, rating_count ${c.data.rating_count || 0}` +
    (starterIds.has(c.id) ? ', starter joke' : '');
  console.log(`\n${keeper.data.character}: "${preview(keeper.data.text)}"`);
  console.log(`  keep    ${label(keeper)}`);
  for (const c of removed) console.log(`  delete  ${label(c)}  "${preview(c.data.text)}"`);
  const moved = eventMoves.filter((m) => m.target).length;
  const dropped = eventMoves.length - moved;
  if (eventMoves.length) console.log(`  rating events: ${moved} moved to the kept copy, ${dropped} dropped (same device rated both that week)`);
  if (dailyMoves.length) console.log(`  daily_jokes: ${dailyMoves.map((d) => d.id).join(', ')} repointed to the kept copy`);
}

async function applyPlan(db, plan) {
  const batch = db.batch();
  const jokes = db.collection(JOKES);
  batch.update(jokes.doc(plan.keeper.id), plan.keeperUpdate);
  for (const { from, target } of plan.eventMoves) {
    if (target) batch.set(db.collection(RATING_EVENTS).doc(target), { ...from.data(), joke_id: plan.keeper.id });
    batch.delete(from.ref);
  }
  for (const daily of plan.dailyMoves) batch.update(daily.ref, { joke_id: plan.keeper.id });
  for (const copy of plan.removed) batch.delete(jokes.doc(copy.id));
  await batch.commit(); // one group per batch: well under the 500-write limit
}

async function main() {
  log.divider();
  log.info(`Remove duplicate jokes: ${APPLY ? 'APPLY' : 'DRY RUN (pass --apply to make changes)'}`);
  log.divider();

  const db = initializeFirebase();
  const starterIds = loadStarterIds();

  const plans = [];
  for (const group of DUPLICATE_GROUPS) {
    const plan = await planGroup(db, group, starterIds);
    if (plan) {
      plans.push(plan);
      printPlan(plan, starterIds);
    }
  }

  const deleteCount = plans.reduce((n, p) => n + p.removed.length, 0);
  log.divider();
  log.info(`${plans.length} groups, ${deleteCount} documents to delete`);

  if (!APPLY || plans.length === 0) {
    if (plans.length === 0) log.info('Nothing to do: every group is already down to one copy.');
    else log.info('Dry run only. Run again with --apply to make these changes.');
    return;
  }

  const backupPath = join(__dirname, `jokes-backup-duplicates-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
  const backup = plans.map((p) => ({
    kept: { id: p.keeper.id, before: p.keeper.data },
    deleted: p.removed.map((c) => ({ id: c.id, data: c.data })),
    ratingEvents: p.eventMoves.map((m) => ({ id: m.from.id, data: m.from.data(), movedTo: m.target })),
    dailyJokes: p.dailyMoves.map((d) => ({ id: d.id, data: d.data() }))
  }));
  writeFileSync(backupPath, JSON.stringify(backup, null, 2));
  log.success(`Backup written: ${backupPath}`);

  let done = 0;
  for (const plan of plans) {
    try {
      await applyPlan(db, plan);
      done += plan.removed.length;
    } catch (error) {
      log.error(`Failed on "${preview(plan.keeper.data.text)}": ${error.message}`);
      log.error('Earlier groups are done. Fix the problem and run again; finished groups are skipped.');
      process.exit(1);
    }
  }

  log.divider();
  log.success(`Deleted ${done} duplicate documents across ${plans.length} groups.`);
  log.info('All-time rankings rebuild at midnight; they include the moved votes from then on.');
}

main().catch((error) => {
  log.error(error.stack || error.message);
  process.exit(1);
});
