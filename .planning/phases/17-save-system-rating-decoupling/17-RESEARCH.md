# Phase 17: Save System & Rating Decoupling - Research

**Researched:** 2026-02-20
**Domain:** SwiftUI state management, UserDefaults persistence, data migration
**Confidence:** HIGH

## Summary

Phase 17 decouples the "save" concept from the "rate" concept. Currently, the Me tab shows jokes the user has rated (via `ratedJokes`, `hilariousJokes`, `horribleJokes` computed properties in `JokeViewModel`). After this phase, the Me tab will show jokes the user has explicitly saved, independently of whether they rated them. Rating continues to exist for the All-Time Top 10 system but no longer drives the Me tab.

The implementation is entirely client-side SwiftUI + UserDefaults. No new libraries are needed. No Firestore schema changes are required. The work involves: (1) adding a save/unsave persistence layer in `LocalStorageService`, (2) adding a Save button to `JokeDetailSheet`, (3) rewiring `MeView` to display saved jokes instead of rated jokes, (4) migrating all previously-rated joke IDs into the saved collection on first launch, and (5) propagating save state through the existing notification/communication patterns.

**Primary recommendation:** Model the save system as a parallel track to the existing rating system in `LocalStorageService` -- a `savedJokeIds` Set<String> and `savedTimestamps` dictionary, following the exact same patterns as `jokeRatings` and `jokeRatingTimestamps`. Wire save state into `Joke` model via a new `isSaved` property. Reuse existing cross-ViewModel notification patterns for save state synchronization.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 18+ | UI framework | Already in use, native to the project |
| UserDefaults | Foundation | Save state persistence | Already used for ratings, impressions, cache -- proven pattern in this codebase |
| Combine | Foundation | Cross-ViewModel sync | Already used for `NotificationCenter` publishers between ViewModels |

### Supporting

No new libraries needed. This phase uses only what already exists in the project.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UserDefaults for saves | SwiftData / CoreData | Overkill for a simple ID set; adds migration complexity, breaks consistency with rating storage pattern |
| `isSaved` property on Joke model | Separate lookup at display time | Adding to model keeps it consistent with `userRating` pattern and simplifies view logic |
| NotificationCenter for save sync | Combine PassthroughSubject | NotificationCenter already established for rating sync; no reason to diverge |

## Architecture Patterns

### Recommended Changes (by file)

```
LocalStorageService.swift    # Add save/unsave methods + migration
Joke.swift                   # Add isSaved: Bool property
JokeViewModel.swift          # Add savedJokes computed property, save/unsave methods, migration trigger
CharacterDetailViewModel.swift  # Add save notification posting (mirrors rating notification)
JokeDetailSheet.swift        # Add Save/Saved toggle button between rating and Copy/Share
MeView.swift                 # Rewire from ratedJokes to savedJokes, remove segmented control
JokeCardView.swift           # No changes needed (rating indicator stays)
CharacterDetailView.swift    # Pass onSave callback through CharacterJokeCardView
Notification.Name extension  # Add .jokeSaveDidChange notification
```

### Pattern 1: Save Persistence (mirrors rating persistence)

**What:** Store saved joke IDs and timestamps in UserDefaults, parallel to ratings
**When to use:** All save/unsave operations
**Example:**
```swift
// In LocalStorageService
private let savedJokesKey = "savedJokeIds"
private let savedTimestampsKey = "savedJokeTimestamps"

func saveJoke(firestoreId: String) {
    queue.sync {
        var saved = self.loadSavedIdsSync()
        saved.insert(firestoreId)
        self.saveSavedIdsSync(saved)

        var timestamps = self.loadSavedTimestampsSync()
        timestamps[firestoreId] = Date().timeIntervalSince1970
        self.saveSavedTimestampsSync(timestamps)
    }
}

func unsaveJoke(firestoreId: String) {
    queue.sync {
        var saved = self.loadSavedIdsSync()
        saved.remove(firestoreId)
        self.saveSavedIdsSync(saved)

        var timestamps = self.loadSavedTimestampsSync()
        timestamps.removeValue(forKey: firestoreId)
        self.saveSavedTimestampsSync(timestamps)
    }
}

func isJokeSaved(firestoreId: String) -> Bool {
    queue.sync {
        loadSavedIdsSync().contains(firestoreId)
    }
}
```

