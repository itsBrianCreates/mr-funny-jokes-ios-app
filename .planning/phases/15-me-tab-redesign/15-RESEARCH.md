# Phase 15: Me Tab Redesign - Research

**Researched:** 2026-02-18
**Domain:** SwiftUI view redesign (segmented control pattern reuse)
**Confidence:** HIGH

## Summary

Phase 15 transforms the Me tab from a sectioned List layout (two collapsible sections with headers) into a segmented-control-driven layout that matches the MonthlyTopTenDetailView pattern already established in the codebase. The change is straightforward because: (1) the target pattern already exists and works, (2) the data layer (ViewModel computed properties) is already in place from Phase 14, and (3) the scope is limited to a single view file plus minor ViewModel cleanup.

The current MeView uses a `List` with `.insetGrouped` style, showing "Hilarious" and "Horrible" as collapsible `Section` blocks. The target pattern (MonthlyTopTenDetailView) uses a `ScrollView > LazyVStack` with a native `Picker(.segmented)` at the top, switching between content based on `@State selectedType`. The redesign replaces the List-based layout with this ScrollView-based pattern.

**Primary recommendation:** Rewrite MeView.swift to use the MonthlyTopTenDetailView pattern: `Picker(.segmented)` at top with count badges in segment labels, `ScrollView > LazyVStack` body, `JokeRowView` items rendered as cards (not List rows). Clean up dead `selectedMeCategory` filter infrastructure.

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SwiftUI `Picker(.segmented)` | iOS 18.0+ | Hilarious/Horrible toggle | Native component, already used in MonthlyTopTenDetailView |
| `RankingType` enum | Existing | Type-safe segment identity | Already defines `.hilarious`/`.horrible` with emoji, rawValue, Identifiable |
| `@State selectedType: RankingType` | SwiftUI | Track active segment | Same pattern as MonthlyTopTenDetailView |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| `JokeRowView` | Existing | Joke row rendering | Already used in current MeView, keep as-is |
| `JokeDetailSheet` | Existing | Joke detail presentation | Already wired up in current MeView |
| `CharacterIndicatorView` | Existing | Character avatar in rows | Used by JokeRowView |
| `HapticManager` | Existing | Haptic feedback on interactions | Per CLAUDE.md conventions |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Native `Picker(.segmented)` | Custom pill tabs | Unnecessary complexity; native matches MonthlyTopTenDetailView exactly |
| `ScrollView > LazyVStack` | Keep `List(.insetGrouped)` | List doesn't match MonthlyTopTenDetailView pattern; segmented control above a List looks inconsistent |
| Reuse `RankingType` enum | Create new `MeSegmentType` enum | RankingType already has everything needed; avoid duplication |

## Architecture Patterns

### Target Pattern: MonthlyTopTenDetailView (the pattern to match)

The view to match is `MonthlyTopTenDetailView.swift`. Its structure:

```swift
struct MonthlyTopTenDetailView: View {
    @State var selectedType: RankingType    // Segment selection state

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Segmented control
                Picker("Category", selection: $selectedType) {
                    ForEach(RankingType.allCases) { type in
                        Text("\(type.emoji) \(type.rawValue)").tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)
                .padding(.bottom, 8)

                // Content based on selection
                if hasData {
                    ForEach(jokes) { joke in ... }
                } else {
                    EmptyStateView(type: selectedType)
                }
            }
            .padding(.horizontal)
        }
    }
}
```

### MeView Adaptation

The Me tab adaptation follows the same skeleton but with these differences:

1. **Count badge in segment label:** `Text("\(type.emoji) \(type.rawValue) (\(count))")` -- per ME-02 requirement
2. **Local data source:** Uses `viewModel.hilariousJokes` / `viewModel.horribleJokes` (already computed) instead of fetching from a ViewModel like MonthlyRankingsViewModel
3. **No loading state needed:** Data is local (already loaded by JokeViewModel from main feed)
4. **Swipe-to-delete:** Requires using a `List` OR implementing custom swipe actions. Since the target pattern uses `ScrollView > LazyVStack`, swipe-to-delete (un-rate) must be handled differently. Options:
   - Wrap joke rows in a `List` inside the `ScrollView` (bad -- nested scrolling)
   - Use `.swipeActions` on `Button` inside `LazyVStack` (only works on `List` rows)
   - Move un-rate to the detail sheet (tap row > sheet > change/remove rating)
   - Use `.contextMenu` on rows for quick un-rate

