# Phase 14: Binary Rating UI - Research

**Researched:** 2026-02-18
**Domain:** SwiftUI rating UI, codebase refactoring (5-point to binary)
**Confidence:** HIGH

## Summary

Phase 14 replaces the existing 5-emoji slider (`GroanOMeterView`) with a binary segmented control (Hilarious/Horrible) across the entire app. The codebase already uses Int values `1` and `5` for the binary ratings internally (decided in Phase 13), and the local migration from 5-point to binary has already been completed. This phase is purely a UI transformation -- no data model or storage changes needed.

The scope is well-contained: one rating input view (`GroanOMeterView`), one compact indicator view (`CompactGroanOMeterView`), one model property (`ratingEmoji`), and the Me tab's 5-section grouped list need updating. The `onRate: (Int) -> Void` callback signature used throughout stays the same -- it will pass `1` (Horrible) or `5` (Hilarious). The clamping logic in both ViewModels (`min(max(rating, 1), 5)`) still works correctly since only `1` and `5` are produced.

**Primary recommendation:** Replace `GroanOMeterView` with a native SwiftUI `Picker(.segmented)` using two options (Hilarious/Horrible), update `CompactGroanOMeterView` to show only the binary emoji, update `Joke.ratingEmoji` to only map 1 and 5, and collapse the Me tab from 5 sections to 2.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 18+ | All UI components | Already the project's UI framework |
| UIKit (HapticManager) | iOS 18+ | Haptic feedback | Existing pattern via `HapticManager.shared` |

### Supporting
No additional libraries needed. SwiftUI's native `Picker` with `.segmented` style provides the exact UI pattern required.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Native `Picker(.segmented)` | Custom `HStack` with buttons | Custom gives more visual control but segmented control is the iOS standard for binary choice and matches the existing Top 10 detail view pattern already in `MonthlyTopTenDetailView` |

## Architecture Patterns

### Pattern 1: Replace GroanOMeterView with Binary Segmented Control
**What:** Replace the custom 5-emoji drag-gesture slider with a simple SwiftUI `Picker(.segmented)` containing two options.
**When to use:** When the old `GroanOMeterView` is currently rendered (only in `JokeDetailSheet`, line 48).
**Example:**
```swift
// New BinaryRatingView replaces GroanOMeterView
struct BinaryRatingView: View {
    let currentRating: Int?
    let onRate: (Int) -> Void

    private var selectedOption: RatingOption? {
        guard let rating = currentRating else { return nil }
        switch rating {
        case 5: return .hilarious
        case 1: return .horrible
        default: return nil
        }
    }

    enum RatingOption: String, CaseIterable, Identifiable {
        case hilarious = "Hilarious"
        case horrible = "Horrible"
        var id: String { rawValue }
        var emoji: String {
            switch self {
            case .hilarious: return "😂"
            case .horrible: return "🫠"
            }
        }
        var rating: Int {
            switch self {
            case .hilarious: return 5
            case .horrible: return 1
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rate joke")
                .font(.headline)

            // Two-button segmented control
            HStack(spacing: 12) {
                ForEach(RatingOption.allCases) { option in
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onRate(option.rating)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(option.emoji)
                            Text(option.rawValue)
                                .font(.subheadline.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedOption == option
                                ? option == .hilarious ? Color.green.opacity(0.2) : Color.red.opacity(0.2)
                                : Color(.tertiarySystemFill)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    selectedOption == option
                                        ? option == .hilarious ? Color.green : Color.red
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
```

### Pattern 2: Update CompactGroanOMeterView for Binary
**What:** Simplify the compact emoji indicator on feed cards to only handle ratings 1 and 5.
**Where used:** `JokeCardView` (line 72), `CharacterJokeCardView` (line 264), `JokeOfTheDayView` (line 106).
**Example:**
```swift
struct CompactRatingView: View {
    let rating: Int?

    var body: some View {
        if let rating = rating {
            switch rating {
            case 5: Text("😂").font(.callout)
            case 1: Text("🫠").font(.callout)
            default: EmptyView()
            }
        }
    }
}
```

### Pattern 3: Collapse Me Tab from 5 Sections to 2
**What:** The Me tab currently shows 5 rating sections (Hilarious/Funny/Meh/Groan-worthy/Horrible). Collapse to just Hilarious and Horrible.
**Where:** `MeView.swift` and the computed properties in `JokeViewModel` (`funnyJokes`, `mehJokes`, `groanJokes`, `filteredFunnyJokes`, `filteredMehJokes`, `filteredGroanJokes`).

