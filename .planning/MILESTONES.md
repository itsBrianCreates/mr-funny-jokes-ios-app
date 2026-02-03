# Project Milestones: Mr. Funny Jokes

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
