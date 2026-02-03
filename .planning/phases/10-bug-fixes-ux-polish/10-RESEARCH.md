# Phase 10: Bug Fixes & UX Polish - Research

**Researched:** 2026-02-02
**Domain:** iOS SwiftUI / UserDefaults persistence / State management
**Confidence:** HIGH

## Summary

This phase addresses two distinct bugs: (1) Me tab not persisting rated jokes across app sessions, and (2) YouTube promo card lacking dismissal functionality. Both issues stem from well-understood patterns in the existing codebase.

**Me Tab Bug Root Cause:** The `ratedJokes` computed property in `JokeViewModel` filters `jokes.filter { $0.userRating != nil }`. However, when the app restarts, `jokes` array is repopulated from Firestore without applying stored ratings during the initial cache load. The `applyStoredRatings(to:)` method exists in `LocalStorageService` but isn't being called consistently in all load paths.

**YouTube Promo:** The `YouTubePromoCardView` is a simple SwiftUI view with no dismissal state. Requires adding `@AppStorage` or UserDefaults persistence for two states: (1) manual X dismissal, (2) Subscribe button tapped.

**Primary recommendation:** Fix the rating application during joke loading in `JokeViewModel.loadInitialContentAsync()` and add UserDefaults-backed dismissal state to the YouTube promo.

## Standard Stack

### Core (Already in Use)

| Library/Pattern | Version | Purpose | Why Standard |
|-----------------|---------|---------|--------------|
| UserDefaults | iOS 18+ | Persist promo dismissal state | Already used for ratings, impressions, device ID |
| @AppStorage | SwiftUI | Reactive UserDefaults binding | Simpler than manual KVO for simple boolean flags |
| Combine | iOS 18+ | Cross-view communication | Already used for NotificationCenter subscriptions |

### Supporting (Already in Use)

| Library/Pattern | Version | Purpose | When to Use |
|-----------------|---------|---------|-------------|
| LocalStorageService | Custom | Centralized UserDefaults access | All persistence operations |
| NotificationCenter | Foundation | Cross-ViewModel sync | Rating changes across views |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| @AppStorage | LocalStorageService | @AppStorage simpler for single view; LocalStorageService better for shared state across multiple views |
| UserDefaults | SwiftData | Overkill for 2 boolean flags; UserDefaults sufficient |

## Architecture Patterns

### Recommended Pattern for Me Tab Fix

The bug exists because `loadAllCachedJokesAsync()` returns jokes but the JokeViewModel only applies ratings in specific paths. The fix should ensure ratings are always applied after any joke load.

**Pattern: Centralized Rating Application**

```swift
// In JokeViewModel - apply ratings to any joke array
private func applyStoredRatings(to jokes: [Joke]) -> [Joke] {
    return jokes.map { joke in
        var mutableJoke = joke
        mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
        return mutableJoke
    }
}
```

**Current Flow (Bug):**
1. `loadInitialContentAsync()` calls `storage.loadAllCachedJokesAsync()`
2. `loadAllCachedJokesAsync()` internally calls `applyStoredRatings` (in LocalStorageService)
3. However, this only applies ratings to cached jokes, not to fresh Firebase jokes
4. When Firebase fetch completes, it overwrites with fresh jokes but applies ratings correctly
5. **BUG:** If cache is present but ratings were made after cache was written, those ratings are lost

**The Real Bug:** `LocalStorageService.loadAllCachedJokesAsync()` applies ratings from `loadRatingsSync()` dictionary, but the cache JSON itself contains `userRating` values that may be stale. The fix should always re-apply ratings from the authoritative `jokeRatings` UserDefaults key.

### Recommended Pattern for YouTube Promo Dismissal

**Pattern: @AppStorage with View-local State**

```swift
struct YouTubePromoCardView: View {
    // Persistent dismissal state (survives app restart)
    @AppStorage("hasSubscribedToYouTube") private var hasSubscribed = false
    @AppStorage("hasManuallyDismissedYouTubePromo") private var hasManuallyDismissed = false

    // Callback for parent to hide the view
    var onDismiss: () -> Void

    var body: some View {
        // Only show if not dismissed and not subscribed
        if !hasSubscribed && !hasManuallyDismissed {
            // ... existing content ...
        }
    }
}
```

**Alternative: Parent-controlled visibility (recommended)**

```swift
// In JokeFeedView
@AppStorage("youtubePromoHidden") private var promoHidden = false

// Conditional rendering
if showYouTubePromo && !promoHidden {
    YouTubePromoCardView(onDismiss: { promoHidden = true })
}
```

### Anti-Patterns to Avoid

- **Storing dismissal in @State:** Won't persist across app restarts
- **Using environment variables:** Not persisted
- **Relying on joke array position:** Promo position is fixed (4th item), not state-dependent

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Persist boolean flag | Custom file storage | @AppStorage/UserDefaults | Thread-safe, atomic writes, already used |
| Cross-view state sync | Custom observers | NotificationCenter + Combine | Already established pattern in codebase |
| Joke rating lookup | Linear search every render | Cached Set<String> lookup | LocalStorageService already provides `getRatedJokeIds()` |

**Key insight:** The codebase already has all the infrastructure needed. The bugs are logic errors, not missing features.

## Common Pitfalls

### Pitfall 1: Stale Ratings in Cached Jokes

**What goes wrong:** Jokes are cached with their `userRating` value at cache time. If user rates a joke, the rating is saved to UserDefaults but the cached joke still has the old (or nil) rating.

**Why it happens:** `saveCachedJokes` saves the full Joke struct including `userRating`. When loaded later, this cached rating may not match the authoritative `jokeRatings` dictionary.