### Anti-Patterns to Avoid
- **Leaving stale 5-point references:** Search for all `ratingEmojis`, `ratingOptions`, emoji arrays `["🫠", "😩", "😐", "😄", "😂"]` and replace/remove them. The old array at `Joke.ratingEmojis` and `Joke.ratingEmoji` switch statement must be updated.
- **Forgetting the MonthlyTopTenDetailView empty state text:** Line 127 still references "5 stars" and "1 star" -- update to "Hilarious" and "Horrible".
- **Leaving `clampedRating = min(max(rating, 1), 5)` without validation:** While technically still valid, both ViewModels should only receive `1` or `5` from the new UI. The clamping is harmless but consider adding an assertion for clarity.

## Inventory of Files to Change

### Rating Input (GroanOMeterView replacement)
| File | What Changes | Lines |
|------|-------------|-------|
| `Views/GrainOMeterView.swift` | Replace `GroanOMeterView` with binary segmented control; replace `CompactGroanOMeterView` with binary version | All |
| `Views/JokeDetailSheet.swift` | Update call from `GroanOMeterView` to new binary view | Line 48 |

### Rating Display (CompactGroanOMeterView consumers)
| File | What Changes | Lines |
|------|-------------|-------|
| `Views/JokeCardView.swift` | Update `CompactGroanOMeterView` usage (if renamed) | Line 72 |
| `Views/CharacterDetailView.swift` | Update `CompactGroanOMeterView` usage (if renamed) | Line 264 |
| `Views/JokeOfTheDayView.swift` | Update `CompactGroanOMeterView` usage (if renamed) | Line 106 |

### Model (Rating emoji mapping)
| File | What Changes | Lines |
|------|-------------|-------|
| `Models/Joke.swift` | Update `ratingEmoji` computed property (remove cases 2,3,4); update `ratingEmojis` static array | Lines 84-96 |

### Me Tab (5 sections to 2)
| File | What Changes | Lines |
|------|-------------|-------|
| `Views/MeView.swift` | Remove Funny/Meh/Groan-Worthy sections; keep Hilarious and Horrible | Lines 66-113 |
| `ViewModels/JokeViewModel.swift` | Remove `funnyJokes`, `mehJokes`, `groanJokes` computed properties and their filtered variants | Lines 99-176 |

### Text/Copy Updates
| File | What Changes | Lines |
|------|-------------|-------|
| `Views/MonthlyTopTen/MonthlyTopTenDetailView.swift` | Update empty state text from "5 stars"/"1 star" to binary language | Line 127 |

### Preview Updates
| File | What Changes |
|------|-------------|
| `Views/GrainOMeterView.swift` | Update previews for new binary component |
| `Views/JokeDetailSheet.swift` | Update preview `userRating` values to 1 or 5 |
| `Views/JokeCardView.swift` | Update preview `userRating` values |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Segmented control | Custom toggle/switch | SwiftUI `Picker(.segmented)` or styled HStack with buttons | Native look, accessibility built-in |
| Haptic feedback | UIImpactFeedbackGenerator directly | `HapticManager.shared.selection()` | Existing singleton with consistent API |
| Rating persistence | New storage mechanism | Existing `LocalStorageService.saveRating(for:firestoreId:rating:)` | Already works with Int values 1 and 5 |
| Cross-VM sync | New notification | Existing `.jokeRatingDidChange` notification | Already handles rating changes across views |

**Key insight:** The entire backend plumbing (storage, Firestore sync, cross-VM notifications, migration) is already binary-ready from Phase 13. This phase is a pure UI swap.

## Common Pitfalls

### Pitfall 1: Missing Rating Value Consumers
**What goes wrong:** Changing the rating UI but missing a consumer that still expects values 2, 3, or 4.
**Why it happens:** Rating values are checked in multiple files (model emoji mapping, Me tab sections, compact views, previews).
**How to avoid:** Grep for `userRating == 2`, `userRating == 3`, `userRating == 4`, `rating == 2`, `rating == 3`, `rating == 4`, `case 2:`, `case 3:`, `case 4:` in rating-related switch statements.
**Warning signs:** Stale emoji options appearing, empty sections in Me tab, incorrect emojis on cards.

