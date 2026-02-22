# Project Milestones: Mr. Funny Jokes

## v1.0.3 Seasonal Content & Scroll Fix (Shipped: 2026-02-15)

**Delivered:** Seasonal content ranking that demotes Christmas jokes outside their season, plus scroll stability fixes for iOS 18.

**Phases completed:** 11-12 (2 plans total)

**Key accomplishments:**

- Christmas jokes demoted to bottom of all feeds outside Nov 1 - Dec 31 via SeasonalHelper utility
- Stable ForEach identity replacing enumerated pattern — eliminates upward scroll jumps on iOS 18
- Scoped withAnimation at ViewModel mutation sites replacing implicit .animation() on ScrollView
- YouTube promo card extracted as standalone LazyVStack item — no more scroll anchor shifts

**Stats:**

- 6 Swift files modified
- 8,335 lines of Swift
- 2 phases, 2 plans, 4 tasks
- 1 day (2026-02-15)

**Git range:** `046ca73` → `ec3ba7b`

**What's next:** Next milestone based on user feedback and App Store analytics.

---

## v1.0.2 Bug Fixes & UX Polish (Shipped: 2026-02-02)

**Delivered:** Fixed Me tab rating persistence and added YouTube promo dismissal with bonus UX improvements.

**Phases completed:** 10 (1 plan total)

**Key accomplishments:**

- Fixed Me tab bug where rated jokes disappeared after app restart
- Added YouTube promo dismissal with X button (animated, haptic feedback)
- Promo auto-hides when Subscribe button is tapped
- Promo dismissal state persists across app sessions via @AppStorage
- **Bonus:** Me tab now shows most recently rated jokes first
- **Bonus:** Pull-to-refresh properly bounces back to top

**Stats:**

- 9 files modified
- 8,303 lines of Swift
- 1 phase, 1 plan, 2 tasks + 2 bonus fixes
- 1 day (2026-02-02)

**Git range:** `21d9f86` → `a522789`

**What's next:** App Store submission, then v1.1 based on user feedback.

---

## v1.0.1 Content Freshness (Shipped: 2026-01-31)

**Delivered:** Widget background refresh, infinite scroll feed, and cloud-based rankings for content that stays fresh without app launches.

**Phases completed:** 7-9 (6 plans total)

**Key accomplishments:**

- Migrated rankings aggregation to Firebase Cloud Functions (runs daily at midnight ET)
- Added infinite scroll to feed, removing manual "Load More" button
- Feed now prioritizes unrated jokes sorted by popularity score
- All 6 widgets refresh daily via Firestore REST API without app launch
- Widget tap deep links to joke detail sheet with punchline and sharing
- Graceful fallback cache for offline widget experience

**Stats:**

- 39 files created/modified
- 8,215 lines of Swift
- 3 phases, 6 plans, ~18 tasks
- 2 days (Jan 30 → Jan 31, 2026)

**Git range:** `037a513` → `af5e891`

**What's next:** Physical device overnight test, App Store submission, then v1.1 based on user feedback.

---

## v1.0 MVP (Shipped: 2026-01-25)

**Delivered:** Native iOS integration (Siri, widgets, notifications) to address App Store Guideline 4.2.2 rejection.

**Phases completed:** 1-6 (11 plans total)

**Key accomplishments:**

- Added 3 lock screen widgets (circular, rectangular, inline) with vibrant mode support
- Integrated Siri via App Intents with offline caching and visual snippets
- Polished all home screen widgets to match native iOS spacing (8pt/11pt)
- Changed rankings from weekly to monthly for better early-user population
- Simplified notifications with iOS Settings deep link (native pattern)
- Created comprehensive App Store submission materials

**Stats:**

- 75 files created/modified
- 7,816 lines of Swift
- 6 phases, 11 plans, 47 test cases
- 2 days from project init to ship

**Git range:** `1013c5d` → `549abf1`

**What's next:** App Store submission, then v1.1 enhancements based on review feedback.

---


## v1.1.0 Rating Simplification, Save & Me Tab Rework (Shipped: 2026-02-21)

**Delivered:** Simplified rating from 5-point to binary, decoupled saving from rating, redesigned Me tab around saved jokes with rating indicators, and replaced monthly rankings with all-time leaderboard.

**Phases completed:** 13-18 (10 plans total)

**Key accomplishments:**

- Binary rating system (Hilarious/Horrible) replacing 5-emoji slider across all touchpoints
- Three-layer rating migration (UserDefaults + Firestore + Cloud Function) preserving all user history
- All-Time Top 10 leaderboard replacing Monthly Top 10 with daily cloud recomputation
- Save system decoupled from rating — Save button in JokeDetailSheet for personal collection
- Me tab rewired to show saved jokes with swipe-to-unsave and rating indicators
- Consistent action button styling (Save/Copy/Share) with semibold weight and blue/green tint

**Stats:**

- 21 Swift/JS files modified
- +951 / -558 lines changed
- 6 phases, 10 plans
- 4 days (2026-02-18 → 2026-02-21)

**Git range:** `5aaf9f2` → `a6b0a24`

**What's next:** Firebase Analytics integration (v1.1.1).

---


## v1.10 Firebase Analytics (Shipped: 2026-02-22)

**Delivered:** Firebase Analytics integration with lightweight instrumentation of core user interactions — rating, sharing, copying jokes and character selection.

**Phases completed:** 19-20 (2 plans total)

**Key accomplishments:**

- FirebaseAnalytics SPM dependency linked with analytics auto-initialization via existing FirebaseApp.configure()
- AnalyticsService singleton following existing service pattern (HapticManager-style)
- 7 analytics call sites wired into JokeViewModel, CharacterDetailViewModel, and MrFunnyJokesApp
- Fire-and-forget event pattern — calls placed after state mutations, before async Firestore sync
- Events: joke_rated (with character + rating), joke_shared (with share/copy method), character_selected

**Stats:**

- 4 Swift files created/modified
- 800 insertions, 31 deletions
- 2 phases, 2 plans, 4 tasks
- 2 days (2026-02-21 → 2026-02-22)

**Git range:** `1a3e1ba` → `c330a58`

**What's next:** Bug fix milestone based on user testing feedback.

---


## v1.1.0 Bug Fixes (Shipped: 2026-02-22)

**Delivered:** Fixed first-launch unresponsiveness and feed reordering behavior before App Store release.

**Phases completed:** 21-22 (3 plans total)

**Key accomplishments:**

- Pre-warmed haptic engines and deferred ViewModel creation for instant first-launch responsiveness
- Splash screen holds until Firestore background fetch completes — main thread free at first interaction
- Analytics calls moved to Task.detached to avoid blocking share/rate/copy UI
- Impression-tiered feed ordering (unseen > seen-unrated > rated) with session-deferred reordering
- Pull-to-refresh correctly reorders rated jokes to bottom and scrolls to top
- Detail-sheet-open tracking via onView callback wired through view hierarchy

**Stats:**

- 13 files modified
- 1,075 insertions, 46 deletions
- 2 phases, 3 plans, 6 tasks
- 1 day (2026-02-22)

**Git range:** `5b63f53` → `10f9738`

**What's next:** App Store submission for v1.1.0.

---

