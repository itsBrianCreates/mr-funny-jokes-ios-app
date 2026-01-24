# Mr. Funny Jokes

## What This Is

A native iOS joke app featuring character personas (Mr. Funny, Mr. Potty, Mr. Bad, Mr. Love, Mr. Sad) that deliver jokes matching their personality. Users swipe through jokes, rate them with emoji reactions, and see community rankings. The app targets iOS users looking for quick, shareable humor content.

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
- ✓ Weekly Top 10 rankings display — existing
- ✓ Joke of the Day feature — existing
- ✓ Character detail views with pagination — existing
- ✓ Search functionality — existing
- ✓ Me tab showing rated jokes — existing
- ✓ Copy/share joke functionality — existing
- ✓ Offline mode with Firestore cache — existing
- ✓ Skeleton loading screens — existing
- ✓ Haptic feedback — existing
- ✓ Push notifications for daily jokes — existing
- ✓ Home screen widgets (basic) — existing

### Active

- [ ] Change weekly rankings to monthly rankings
- [ ] Remove in-app notification time picker
- [ ] Add iOS Settings guidance text for notification management
- [ ] Polish widgets across all sizes (small, medium, large)
- [ ] Add lock screen widget for Joke of the Day
- [ ] Siri integration — "Hey Siri, tell me a joke" with voice response
- [ ] 500 jokes content across all 5 characters

### Out of Scope

- Character Chat feature — too large for v1.0, saved as v2.0 backup plan
- OAuth/social login — email/password not currently implemented either, no auth needed
- In-app purchases — free app for now
- Android version — iOS only
- Custom notification scheduling UI — using iOS Settings instead

## Context

**App Store Status:** Rejected for Guideline 4.2.2 (Minimum Functionality). Apple considers the current app to be aggregated internet content with limited features. v1.0 must demonstrate deep native iOS integration to pass review.

**Native iOS Features (addressing 4.2.2):**
- Widgets: All sizes + lock screen = native iOS integration
- Siri: App Intents = system-level integration
- Notifications: Native scheduling via iOS Settings
- Haptics: Already implemented

**Backup Plan:** If v1.0 still fails review, escalate to Character Chat feature (PRD at `/Users/brianvanaski/Desktop/PRD Character Chat Feature.md`)

**Content:** Currently low joke count — need 500 jokes to feel populated.

## Constraints

- **Platform**: iOS 18.0+ only — set by existing project
- **Backend**: Firebase Firestore — already integrated, no migration
- **No Auth**: Anonymous users, ratings tied to device ID
- **Timeline**: Ship v1.0 to address App Store rejection

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Monthly rankings instead of weekly | Not enough early users to populate weekly leaderboard | — Pending |
| iOS Settings for notification time | Remove duplicate UI, simpler UX, native iOS pattern | — Pending |
| Siri via App Intents | Modern approach (replaces SiriKit), required for iOS 16+ | — Pending |
| Lock screen widget | Low-effort high-visibility feature for 4.2.2 compliance | — Pending |
| 500 jokes content goal | Enough to feel populated without overwhelming | — Pending |

---
*Last updated: 2025-01-24 after initialization*