### Pitfall 2: Animation on Scroll Containers
**What goes wrong:** Adding `.animation()` to the new rating component or its parent disrupts scroll position.
**Why it happens:** Per CLAUDE.md, `.animation()` modifiers on ScrollView/LazyVStack cause scroll jumps on iOS 18.
**How to avoid:** Use `withAnimation` at the mutation site (ViewModel) or on isolated view elements. Never on scroll containers.
**Warning signs:** Feed jumps when rating a joke.

### Pitfall 3: Forgetting Preview Updates
**What goes wrong:** Previews crash or show incorrect content because they use rating values (2, 3, 4) that no longer have UI mappings.
**Why it happens:** Previews hardcode `userRating: 3` or `userRating: 4`.
**How to avoid:** Update all `#Preview` blocks that create `Joke(userRating: ...)` to use nil, 1, or 5.
**Warning signs:** Preview canvas errors.

### Pitfall 4: Stale GroanOMeter Name References
**What goes wrong:** If the type is renamed, callers still reference old type name causing compile errors.
**Why it happens:** The type `GroanOMeterView` and `CompactGroanOMeterView` are used in 5+ files.
**How to avoid:** Either (a) rename in place keeping the same file, or (b) do a project-wide rename. Recommendation: edit the existing `GrainOMeterView.swift` file in place to avoid Xcode project file changes.
**Warning signs:** Build errors from missing type names.

### Pitfall 5: Forgetting the onRate Callback Signature
**What goes wrong:** Changing the callback from `(Int) -> Void` to something else cascades changes through every view.
**Why it happens:** `onRate: (Int) -> Void` is the interface between views and ViewModels, used in 6+ view files.
**How to avoid:** Keep `onRate: (Int) -> Void`. The new UI simply passes `1` or `5` instead of `1-5`.
**Warning signs:** Massive compile error cascade.

## Code Examples

### Current Rating Flow (to understand what changes)

**1. User interacts with GroanOMeterView:**
```swift
// GrainOMeterView.swift - onEnded callback
.onEnded { value in
    let finalIndex = indexFromLocation(value.location.x, itemWidth: itemWidth)
    onRate(finalIndex + 1)  // Sends 1-5
}
```

**2. View passes to ViewModel:**
```swift
// JokeDetailSheet.swift
GroanOMeterView(currentRating: joke.userRating, onRate: onRate)

// JokeFeedView.swift
onRate: { rating in viewModel.rateJoke(joke, rating: rating) }
```

**3. ViewModel processes:**
```swift
// JokeViewModel.rateJoke()
let clampedRating = min(max(rating, 1), 5)
storage.saveRating(for: joke.id, firestoreId: joke.firestoreId, rating: clampedRating)
// ... Firestore sync, notification post
```

**4. Feed cards display:**
```swift
// JokeCardView.swift
if let rating = joke.userRating {
    CompactGroanOMeterView(rating: rating)  // Shows emoji for 1-5
}
```

### New Binary Rating Flow (what it becomes)

**1. User taps Hilarious or Horrible:**
```swift
// New BinaryRatingView
Button {
    HapticManager.shared.selection()
    withAnimation(.easeInOut(duration: 0.2)) {
        onRate(option.rating)  // Sends 1 or 5 only
    }
}
```

**2. View passes to ViewModel (unchanged):**
```swift
// JokeDetailSheet.swift
BinaryRatingView(currentRating: joke.userRating, onRate: onRate)

// JokeFeedView.swift (unchanged)
onRate: { rating in viewModel.rateJoke(joke, rating: rating) }
```

**3. ViewModel processes (unchanged):**
```swift
// JokeViewModel.rateJoke() -- still works, receives 1 or 5
let clampedRating = min(max(rating, 1), 5)
```