### Current MeView Structure (what changes)

```
MeView
  if ratedJokes.isEmpty → emptyState
  else if filteredRatedJokes.isEmpty → filteredEmptyState
  else → ratedJokesList
    List(.insetGrouped)
      Section("Hilarious") with header showing emoji + count
        ForEach(filteredHilariousJokes) → JokeRowView with swipeActions
      Section("Horrible") with header showing emoji + count
        ForEach(filteredHorribleJokes) → JokeRowView with swipeActions
    .sheet → JokeDetailSheet
```

### Target MeView Structure (after redesign)

```
MeView
  if ratedJokes.isEmpty → emptyState (same as today)
  else → segmentedContent
    ScrollView
      LazyVStack(spacing: 12)
        Picker(.segmented) with count badges
        if selectedSegment has jokes → ForEach → JokeRowView-style cards
        else → empty state for that segment
    .sheet → JokeDetailSheet (same as today)
```

### Key Structural Decisions

| Decision | Recommendation | Rationale |
|----------|---------------|-----------|
| List vs ScrollView | ScrollView > LazyVStack | Matches MonthlyTopTenDetailView pattern per ME-03 |
| Swipe-to-delete | Move to detail sheet | `.swipeActions` only works on `List` rows; detail sheet already has rating controls via `BinaryRatingView` |
| Joke row style | Card-style (`.regularMaterial` background) | Matches RankedJokeCard visual style; current JokeRowView needs wrapping |
| Category filter | Remove entirely | `selectedMeCategory` is dead code -- never called from any view. No filter menu exists in Me tab toolbar. |

### Anti-Patterns to Avoid
- **Nested scrolling:** Do NOT put a `List` inside a `ScrollView`. Use `LazyVStack` directly.
- **Implicit `.animation()` on scroll containers:** Per CLAUDE.md, use `withAnimation` at mutation site, not `.animation()` modifier on ScrollView/LazyVStack.
- **Value copy pitfall:** Per CLAUDE.md, store joke IDs in `@State`, look up fresh data from ViewModel.
- **ForEach identity:** Per CLAUDE.md, use `ForEach(jokes)` with Identifiable conformance, never `Array(collection.enumerated())`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Segmented control | Custom pill tabs | `Picker(.segmented)` | Native, accessible, matches MonthlyTopTenDetailView exactly |
| Segment with count badge | Custom labeled button bar | `Text("\(emoji) \(name) (\(count))")` in Picker segment | Keep it simple; native Picker handles all state/animation |
| Rating removal | Custom swipe gesture on ScrollView items | BinaryRatingView in detail sheet (rate 0 to un-rate) | `.swipeActions` only works in `List`; detail sheet already handles rating changes |

**Key insight:** The entire target pattern already exists in MonthlyTopTenDetailView. This is a copy-adapt task, not a design-from-scratch task.

## Common Pitfalls

### Pitfall 1: Losing swipe-to-delete when switching from List to ScrollView
**What goes wrong:** Current MeView uses `.swipeActions` on List rows to un-rate jokes. Moving to `ScrollView > LazyVStack` breaks this because `.swipeActions` only works on `List` items.
**Why it happens:** `List` and `ScrollView` have different feature sets; swipe actions are a List-specific API.
**How to avoid:** Accept the trade-off. The JokeDetailSheet already provides BinaryRatingView which allows changing/removing ratings. Users can tap a row, then tap the already-selected rating to toggle it off (or the app can expose an explicit "Remove rating" in the sheet). This is actually simpler UX.
**Warning signs:** Attempting to use `.swipeActions` on non-List views will silently do nothing.

### Pitfall 2: Count badges becoming stale
**What goes wrong:** If count badges are computed from `@State` or cached data, they might not update when ratings change.
**Why it happens:** Value copy pitfall per CLAUDE.md -- `@State` arrays hold copies.
**How to avoid:** Compute counts directly from `viewModel.hilariousJokes.count` and `viewModel.horribleJokes.count` in the Picker label. These are `@Published`-backed computed properties that recalculate on any change.
**Warning signs:** Count shows stale number after rating/un-rating a joke.