### Pattern 2: Joke Model Extension

**What:** Add `isSaved` to Joke struct, applied the same way `userRating` is applied
**When to use:** When loading/displaying jokes
**Example:**
```swift
// In Joke.swift -- add isSaved property
struct Joke: Identifiable, Codable, Equatable {
    // ... existing properties ...
    var isSaved: Bool  // New -- defaults to false

    // CodingKeys must include isSaved with decodeIfPresent for backward compat
}

// In JokeViewModel -- apply save state like ratings are applied
let jokesWithState = newJokes.map { joke -> Joke in
    var mutableJoke = joke
    mutableJoke.userRating = storage.getRating(for: joke.id, firestoreId: joke.firestoreId)
    let key = joke.firestoreId ?? joke.id.uuidString
    mutableJoke.isSaved = storage.isJokeSaved(firestoreId: key)
    return mutableJoke
}
```

### Pattern 3: Save Button in JokeDetailSheet

**What:** Toggle button below rating section, above Copy/Share
**When to use:** JokeDetailSheet layout
**Example:**
```swift
// In JokeDetailSheet -- between BinaryRatingView and Divider/actions
Button {
    onSave()
    HapticManager.shared.lightTap()
} label: {
    HStack {
        Image(systemName: joke.isSaved ? "person.fill" : "person")
            .contentTransition(.symbolEffect(.replace))
        Text(joke.isSaved ? "Saved" : "Save")
    }
    .frame(maxWidth: .infinity, minHeight: 24)
    .padding(.vertical, 14)
}
.buttonStyle(.bordered)
.tint(joke.isSaved ? .accessibleYellow : .gray)
```

### Pattern 4: MeView Rewiring

**What:** Replace rated-joke display with saved-joke display
**When to use:** MeView body
**Example:**
```swift
// In JokeViewModel -- replace ratedJokes/hilariousJokes/horribleJokes for Me tab
var savedJokes: [Joke] {
    let saved = jokes.filter { $0.isSaved }
    return saved.sorted { joke1, joke2 in
        let t1 = storage.getSavedTimestamp(for: joke1.firestoreId ?? joke1.id.uuidString) ?? 0
        let t2 = storage.getSavedTimestamp(for: joke2.firestoreId ?? joke2.id.uuidString) ?? 0
        return t1 > t2  // Most recently saved first
    }
}

// MeView -- simplified, no segmented control
// Each row shows the joke setup + rating indicator if rated
```

### Pattern 5: Data Migration (rated -> saved)

**What:** One-time migration at app launch converting all rated joke IDs into saved joke IDs
**When to use:** First launch after update, gated by UserDefaults flag
**Example:**
```swift
// In LocalStorageService
private let ratedToSavedMigrationKey = "hasMigratedRatedToSaved"

func migrateRatedToSavedIfNeeded() {
    guard !userDefaults.bool(forKey: ratedToSavedMigrationKey) else { return }

    queue.sync {
        let ratings = self.loadRatingsSync()
        let ratingTimestamps = self.loadRatingTimestampsSync()
        var savedIds = self.loadSavedIdsSync()
        var savedTimestamps = self.loadSavedTimestampsSync()

        for (jokeId, _) in ratings {
            savedIds.insert(jokeId)
            // Preserve the rating timestamp as the save timestamp
            if let ts = ratingTimestamps[jokeId] {
                savedTimestamps[jokeId] = ts
            } else {
                savedTimestamps[jokeId] = Date().timeIntervalSince1970
            }
        }

        self.saveSavedIdsSync(savedIds)
        self.saveSavedTimestampsSync(savedTimestamps)
    }

    userDefaults.set(true, forKey: ratedToSavedMigrationKey)
}
```

