# Mr. Funny Jokes

## What This Is

A native iOS joke app featuring character personas (Mr. Funny, Mr. Potty, Mr. Bad, Mr. Love, Mr. Sad) that deliver jokes matching their personality. Users swipe through jokes, rate them as Hilarious or Horrible, and see all-time community rankings. The app integrates deeply with iOS through Siri, home screen and lock screen widgets that refresh daily, native notifications, and infinite scroll feeds that prioritize fresh content. Seasonal content is automatically ranked — holiday jokes step aside outside their season.

## Core Value

Users can instantly get a laugh from character-delivered jokes and share them with friends. If everything else fails, joke delivery and sharing must work.

## Requirements

### Validated

- ✓ SwiftUI app with MVVM architecture — existing
- ✓ 5 character personas with distinct personalities — existing
- ✓ Firebase Firestore backend with jokes collection — existing
- ✓ Joke feed with infinite scroll pagination — existing
- ✓ Category filtering (Dad Jokes, Knock-Knock, Pickup Lines) — existing
- ✓ Local rating persistence with UserDefaults — existing
- ✓ Joke of the Day feature — existing
- ✓ Character detail views with pagination — existing
- ✓ Search functionality — existing
- ✓ Me tab showing rated jokes — existing
- ✓ Copy/share joke functionality — existing
- ✓ Offline mode with Firestore cache — existing
- ✓ Skeleton loading screens — existing
- ✓ Haptic feedback — existing
- ✓ Push notifications for daily jokes — existing
- ✓ Home screen widgets (small, medium, large) — v1.0
- ✓ Lock screen widgets (circular, rectangular, inline) — v1.0
- ✓ Siri integration via App Intents — v1.0
- ✓ iOS Settings deep link for notifications — v1.0
- ✓ iPhone-only deployment — v1.0
- ✓ Widgets update daily in background without app launch — v1.0.1
- ✓ Joke feed prioritizes unrated jokes over already-rated ones — v1.0.1
- ✓ Full joke catalog loads automatically in background (no manual "Load More") — v1.0.1
- ✓ Rankings aggregation runs in cloud (Firebase Cloud Functions) — v1.0.1
- ✓ Me tab correctly persists and displays rated jokes across sessions — v1.0.2
- ✓ YouTube promo card can be dismissed with X button — v1.0.2
- ✓ YouTube promo auto-hides after user clicks Subscribe button — v1.0.2
- ✓ Christmas/holiday jokes demoted to bottom of feed outside Nov 1 - Dec 31 — v1.0.3
- ✓ Christmas/holiday jokes rank normally by popularity during Nov 1 - Dec 31 — v1.0.3
- ✓ Seasonal demotion applies to all feed contexts (main, character, category-filtered) — v1.0.3
- ✓ Smooth upward scrolling without position jumps on iOS 18+ — v1.0.3
- ✓ Stable scroll position during background content loading — v1.0.3
- ✓ Conditional content (promo card, carousel) doesn't destabilize scroll anchors — v1.0.3
- ✓ Binary rating system (Hilarious/Horrible) replaces 5-emoji scale — v1.1.0
- ✓ Rating UI uses two-button binary choice with haptic feedback — v1.1.0
- ✓ Existing 1-5 ratings migrated: 4-5 → Hilarious, 1-2 → Horrible, 3s dropped — v1.1.0
- ✓ All-Time Top 10 replaces Monthly Top 10 — v1.1.0
- ✓ Cloud Function recomputes all-time rankings daily — v1.1.0
- ✓ Me tab redesigned with Hilarious/Horrible segmented control matching Top 10 screen — v1.1.0
- ✓ Feature branch `v1.1.0` created before any code changes — v1.1.0

### Active

(No active requirements — define with next milestone)

### Out of Scope

- Character Chat feature — too large for v1.0, saved as v2.0 backup plan
- OAuth/social login — email/password not currently implemented either, no auth needed
- In-app purchases — free app for now
- Android version — iOS only
- Custom notification scheduling UI — using iOS Settings instead
- Character-specific Siri commands — deferred to v2
- Interactive widget buttons — not needed for 4.2.2 compliance
- Control Center widget — iOS 18+ only, defer to v2
- iPad support — iPhone-only simplifies testing
- Aggressive background refresh — battery drain risk, removed in v1.0.1 research
- Firebase SDK in widget extension — deadlock issue #13070
- Multi-holiday seasonal system — just Christmas for now; extend later if needed
- Server-side seasonal ranking — client-side sort modification is simpler and sufficient
- Monthly rankings retention — not enough users; all-time accumulates value
- 3-point or 4-point rating scale — binary is simpler and proven (Netflix/YouTube pattern)