### Pitfall 3: Empty state not updating when switching segments
**What goes wrong:** Empty state view shows text for wrong segment after switching.
**Why it happens:** Empty state references stale `selectedType` or uses wrong data source.
**How to avoid:** Compute displayed jokes based on `selectedType` in a single switch/conditional, and derive empty state from the same source.

### Pitfall 4: selectedMeCategory ghost references
**What goes wrong:** After removing the category filter infrastructure, build errors from leftover references.
**Why it happens:** MeView.swift references `viewModel.selectedMeCategory` in the filtered empty state views (lines 52, 56, 59).
**How to avoid:** The filtered empty state can be simplified or removed entirely since the new design uses per-segment empty states (like MonthlyTopTenDetailView's `EmptyStateView(type:)`).

## Code Examples

### Segmented Control with Count Badges (adapted from MonthlyTopTenDetailView)

```swift
// Source: MonthlyTopTenDetailView.swift (lines 54-61) -- adapted for Me tab
@State private var selectedType: RankingType = .hilarious

// In body:
Picker("Category", selection: $selectedType) {
    ForEach(RankingType.allCases) { type in
        Text("\(type.emoji) \(type.rawValue) (\(jokesCount(for: type)))").tag(type)
    }
}
.pickerStyle(.segmented)
.padding(.top, 4)
.padding(.bottom, 8)

// Helper:
private func jokesCount(for type: RankingType) -> Int {
    switch type {
    case .hilarious: return viewModel.hilariousJokes.count
    case .horrible: return viewModel.horribleJokes.count
    }
}
```

### Jokes for Selected Segment

```swift
private var currentJokes: [Joke] {
    switch selectedType {
    case .hilarious: return viewModel.hilariousJokes
    case .horrible: return viewModel.horribleJokes
    }
}
```

### Card-Style Joke Row (matching RankedJokeCard visual pattern)

```swift
// Source: RankedJokeCard.swift (lines 60-101) -- simplified for Me tab (no rank badge)
Button {
    HapticManager.shared.mediumImpact()
    selectedJokeId = joke.id
} label: {
    VStack(alignment: .leading, spacing: 10) {
        Text(joke.setup)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 8) {
            if let character = jokeCharacter {
                CharacterIndicatorView(character: character)
            }

            HStack(spacing: 4) {
                Image(systemName: joke.category.icon)
                Text(joke.category.rawValue)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
}
.buttonStyle(.plain)
```

### Existing ViewModel Properties (no changes needed)

```swift
// Source: JokeViewModel.swift (lines 94-140) -- all already in place
var ratedJokes: [Joke]          // All rated jokes (for empty check)
var hilariousJokes: [Joke]      // userRating == 5, sorted by timestamp
var horribleJokes: [Joke]       // userRating == 1, sorted by timestamp

// These filtered variants can be removed (selectedMeCategory is dead code):
var filteredRatedJokes: [Joke]
var filteredHilariousJokes: [Joke]
var filteredHorribleJokes: [Joke]
```

## Existing Assets to Reuse

| Asset | Location | How to Use |
|-------|----------|------------|
| `RankingType` enum | `Models/FirestoreModels.swift:196` | Use as Picker selection type -- has `.hilarious`, `.horrible`, emoji, rawValue, Identifiable |
| `JokeRowView` | `Views/MeView.swift:149` | Existing row component; may refactor to card-style or create new `MeJokeCard` |
| `JokeDetailSheet` | `Views/JokeDetailSheet.swift` | Already wired; keep same sheet presentation pattern |
| `BinaryRatingView` | `Views/GrainOMeterView.swift` | Available in detail sheet for rating changes |
| `EmptyStateView` | `Views/MonthlyTopTen/MonthlyTopTenDetailView.swift:111` | Reusable per-segment empty state; already uses `RankingType` |
| `HapticManager` | `Utilities/HapticManager.swift` | Required for all interactions per CLAUDE.md |

## Dead Code to Clean Up

| Item | Location | Why Dead | Action |
|------|----------|----------|--------|
| `selectedMeCategory: JokeCategory?` | `JokeViewModel.swift:9` | Never set from any view; no filter menu exists in Me tab | Remove |
| `filteredRatedJokes` | `JokeViewModel.swift:119` | Only used for Me tab empty state which will be rewritten | Remove |
| `filteredHilariousJokes` | `JokeViewModel.swift:127` | Wraps `hilariousJokes` with dead category filter | Remove (use `hilariousJokes` directly) |
| `filteredHorribleJokes` | `JokeViewModel.swift:135` | Wraps `horribleJokes` with dead category filter | Remove (use `horribleJokes` directly) |
| `selectMeCategory(_:)` | `JokeViewModel.swift:987` | Never called from any view | Remove |
| `filteredEmptyState` | `MeView.swift:48` | References dead `selectedMeCategory`; new design handles per-segment empty states | Remove |

## Files Modified

| File | Changes | Scope |
|------|---------|-------|
| `MrFunnyJokes/MrFunnyJokes/Views/MeView.swift` | Rewrite `ratedJokesList` to segmented control pattern; update empty states; keep `JokeRowView` | Major rewrite |
| `MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` | Remove `selectedMeCategory`, `filteredRatedJokes`, `filteredHilariousJokes`, `filteredHorribleJokes`, `selectMeCategory()` | Dead code cleanup |

No new files need to be created. No Xcode project file changes needed (no files added/removed/renamed).

## Open Questions

1. **Swipe-to-delete trade-off: acceptable?**
   - What we know: Current Me tab has swipe-to-delete (un-rate) on joke rows via `.swipeActions`. Switching to ScrollView loses this. The detail sheet (JokeDetailSheet) already provides full rating controls via BinaryRatingView.
   - What's unclear: Whether the user considers swipe-to-delete essential.
   - Recommendation: Accept the trade-off. Users can still un-rate via the detail sheet. This is the same UX as MonthlyTopTenDetailView (which has no swipe actions). Alternatively, a `.contextMenu` could provide a quick "Remove Rating" option without requiring a sheet.

2. **JokeRowView vs new card component?**
   - What we know: Current `JokeRowView` is designed for `List` rows (no background/border). MonthlyTopTenDetailView uses `RankedJokeCard` which has `.regularMaterial` background and shadow.
   - What's unclear: Whether to adapt `JokeRowView` for card-style rendering or create a new component.
   - Recommendation: Inline the card layout in MeView (wrap existing JokeRowView content in card-style container) or refactor JokeRowView to accept a card-style mode. Avoid creating a whole new component for this simple change.

## Sources

### Primary (HIGH confidence)
- `MrFunnyJokes/MrFunnyJokes/Views/MonthlyTopTen/MonthlyTopTenDetailView.swift` -- Target pattern (segmented Picker, ScrollView/LazyVStack layout)
- `MrFunnyJokes/MrFunnyJokes/Views/MeView.swift` -- Current implementation being replaced
- `MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` -- Data layer (computed properties for rated jokes)
- `MrFunnyJokes/MrFunnyJokes/Models/FirestoreModels.swift:196` -- `RankingType` enum definition
- `MrFunnyJokes/MrFunnyJokes/Views/GrainOMeterView.swift` -- `BinaryRatingView` (already named BinaryRatingView, file kept as GrainOMeterView per Phase 14 decision)
- `.planning/ROADMAP.md:94-102` -- Phase 15 success criteria
- `.planning/REQUIREMENTS.md:27-29` -- ME-01, ME-02, ME-03 requirements

### Secondary (MEDIUM confidence)
- SwiftUI `Picker(.segmented)` behavior on iOS 18 -- based on working code in MonthlyTopTenDetailView (proven in this codebase)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- All components already exist in codebase; no new libraries
- Architecture: HIGH -- Target pattern (MonthlyTopTenDetailView) is proven and working
- Pitfalls: HIGH -- Identified from codebase analysis and CLAUDE.md documented patterns

**Research date:** 2026-02-18
**Valid until:** 2026-03-18 (stable -- no external dependencies, internal refactor only)