### Pattern 6: Cross-ViewModel Save Notification

**What:** Mirror the `.jokeRatingDidChange` pattern for saves
**When to use:** When saves happen in CharacterDetailViewModel
**Example:**
```swift
// New notification name
extension Notification.Name {
    static let jokeSaveDidChange = Notification.Name("jokeSaveDidChange")
}

// Post from CharacterDetailViewModel.saveJoke()
NotificationCenter.default.post(
    name: .jokeSaveDidChange,
    object: nil,
    userInfo: [
        "firestoreId": firestoreId as Any,
        "jokeId": joke.id,
        "isSaved": newSavedState,
        "jokeData": jokeData as Any
    ]
)

// Subscribe in JokeViewModel.init()
NotificationCenter.default.publisher(for: .jokeSaveDidChange)
    .receive(on: DispatchQueue.main)
    .sink { [weak self] notification in
        self?.handleSaveNotification(notification)
    }
    .store(in: &cancellables)
```

### Anti-Patterns to Avoid

- **Storing saved state only in Joke model (no persistence):** The Joke struct is a value type that gets rebuilt on every fetch. Save state MUST be stored in UserDefaults and reapplied, just like `userRating` is.
- **Using @State array for saved jokes in MeView:** Per CLAUDE.md "Value Copy Pitfall" -- store IDs, not joke copies. Use computed property that looks up fresh data from `viewModel.jokes`.
- **Removing rating from JokeDetailSheet:** Rating stays -- it serves the All-Time Top 10 system. Only the Me tab connection is severed.
- **Putting .animation() on MeView's List:** Per CLAUDE.md "Animation on Scroll Containers Pitfall" -- use `withAnimation` at mutation site in ViewModel.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Save state persistence | Custom file-based storage | UserDefaults (existing `LocalStorageService` pattern) | Consistency with rating persistence; thread-safe queue already exists |
| Cross-ViewModel sync | Custom pub/sub system | `NotificationCenter` (existing `.jokeRatingDidChange` pattern) | Already proven pattern; avoid divergent communication channels |
| Save button toggle animation | Custom animation state machine | SwiftUI `.contentTransition(.symbolEffect(.replace))` | Native iOS 17+ symbol animation; already used for Copy button |

**Key insight:** This phase is an extension of existing patterns, not new architecture. Every building block (UserDefaults persistence, notification sync, model property application, toggle buttons, list views) already exists in the codebase. The work is wiring, not inventing.

## Common Pitfalls

### Pitfall 1: Forgetting to Apply Save State After Fetch
**What goes wrong:** Jokes loaded from Firestore or cache don't show correct save state in UI
**Why it happens:** `isSaved` is not stored in Firestore or the joke cache -- it must be applied from UserDefaults after every load, just like `userRating`
**How to avoid:** Apply save state in every code path that creates/loads jokes -- search for all places `userRating` is applied via `storage.getRating()` and add parallel `storage.isJokeSaved()` calls
**Warning signs:** Jokes appear unsaved after app restart or pull-to-refresh despite being saved

### Pitfall 2: Migration Not Running Before Cache Preload
**What goes wrong:** First launch shows empty Me tab despite having rated jokes
**Why it happens:** Migration must run before `preloadMemoryCacheAsync()` reads saved IDs into memory
**How to avoid:** Call `migrateRatedToSavedIfNeeded()` in the same PHASE 0 slot where `migrateRatingsToBinaryIfNeeded()` runs in `loadInitialContentAsync()`
**Warning signs:** Me tab empty on first launch after update, but works after force-quit and relaunch