**How to avoid:** Always call `storage.getRating(for:firestoreId:)` when loading jokes, treating the cached `userRating` as a hint, not truth.

**Warning signs:** Me tab shows empty after app restart, but ratings appear after pull-to-refresh.

### Pitfall 2: @AppStorage Namespace Collision

**What goes wrong:** Two views using the same @AppStorage key can cause unexpected behavior.

**Why it happens:** @AppStorage uses UserDefaults under the hood with the key string as the key.

**How to avoid:** Use descriptive, namespaced keys: `"youtubePromo_dismissed"` not `"dismissed"`.

**Warning signs:** Dismissing promo in one context affects unrelated views.

### Pitfall 3: Subscribe Button vs X Button State Confusion

**What goes wrong:** User taps Subscribe, leaves YouTube, returns to app - promo still shows because dismissal wasn't tracked.

**Why it happens:** Only tracking X button, not Subscribe button action.

**How to avoid:** Track both actions separately: `hasManuallyDismissed` and `hasSubscribed`. Either true hides the promo.

**Warning signs:** Users report promo reappearing after subscribing.

### Pitfall 4: Animation on Dismissal

**What goes wrong:** Promo disappears abruptly without animation when X is tapped.

**Why it happens:** SwiftUI needs explicit animation wrapper for conditional rendering changes.

**How to avoid:** Wrap state change in `withAnimation { promoHidden = true }`.

**Warning signs:** Jarring UX when dismissing promo.

## Code Examples

Verified patterns from the existing codebase:

### Rating Persistence (Current Working Pattern)

```swift
// From LocalStorageService.swift - authoritative rating source
func getRating(for jokeId: UUID, firestoreId: String?) -> Int? {
    let key = firestoreId ?? jokeId.uuidString
    return queue.sync {
        let ratings = self.loadRatingsSync()
        return ratings[key]
    }
}

// From JokeViewModel.swift - applying ratings after Firebase fetch
let jokesWithRatings = newJokes.map { joke -> Joke in
    var mutableJoke = joke
    mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
    return mutableJoke
}
```

### @AppStorage Usage Pattern (for YouTube Promo)

```swift
// Based on standard SwiftUI pattern
struct YouTubePromoCardView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("youtubePromo_dismissed") private var isDismissed = false

    var body: some View {
        if !isDismissed {
            // ... card content ...
            Button("Subscribe") {
                openURL(youtubeURL)
                isDismissed = true  // Hide after Subscribe tap
            }
        }
    }
}
```

### Conditional Rendering with Animation

```swift
// From JokeFeedView.swift - existing animation pattern
.animation(.easeInOut(duration: 0.3), value: viewModel.isOffline)

// Apply same pattern for promo dismissal
if showYouTubePromo && !promoHidden {
    YouTubePromoCardView(onDismiss: {
        withAnimation(.easeInOut(duration: 0.3)) {
            promoHidden = true
        }
    })
    .transition(.opacity.combined(with: .scale(scale: 0.95)))
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| @ObservedObject for simple flags | @AppStorage | iOS 14+ | Simpler syntax for UserDefaults binding |
| Manual KVO for UserDefaults | Combine publishers | Swift 5.5+ | Reactive updates without boilerplate |

**Deprecated/outdated:**
- Using `@State` for persistence: Never persists across app launches
- Using `UserDefaults.standard.synchronize()`: Unnecessary since iOS 12+

## Open Questions

None. Both bugs have clear root causes and straightforward fixes using existing codebase patterns.

## Sources

### Primary (HIGH confidence)

- Codebase analysis: `JokeViewModel.swift` lines 83-107 (ratedJokes computed property)
- Codebase analysis: `LocalStorageService.swift` lines 160-166 (loadRatingsSync)
- Codebase analysis: `YouTubePromoCardView.swift` (full file, no dismissal state)
- Codebase analysis: `JokeFeedView.swift` lines 91-94 (promo insertion logic)

### Secondary (MEDIUM confidence)

- Apple Documentation: @AppStorage property wrapper
- SwiftUI conventions for UserDefaults persistence

### Tertiary (LOW confidence)

- None required - this is a bug fix in well-understood code

## Metadata

**Confidence breakdown:**
- Me Tab Bug: HIGH - Root cause identified through code analysis
- YouTube Promo: HIGH - Missing feature, straightforward implementation
- Persistence Pattern: HIGH - @AppStorage is standard SwiftUI

**Research date:** 2026-02-02
**Valid until:** No expiration - this is internal codebase analysis, not external library research

## Implementation Notes for Planner

### Me Tab Fix Tasks

1. **Investigate exact bug location:** Trace `loadAllCachedJokesAsync()` call in `loadInitialContentAsync()` to confirm ratings are being applied
2. **Verify the issue:** Check if `LocalStorageService.applyStoredRatings(to:)` is being called on cached jokes
3. **Fix:** Ensure `storage.getRating(for:firestoreId:)` is called for every joke after loading from cache
4. **Test:** Rate a joke, close app, reopen - joke should appear in Me tab

### YouTube Promo Tasks

1. **Add X dismiss button:** Overlay button on top-right of promo card
2. **Add @AppStorage state:** `youtubePromo_dismissed` boolean
3. **Track Subscribe tap:** Set dismissed = true when Subscribe button is tapped
4. **Update JokeFeedView:** Check dismissed state before rendering promo
5. **Add animation:** Smooth transition when promo disappears

### Verification Checklist

- [ ] User rates joke, closes app, reopens - joke still in Me tab
- [ ] User pulls to refresh Me tab - rated jokes remain visible
- [ ] User taps X on YouTube promo - promo disappears immediately
- [ ] User taps Subscribe button - promo hidden on next refresh/session
- [ ] User closes and reopens app - promo dismissal state persists
