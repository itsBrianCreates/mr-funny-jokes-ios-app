# Mr. Funny Jokes

## What This Is

A native iOS joke app featuring character personas (Mr. Funny, Mr. Potty, Mr. Bad, Mr. Love, Mr. Sad) that deliver jokes matching their personality. Users swipe through jokes, rate them with emoji reactions, and see community rankings. The app integrates deeply with iOS through Siri, home screen and lock screen widgets, and native notifications.

## Core Value

Users can instantly get a laugh from character-delivered jokes and share them with friends. If everything else fails, joke delivery and sharing must work.

## Requirements

### Validated

- ✓ SwiftUI app with MVVM architecture — existing
- ✓ 5 character personas with distinct personalities — existing
- ✓ Firebase Firestore backend with jokes collection — existing
- ✓ Joke feed with infinite scroll pagination — existing
- ✓ Category filtering (Dad Jokes, Knock-Knock, Pickup Lines) — existing
- ✓ User rating system (1-5 emoji scale) — existing
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
- ✓ Monthly rankings (30-day window) — v1.0
- ✓ iOS Settings deep link for notifications — v1.0
- ✓ iPhone-only deployment — v1.0

### Active

(Defined with next milestone via /gsd:new-milestone)

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

## Context

**Current State:** v1.0 shipped 2026-01-25 with 7,816 LOC Swift.

**App Store Status:** Submitted for review addressing Guideline 4.2.2 (Minimum Functionality). v1.0 demonstrates deep native iOS integration through:
- 6 widget types (3 home screen + 3 lock screen)
- Siri integration with offline caching
- Native iOS Settings integration for notifications

**Tech Stack:** SwiftUI, Firebase Firestore, WidgetKit, App Intents, UserNotifications

**Known Issues:**
- Backend collection still named "weekly_rankings" while UI shows "Monthly" (cosmetic debt)
- Direct "Hey Siri" voice command triggers iOS built-in jokes (Shortcuts app works reliably)

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

---
*Last updated: 2026-01-25 after v1.0 milestone*