### Pitfall 3: Save State Not Synced from CharacterDetailView
**What goes wrong:** User saves a joke in character detail view, navigates to Me tab -- joke doesn't appear
**Why it happens:** `CharacterDetailViewModel` doesn't post save notifications, so `JokeViewModel` doesn't know about the save
**How to avoid:** Post `.jokeSaveDidChange` notification from `CharacterDetailViewModel.saveJoke()`, and handle it in `JokeViewModel` -- exact same pattern as rating notification
**Warning signs:** Save works on home feed but not in character detail view

### Pitfall 4: Not Passing onSave Through All JokeDetailSheet Entry Points
**What goes wrong:** Save button doesn't appear or doesn't work from some screens
**Why it happens:** `JokeDetailSheet` is instantiated in 6 places: `JokeCardView`, `CharacterJokeCardView`, `MeView`, `JokeOfTheDayView`, `RankedJokeCard`, and `MainContentView` (deep link sheet). Missing `onSave` in any causes compile error or missing functionality
**How to avoid:** When adding `onSave` parameter to `JokeDetailSheet`, update ALL call sites. Search for `JokeDetailSheet(` across the codebase
**Warning signs:** Compile errors in multiple files after adding parameter

### Pitfall 5: Removing Segmented Control Breaks Empty State
**What goes wrong:** `MeView` empty state references "No Rated Jokes Yet" text
**Why it happens:** Existing empty state checks `viewModel.ratedJokes.isEmpty` and uses rating-specific copy
**How to avoid:** Update empty state check to `viewModel.savedJokes.isEmpty` and update copy to "No Saved Jokes Yet" / "Save jokes to build your collection"
**Warning signs:** Incorrect messaging in Me tab when user has no saved jokes

### Pitfall 6: Swipe-to-Delete in MeView Removes Rating Instead of Unsaving
**What goes wrong:** Swiping to delete in Me tab removes the rating (sends rating 0) instead of unsaving
**Why it happens:** Current `MeView` swipe action calls `viewModel.rateJoke(joke, rating: 0)` which removes the rating. After decoupling, it should call `viewModel.unsaveJoke(joke)` instead
**How to avoid:** Replace the swipe-to-delete action with unsave behavior. Keep the rating intact
**Warning signs:** Swipe-to-delete in Me tab also removes the user's Hilarious/Horrible rating

## Code Examples

### All JokeDetailSheet Instantiation Sites (must all be updated)

```
1. JokeCardView.swift:81        -- sheet(isPresented: $showingSheet)
2. CharacterDetailView.swift:273 -- CharacterJokeCardView sheet
3. MeView.swift:112             -- sheet(isPresented: Binding(...))
4. JokeOfTheDayView.swift       -- (check if separate or reuses JokeCardView)
5. RankedJokeCard.swift          -- sheet for ranked joke cards
6. MrFunnyJokesApp.swift:193    -- deep link JOTD sheet
```

All six sites need the `onSave` callback added.

### UserDefaults Key Naming (consistency with existing)

```swift
// Existing keys in LocalStorageService:
private let ratingsKey = "jokeRatings"           // [String: Int]
private let ratingTimestampsKey = "jokeRatingTimestamps"  // [String: TimeInterval]
private let impressionsKey = "jokeImpressions"   // [String]

// New keys (follow same pattern):
private let savedJokesKey = "savedJokeIds"       // [String] (array of firestoreId strings)
private let savedTimestampsKey = "savedJokeTimestamps"  // [String: TimeInterval]
```

### Save State Application Points (every place ratings are applied)

These are all the code paths where `storage.getRating()` is called to apply ratings. Each one needs a parallel `storage.isJokeSaved()` call:

```
JokeViewModel.swift:
  - loadInitialContentAsync() line ~328 (cached jokes)
  - fetchInitialAPIContent() line ~473 (initial API load)
  - fetchInitialAPIContentBackground() line ~530 (background API load)
  - refresh() line ~618 (pull-to-refresh)
  - loadFullCatalogInBackground() line ~690 (background catalog)
  - performLoadMore() line ~767 (infinite scroll)
  - handleRatingNotification() -- needs parallel handleSaveNotification()
  - jokeOfTheDay computed property line ~146 (JOTD fallback)

CharacterDetailViewModel.swift:
  - loadJokes() line ~111 (initial load)
  - loadMoreJokes() line ~157 (infinite scroll)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Rating drives Me tab | Save drives Me tab | Phase 17 | Me tab shows saved jokes, not rated jokes |
| Me tab has Hilarious/Horrible segments | Me tab is a flat saved-jokes list | Phase 17 | Simpler UI, date-sorted |
| No save concept exists | Save/Unsave toggle in joke sheet | Phase 17 | New user interaction |

**Deprecated/outdated after this phase:**
- `JokeViewModel.ratedJokes` -- no longer used for Me tab (keep for potential other uses, or remove if dead)
- `JokeViewModel.hilariousJokes` / `horribleJokes` -- no longer used for Me tab (may be dead code if only used by MeView)
- `MeView` segmented control + `selectedType` state
- `MeView` `currentJokes` computed property

## Open Questions

1. **Should `ratedJokes`, `hilariousJokes`, `horribleJokes` be deleted from JokeViewModel?**
   - What we know: After rewiring MeView, these computed properties may have no remaining consumers
   - What's unclear: Are they used anywhere else (e.g., SearchView, AllTimeTopTenDetailView)?
   - Recommendation: Grep for usage. If only MeView uses them, delete. If used elsewhere, keep. Based on codebase review: `ratedJokes` is used only in `MeView` (line 40). `hilariousJokes` and `horribleJokes` are used only in `MeView`. These can be removed. However, the `ratedJokes` computed property guards the empty state in MeView -- this check needs to change to `savedJokes.isEmpty`.

2. **Should the person icon be filled when saved (`person.fill`) or use a different indicator?**
   - What we know: Requirements say "person icon" for Save button; Me tab already uses `person.fill` as its tab icon
   - What's unclear: Exact visual design (filled vs outline, color when saved)
   - Recommendation: Use `person` (outline) for unsaved state, `person.fill` for saved state. Tint with `.accessibleYellow` when saved to match app branding. This mirrors the tab bar icon reinforcing "save to My collection."

3. **Should the JokeOfTheDayView have a save button inline or only in the detail sheet?**
   - What we know: Requirements specify Save button in "joke detail sheet" (SAVE-01, SAVE-02)
   - What's unclear: Whether JokeOfTheDayView (which is a hero card, not a sheet) should also have inline save
   - Recommendation: Save only in the detail sheet for now. The JOTD hero card opens the detail sheet on tap, so the save button is accessible. Phase 18 (Me Tab Redesign) may add further UX improvements.

## Sources

### Primary (HIGH confidence)
- Codebase inspection: `LocalStorageService.swift` -- established UserDefaults patterns for ratings, timestamps, impressions, and migration
- Codebase inspection: `JokeViewModel.swift` -- rating application pattern across all load paths, notification handling
- Codebase inspection: `CharacterDetailViewModel.swift` -- cross-ViewModel notification posting pattern
- Codebase inspection: `JokeDetailSheet.swift` -- current layout (rating section position, action buttons)
- Codebase inspection: `MeView.swift` -- current rated-joke display with segmented control
- Codebase inspection: `Joke.swift` -- model structure with `userRating` optional property pattern
- CLAUDE.md -- Bug prevention patterns (Value Copy Pitfall, Animation on Scroll Containers Pitfall)

### Secondary (MEDIUM confidence)
- SwiftUI `.contentTransition(.symbolEffect(.replace))` -- used for Copy button animation in `JokeDetailSheet`, suitable for Save toggle

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- no new libraries; pure extension of existing patterns
- Architecture: HIGH -- every pattern is modeled on existing rating system code
- Pitfalls: HIGH -- identified from actual codebase analysis (all load paths, all sheet instantiation sites)

**Research date:** 2026-02-20
**Valid until:** 2026-03-20 (stable -- no external dependencies to change)