**4. Feed cards display (simplified):**
```swift
// Updated CompactRatingView
if let rating = joke.userRating {
    switch rating {
    case 5: Text("😂")
    case 1: Text("🫠")
    default: EmptyView()
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 5-emoji drag slider (`GroanOMeterView`) | Binary segmented control | Phase 14 (this phase) | Simpler UX, matches data model from Phase 13 |
| 5 rating sections in Me tab | 2 sections (Hilarious/Horrible) | Phase 14 (this phase) | Cleaner organization |
| `ratingEmojis` array of 5 | 2 emojis only | Phase 14 (this phase) | No stale mappings |

**Deprecated/outdated after this phase:**
- `GroanOMeterView` 5-emoji slider: replaced with binary control
- `CompactGroanOMeterView` 5-emoji lookup: replaced with binary lookup
- `Joke.ratingEmojis` 5-element array: reduced to 2
- JokeViewModel computed properties: `funnyJokes`, `mehJokes`, `groanJokes` and their `filtered*` variants removed
- MeView sections: Funny, Meh, Groan-Worthy sections removed

## Open Questions

1. **Naming: Keep "GroanOMeter" or rename?**
   - What we know: The "Groan-O-Meter" name was thematic for a 5-point scale. A binary choice doesn't really "meter" anything.
   - Recommendation: Rename to `BinaryRatingView` and `CompactRatingView`. Edit the existing `GrainOMeterView.swift` file in place to avoid needing Xcode project file updates. The file name on disk won't match the type name, but that's a minor cosmetic issue. Alternatively, rename the file too but that requires updating `project.pbxproj`.

2. **Visual design: Segmented Picker vs. styled buttons?**
   - What we know: The MonthlyTopTenDetailView already uses `Picker(.segmented)` for Hilarious/Horrible toggle. That's a simple text picker. For the rating control, styled buttons with emoji + text + color feedback would be more visually engaging and satisfying.
   - Recommendation: Use styled HStack buttons (not Picker) for the rating control in JokeDetailSheet. This allows emoji + text + color + animation, matching the "feels responsive and satisfying" success criterion. The MonthlyTopTenDetailView already provides the Picker pattern for a different context (list filtering).

3. **Should un-rating (removing a rating) still be possible?**
   - What we know: Currently, tapping the already-selected option in GroanOMeterView doesn't un-rate. Un-rating is only possible via swipe-to-delete in the Me tab (`viewModel.rateJoke(joke, rating: 0)`). The success criteria don't mention un-rating from the detail sheet.
   - Recommendation: Keep current behavior -- tapping the already-selected option is a no-op. Un-rating via swipe-to-delete in Me tab still works.

## Sources

### Primary (HIGH confidence)
- **Codebase inspection** -- All file contents read directly from the repository
  - `Views/GrainOMeterView.swift` -- Current 5-emoji slider implementation
  - `Views/JokeDetailSheet.swift` -- Where GroanOMeterView is instantiated
  - `Views/JokeCardView.swift` -- CompactGroanOMeterView usage on feed cards
  - `Views/CharacterDetailView.swift` -- CompactGroanOMeterView in character feed
  - `Views/JokeOfTheDayView.swift` -- CompactGroanOMeterView on JOTD card
  - `Views/MeView.swift` -- 5-section rated jokes list
  - `Models/Joke.swift` -- `ratingEmoji` and `ratingEmojis` properties
  - `ViewModels/JokeViewModel.swift` -- Rating methods, Me tab computed properties
  - `ViewModels/CharacterDetailViewModel.swift` -- Rating methods, notification posting
  - `Services/LocalStorageService.swift` -- Rating storage and binary migration
  - `Services/FirestoreService.swift` -- Firestore rating sync
  - `Utilities/HapticManager.swift` -- Haptic feedback API
  - `Models/FirestoreModels.swift` -- RankingType enum (already has .hilarious/.horrible)
  - `Views/MonthlyTopTen/MonthlyTopTenDetailView.swift` -- Existing segmented control pattern
  - `Views/MonthlyTopTen/RankedJokeCard.swift` -- Ranked joke display
  - `Views/MonthlyTopTen/MonthlyTopTenCarouselView.swift` -- Ranking carousel
  - `ViewModels/MonthlyRankingsViewModel.swift` -- Rankings data

- **CLAUDE.md** -- Project conventions and architectural decisions
- **STATE.md** -- Phase 13 complete, ready for Phase 14
- **PROJECT.md** -- v1.1.0 requirements and constraints

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- Pure SwiftUI, no new libraries needed
- Architecture: HIGH -- Direct codebase inspection, every file read, all touchpoints mapped
- Pitfalls: HIGH -- Based on actual code patterns observed in the codebase

**Research date:** 2026-02-18
**Valid until:** Indefinite (codebase-specific research, no external dependencies)