## Context

**Current State:** v1.1.0 shipped. Binary rating system (Hilarious/Horrible) and All-Time Top 10 leaderboard are live. App ready for App Store submission.

**Tech Stack:** SwiftUI, Firebase Firestore, Firebase Cloud Functions, WidgetKit, App Intents, UserNotifications

**Codebase:** 8,150 lines of Swift across main app and widget extension. 433 jokes in Firestore.

**Known Issues:**
- Backend collection named "weekly_rankings" but stores all-time data (cosmetic debt, accepted)
- Direct "Hey Siri" voice command triggers iOS built-in jokes (Shortcuts app works reliably)
- Local crontab entry needs manual removal (Cloud Functions now handle aggregation)
- daily_jokes population is manual (consider automating via Cloud Function)

## Constraints

- **Platform**: iOS 18.0+ only — set by existing project
- **Backend**: Firebase Firestore — already integrated, no migration
- **No Auth**: Anonymous users, ratings tied to device ID
- **App Store**: Must pass Guideline 4.2.2 review

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Monthly rankings instead of weekly | Not enough early users to populate weekly leaderboard | ✓ Good |
| iOS Settings for notification time | Remove duplicate UI, simpler UX, native iOS pattern | ✓ Good |
| Siri via App Intents | Modern approach (replaces SiriKit), required for iOS 16+ | ✓ Good |
| Lock screen widgets | Low-effort high-visibility feature for 4.2.2 compliance | ✓ Good |
| SF Symbol for circular lock screen widget | Character images don't render in vibrant mode | ✓ Good |
| Client-side category filtering | Firestore query missed non-standard type values | ✓ Good |
| Shortcuts app for Siri (not voice) | Direct voice triggers iOS built-in jokes; Shortcuts reliable | ✓ Good |
| Firestore REST API for widgets | Avoids SDK deadlock issue #13070 | ✓ Good |
| Background load on first scroll | Preserves app launch performance | ✓ Good |
| Session-rated visibility | Rated jokes stay visible until pull-to-refresh for smoother UX | ✓ Good |
| Archive local cron scripts | Enables quick rollback if Cloud Functions issues arise | ✓ Good |
| Node.js 20 for Cloud Functions | Required by firebase-functions v7; v18 deprecated | ✓ Good |
| Explicit rating re-application in loadInitialContentAsync | Consistency with all other load paths | ✓ Good |
| @AppStorage for promo dismissal | Simple persistent state without extra infrastructure | ✓ Good |
| Rating timestamps for Me tab sorting | Most recently rated jokes appear first | ✓ Good |
| Christmas season = Nov 1 - Dec 31 | Users experience seasons locally; broad window for holiday spirit | ✓ Good |
| Only "christmas" tag triggers demotion | "holidays" tag unaffected; precise targeting avoids false positives | ✓ Good |
| Seasonal demotion at filteredJokes level | Applied after all other filters; clean separation of concerns | ✓ Good |
| Scoped withAnimation over implicit .animation() | Prevents scroll container animation interference on iOS 18 | ✓ Good |
| YouTube promo as standalone LazyVStack item | Prevents scroll anchor shifts from conditional content in ForEach | ✓ Good |
| Binary rating (Hilarious/Horrible) over 5-point scale | Simpler UX, cleaner data for Top 10, consistent Me tab/Top 10 UI | ✓ Good |
| All-Time Top 10 over Monthly | Not enough users for meaningful monthly rankings; all-time accumulates value | ✓ Good |
| Migrate existing ratings (4-5→Hilarious, 1-2→Horrible, drop 3s) | Preserves user history for All-Time rankings | ✓ Good |
| Feature branch for v1.1.0 | Easy revert if changes aren't satisfactory | ✓ Good |
| Keep Int type for ratings (1 and 5) | Minimizes cascading type changes across codebase | ✓ Good |
| Keep weekly_rankings collection name | Pragmatic — avoids Firestore migration, use all_time document ID | ✓ Good |
| Keep GrainOMeterView.swift filename | Avoids Xcode project file modifications for a rename | ✓ Good |
| Tap buttons instead of drag gesture for binary rating | Clearer UX for a two-option choice | ✓ Good |

---
*Last updated: 2026-02-18 after v1.1.0 milestone*
