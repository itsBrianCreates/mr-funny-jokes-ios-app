# Phase 16: All-Time Leaderboard UI - Research

**Researched:** 2026-02-18
**Domain:** SwiftUI UI label/naming refactor, Firestore data model compatibility, Xcode project file management
**Confidence:** HIGH

## Summary

Phase 16 is a pure client-side UI relabeling and data-source rewiring phase. The Cloud Function (Phase 13) already writes all-time rankings to `weekly_rankings/all_time`. The iOS app currently reads from `weekly_rankings/{currentWeekId}` via `getCurrentWeekId()` (ISO week format like "2024-W03"). This phase changes the client to read from the fixed `all_time` document and renames all "Monthly" references to "All-Time" throughout the UI.

The scope is narrow but touches many files: 4 Swift source files contain "Monthly" in type/variable names, 1 model file needs schema adjustment (the `all_time` document omits `week_start`/`week_end` fields), 1 service file needs a new fetch method, the Xcode project file needs folder/file renaming, and the `MonthlyTopTen` directory should be renamed. There are no new dependencies, no new views, and no new behavioral logic -- this is a rename + rewire operation.

**Critical finding:** The `WeeklyRankings` Codable struct has non-optional `weekStart: Date` and `weekEnd: Date` fields, but the Cloud Function's `all_time` document does NOT include `week_start` or `week_end`. Attempting to decode the `all_time` document with the current struct will throw a decoding error. This must be addressed by either making those fields optional or creating a new model.

**Primary recommendation:** Make `weekStart` and `weekEnd` optional in the `WeeklyRankings` struct (or rename the struct entirely), change `fetchWeeklyRankings()` to read from the `"all_time"` document, rename all "Monthly" references to "All-Time", and rename the folder/files from `MonthlyTopTen` to `AllTimeTopTen`. Since the weekly document format is no longer used anywhere, making the fields optional is safe.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 18.0+ | All UI views | Already in use, native framework |
| FirebaseFirestore | Existing | Data fetching via `FirestoreService` | Already in use |

### Supporting

No new libraries needed. This phase uses only existing dependencies.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Renaming files/folder | Keep "Monthly" filenames, only change UI labels | Leaves confusing names in codebase; not worth the tech debt since we're already touching every file |
| Making weekStart/weekEnd optional | Creating a new `AllTimeRankings` struct | New struct would duplicate code; making fields optional is simpler since weekly format is deprecated |

## Architecture Patterns

### Affected File Inventory

```
Files to MODIFY (rename internals):
MrFunnyJokes/
  ViewModels/
    MonthlyRankingsViewModel.swift     -> Rename class to AllTimeRankingsViewModel
  Views/
    MonthlyTopTen/                     -> Rename folder to AllTimeTopTen
      MonthlyTopTenCarouselView.swift  -> Rename file + struct to AllTimeTopTenCarouselView
      MonthlyTopTenDetailView.swift    -> Rename file + struct to AllTimeTopTenDetailView
      RankedJokeCard.swift             -> Update comment only (no "Monthly" in struct name)
    JokeFeedView.swift                 -> Update references + variable names
  Models/
    FirestoreModels.swift              -> Make weekStart/weekEnd optional, update comments
  Services/
    FirestoreService.swift             -> Change document ID from getCurrentWeekId() to "all_time"
MrFunnyJokes.xcodeproj/
  project.pbxproj                      -> Update file/folder references
```

### Pattern 1: Data Source Rewiring

**What:** Change `fetchWeeklyRankings()` to read from `"all_time"` instead of `getCurrentWeekId()`

**Current code (FirestoreService.swift line 474):**
```swift
func fetchWeeklyRankings() async throws -> WeeklyRankings? {
    let weekId = getCurrentWeekId()
    let document = try await db.collection(weeklyRankingsCollection).document(weekId).getDocument()
    guard document.exists else { return nil }
    return try document.data(as: WeeklyRankings.self)
}
```

**Target:**
```swift
func fetchAllTimeRankings() async throws -> WeeklyRankings? {
    let document = try await db.collection(weeklyRankingsCollection).document("all_time").getDocument()
    guard document.exists else { return nil }
    return try document.data(as: WeeklyRankings.self)
}
```

**Note:** The method name changes from `fetchWeeklyRankings` to `fetchAllTimeRankings`. The collection name `weeklyRankingsCollection` stays `"weekly_rankings"` per the accepted tech-debt decision.

### Pattern 2: Model Schema Compatibility

**What:** Make `weekStart` and `weekEnd` optional in `WeeklyRankings` because the `all_time` document doesn't have these fields.

**Current:**
```swift
struct WeeklyRankings: Codable {
    let weekId: String
    let weekStart: Date       // Required -- all_time doc doesn't have this!
    let weekEnd: Date         // Required -- all_time doc doesn't have this!
    let hilarious: [RankedJokeEntry]
    ...
}
```

**Target:**
```swift
struct WeeklyRankings: Codable {
    let weekId: String
    let weekStart: Date?      // Optional -- not present in all_time document
    let weekEnd: Date?        // Optional -- not present in all_time document
    let hilarious: [RankedJokeEntry]
    ...
}
```

### Pattern 3: File Renaming via Xcode Project

**What:** Rename Swift files and folder from `MonthlyTopTen` to `AllTimeTopTen`

**Approach:** Use `git mv` for the file system changes, then update `project.pbxproj` references. The pbxproj file contains:
- File references (`PBXFileReference`) with `path = MonthlyTopTenCarouselView.swift`
- Build file entries (`PBXBuildFile`) referencing the file references
- Group entries (`PBXGroup`) with `path = MonthlyTopTen`

All references use stable UUIDs (e.g., `C35305782EEDF96100C81E13`), so renaming only changes the `path` and display name values, not the UUIDs.

### Pattern 4: UI Label Changes

**What:** Replace all user-visible "Monthly" text with "All-Time"

**Locations (exhaustive list from codebase search):**
1. `MonthlyTopTenCarouselView.swift` line 55: `Text("Monthly Top 10")` -> `Text("All-Time Top 10")`
2. `MonthlyTopTenDetailView.swift` line 88: `.navigationTitle("Monthly Top 10")` -> `.navigationTitle("All-Time Top 10")`

### Pattern 5: Remove Date Range Display

**What:** The detail view currently shows a date range subtitle (e.g., "Dec 1 - 31"). For all-time rankings, this is meaningless. Remove it entirely.

**Affected:**
- `MonthlyRankingsViewModel.swift`: Remove `monthDateRange` published property, `formatDateRange()` method
- `MonthlyTopTenDetailView.swift`: Remove `dateRange` computed property and its `Text(dateRange)` display

### Anti-Patterns to Avoid

- **Partial rename:** Renaming the class but leaving old variable names like `monthlyTopTenDestination` creates confusion. Rename everything consistently.
- **Modifying pbxproj by hand without understanding the structure:** The pbxproj has a specific format. Use `git mv` for filesystem changes and then update the `path` values in the pbxproj. Never change the UUID references.
- **Keeping `getCurrentWeekId()` in the fetch path:** The entire point is to read from a fixed `"all_time"` document. Don't compute a week ID.
- **Leaving `getCurrentWeekDateRange()` as non-dead code:** This function is only used by `fetchWeeklyRankings()`. After this phase, it becomes dead code. It can be removed or left (harmless). Note: `getCurrentWeekId()` is still used by `logRatingEvent()`, so it must NOT be removed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Xcode project file updates | Manual text editing of pbxproj | `git mv` + targeted path string replacements in pbxproj | Keeps UUIDs stable, only changes paths |
| All-time rankings model | New `AllTimeRankings` struct | Make existing `WeeklyRankings` fields optional | Avoids code duplication; no consumer of weekly format remains |

**Key insight:** This phase has zero new features. Every change is a rename, rewire, or removal. The risk is entirely in execution accuracy (missing a reference, breaking a pbxproj entry), not in design.

## Common Pitfalls

### Pitfall 1: WeeklyRankings Decoding Failure on all_time Document

**What goes wrong:** The `all_time` Firestore document does not contain `week_start` or `week_end` fields. The current `WeeklyRankings` struct has these as non-optional `Date` properties. Firestore's Codable decoding will throw an error, and `fetchAllTimeRankings()` will return nil or crash.
**Why it happens:** Phase 13 research explicitly noted "No `week_start` or `week_end` fields needed for all-time document" and the Cloud Function's `saveAllTimeRankings()` omits them.
**How to avoid:** Make `weekStart` and `weekEnd` optional (`Date?`) in the `WeeklyRankings` struct. No other consumer reads these fields from the struct.
**Warning signs:** Rankings screen showing "No data" despite the `all_time` document existing in Firestore. Error log: "Failed to load rankings: keyNotFound(weekStart)".

### Pitfall 2: Xcode Project File Corruption

**What goes wrong:** Incorrectly editing `project.pbxproj` breaks Xcode's ability to open the project.
**Why it happens:** The pbxproj file has strict formatting requirements. Adding/removing lines or changing UUIDs breaks references.
**How to avoid:** Only change `path` string values and display names. Keep all UUIDs identical. After editing, verify with `xcodebuild -list` or open in Xcode.
**Warning signs:** Xcode showing "The project file cannot be parsed" or files appearing as red in the navigator.

### Pitfall 3: Incomplete Rename Leaving "Monthly" References

**What goes wrong:** User sees "Monthly Top 10" in one place and "All-Time Top 10" in another, creating an inconsistent experience.
**Why it happens:** Missing a comment, variable name, or UI string during the rename sweep.
**How to avoid:** Use the exhaustive list from the codebase search (46 occurrences of "Monthly/monthly" across 4 Swift source files). Grep after completion to verify zero remaining "Monthly" references in Swift files.
**Warning signs:** Any occurrence of "Monthly" or "monthly" in `.swift` files under `MrFunnyJokes/MrFunnyJokes/`.

### Pitfall 4: Breaking logRatingEvent by Removing getCurrentWeekId

**What goes wrong:** `logRatingEvent()` in `FirestoreService.swift` still uses `getCurrentWeekId()` to construct the rating event document ID (`{deviceId}_{jokeId}_{weekId}`). Removing or renaming this function breaks rating event logging.
**Why it happens:** Overzealous cleanup -- assuming `getCurrentWeekId()` is dead code when it has a second consumer.
**How to avoid:** Only change `fetchWeeklyRankings()`. Leave `getCurrentWeekId()` and `logRatingEvent()` untouched. The `week_id` field in rating events is still useful for the Cloud Function's data (even though it aggregates all-time, the field exists on documents).
**Warning signs:** Runtime crash or silent failure when user rates a joke.

### Pitfall 5: EmptyStateView Dependency from MeView

**What goes wrong:** `EmptyStateView` is defined in `MonthlyTopTenDetailView.swift`. If the file is renamed but the struct's access changes, `MeView.swift` (which imports and uses `EmptyStateView`) will break.
**Why it happens:** File renaming is assumed to be contained to the MonthlyTopTen folder, but `EmptyStateView` is used externally.
**How to avoid:** `EmptyStateView` struct name does NOT contain "Monthly" -- it keeps its name. Just ensure the renamed file still exports it. Verify MeView compiles after the rename.
**Warning signs:** Build error in MeView.swift: "Cannot find 'EmptyStateView' in scope".

## Code Examples

Verified patterns from the existing codebase:

### Data Source Change (FirestoreService.swift)

```swift
// CURRENT (line 474):
func fetchWeeklyRankings() async throws -> WeeklyRankings? {
    let weekId = getCurrentWeekId()
    let document = try await db.collection(weeklyRankingsCollection).document(weekId).getDocument()
    guard document.exists else { return nil }
    return try document.data(as: WeeklyRankings.self)
}

// TARGET:
func fetchAllTimeRankings() async throws -> WeeklyRankings? {
    let document = try await db.collection(weeklyRankingsCollection).document("all_time").getDocument()
    guard document.exists else { return nil }
    return try document.data(as: WeeklyRankings.self)
}
```

### Model Fix (FirestoreModels.swift)

```swift
// CURRENT (line 164):
struct WeeklyRankings: Codable {
    let weekId: String
    let weekStart: Date      // Non-optional -- BREAKS on all_time doc
    let weekEnd: Date        // Non-optional -- BREAKS on all_time doc
    ...
}

// TARGET:
struct WeeklyRankings: Codable {
    let weekId: String
    let weekStart: Date?     // Optional -- all_time doc omits this
    let weekEnd: Date?       // Optional -- all_time doc omits this
    ...
}
```

### ViewModel Rename + Cleanup (MonthlyRankingsViewModel.swift -> AllTimeRankingsViewModel.swift)

```swift
// CURRENT:
@MainActor
final class MonthlyRankingsViewModel: ObservableObject {
    @Published var monthDateRange: String = ""
    ...
    monthDateRange = formatDateRange(start: rankings.weekStart, end: rankings.weekEnd)
    ...
    private func formatDateRange(start: Date, end: Date) -> String { ... }
}

// TARGET:
@MainActor
final class AllTimeRankingsViewModel: ObservableObject {
    // monthDateRange REMOVED -- no date range for all-time
    // formatDateRange() REMOVED -- no date range for all-time
    ...
    // Remove the line that sets monthDateRange
}
```

### Feed View Variable Rename (JokeFeedView.swift)

```swift
// CURRENT:
@StateObject private var rankingsViewModel = MonthlyRankingsViewModel()
@State private var monthlyTopTenDestination: RankingType?
private var showMonthlyTopTen: Bool { ... }

// TARGET:
@StateObject private var rankingsViewModel = AllTimeRankingsViewModel()
@State private var allTimeTopTenDestination: RankingType?
private var showAllTimeTopTen: Bool { ... }
```

### Detail View Label Change (MonthlyTopTenDetailView.swift -> AllTimeTopTenDetailView.swift)

```swift
// CURRENT (line 88):
.navigationTitle("Monthly Top 10")
// And date range subtitle display

// TARGET:
.navigationTitle("All-Time Top 10")
// Date range subtitle REMOVED entirely
```

### Carousel Header Change (MonthlyTopTenCarouselView.swift -> AllTimeTopTenCarouselView.swift)

```swift
// CURRENT (line 55):
Text("Monthly Top 10")

// TARGET:
Text("All-Time Top 10")
```

## Codebase Inventory: Complete Change List

### Files to RENAME (filesystem + pbxproj)

| Current Path | New Path |
|-------------|----------|
| `Views/MonthlyTopTen/` | `Views/AllTimeTopTen/` |
| `Views/MonthlyTopTen/MonthlyTopTenCarouselView.swift` | `Views/AllTimeTopTen/AllTimeTopTenCarouselView.swift` |
| `Views/MonthlyTopTen/MonthlyTopTenDetailView.swift` | `Views/AllTimeTopTen/AllTimeTopTenDetailView.swift` |
| `ViewModels/MonthlyRankingsViewModel.swift` | `ViewModels/AllTimeRankingsViewModel.swift` |

### Files to MODIFY (content changes)

| File | What Changes |
|------|-------------|
| `Models/FirestoreModels.swift` | Make `weekStart`/`weekEnd` optional; update comments from "weekly" to "all-time" |
| `Services/FirestoreService.swift` | Rename `fetchWeeklyRankings()` to `fetchAllTimeRankings()`, hardcode `"all_time"` document ID; remove/keep `getCurrentWeekDateRange()` as dead code cleanup |
| `Views/AllTimeTopTen/AllTimeTopTenCarouselView.swift` | Rename all struct names from Monthly* to AllTime*; change "Monthly Top 10" text to "All-Time Top 10" |
| `Views/AllTimeTopTen/AllTimeTopTenDetailView.swift` | Rename struct; change nav title; remove date range display and fallback logic |
| `Views/AllTimeTopTen/RankedJokeCard.swift` | Update comment from "Monthly" to "All-Time" |
| `Views/JokeFeedView.swift` | Update variable names and type references from Monthly to AllTime |
| `ViewModels/AllTimeRankingsViewModel.swift` | Rename class; remove `monthDateRange`, `formatDateRange()`; rename `fetchWeeklyRankings()` call |
| `MrFunnyJokes.xcodeproj/project.pbxproj` | Update path references for renamed files/folder |

### Files that do NOT change

| File | Why Not |
|------|---------|
| `Views/MeView.swift` | Uses `RankingType` and `EmptyStateView` -- neither has "Monthly" in the name |
| `Models/Joke.swift` | No ranking/leaderboard references |
| `functions/index.js` | Already writes to `all_time` (Phase 13) |
| `FirestoreService.swift: logRatingEvent()` | Still uses `getCurrentWeekId()` for event document IDs -- correct behavior |
| `FirestoreService.swift: getCurrentWeekId()` | Still needed by `logRatingEvent()` |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Weekly rankings (`weekly_rankings/{weekId}`) | All-time rankings (`weekly_rankings/all_time`) | Phase 13 (backend) | Client must switch document ID |
| Date range display in detail view | No date range for all-time | Phase 16 (this phase) | Remove date formatting code |
| `getCurrentWeekId()` for rankings fetch | Hardcoded `"all_time"` document ID | Phase 16 (this phase) | Simpler fetch, no date calculation |

**Deprecated/outdated after this phase:**
- `getCurrentWeekDateRange()` in `FirestoreService.swift` -- only consumer was `fetchWeeklyRankings()`. Can be removed as dead code.
- `formatDateRange()` in `MonthlyRankingsViewModel.swift` -- only used for monthly date display. Will be removed.
- `monthDateRange` published property -- removed entirely.

## Open Questions

1. **Should `WeeklyRankings` struct be renamed to `AllTimeRankings`?**
   - What we know: The struct name `WeeklyRankings` is technically inaccurate for all-time data. The Firestore collection is also called `weekly_rankings` (accepted tech debt from Phase 13 decision).
   - What's unclear: Whether to rename the struct for code clarity or keep it to match the Firestore collection name.
   - Recommendation: Keep the struct name as `WeeklyRankings` for consistency with the Firestore collection name. The "cosmetic tech debt" was already accepted. Renaming the struct creates churn in the model layer with no user-facing benefit. Update only the doc comments.

2. **Should `getCurrentWeekDateRange()` be removed?**
   - What we know: After this phase, it has no callers. `getCurrentWeekId()` is still used by `logRatingEvent()`.
   - What's unclear: Whether removing dead code is worth the diff noise.
   - Recommendation: Remove it. It's a small method (13 lines) and leaving dead code in a service that's being cleaned up sends mixed signals. Keep `getCurrentWeekId()` since it has a live consumer.

3. **File renaming approach: git mv vs new files?**
   - What we know: Renaming via `git mv` preserves git history. Creating new files and deleting old ones loses history but is simpler in pbxproj.
   - What's unclear: Whether `git mv` + pbxproj edits is more risky than recreating files.
   - Recommendation: Use `git mv` for filesystem changes, then update pbxproj path strings. This preserves history and keeps UUID references stable.

## Sources

### Primary (HIGH confidence)
- **Codebase analysis** -- All findings verified by reading source files directly:
  - `MrFunnyJokes/ViewModels/MonthlyRankingsViewModel.swift` -- Current ViewModel with Monthly naming and date range logic
  - `MrFunnyJokes/Views/MonthlyTopTen/MonthlyTopTenCarouselView.swift` -- Carousel with "Monthly Top 10" header text
  - `MrFunnyJokes/Views/MonthlyTopTen/MonthlyTopTenDetailView.swift` -- Detail view with "Monthly Top 10" nav title and date range
  - `MrFunnyJokes/Views/MonthlyTopTen/RankedJokeCard.swift` -- Card component (only comment references "Monthly")
  - `MrFunnyJokes/Views/JokeFeedView.swift` -- Feed embedding the carousel with Monthly variable names
  - `MrFunnyJokes/Views/MeView.swift` -- Confirmed no "Monthly" references; uses EmptyStateView and RankingType
  - `MrFunnyJokes/Models/FirestoreModels.swift` -- WeeklyRankings struct with non-optional weekStart/weekEnd
  - `MrFunnyJokes/Services/FirestoreService.swift` -- fetchWeeklyRankings() reading getCurrentWeekId()
  - `functions/index.js` -- Confirmed all_time document schema (no week_start/week_end fields)
  - `MrFunnyJokes.xcodeproj/project.pbxproj` -- Verified all file/folder references with UUIDs
  - `.planning/phases/13-data-migration-cloud-function/13-RESEARCH.md` -- Phase 13 decisions and schema
  - `.planning/phases/13-data-migration-cloud-function/13-VERIFICATION.md` -- Confirmed Cloud Function deployed

### Secondary (MEDIUM confidence)
- Phase 13 research documents -- Schema decisions for all_time document (week_start/week_end omission confirmed)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- No new libraries, pure rename + rewire of existing code
- Architecture: HIGH -- All patterns directly observed in existing codebase; schema mismatch verified against both Cloud Function output and Codable struct
- Pitfalls: HIGH -- Decoding failure confirmed by comparing Cloud Function document structure vs Swift model; pbxproj structure verified
- Code examples: HIGH -- All examples are line-referenced from current codebase files

**Research date:** 2026-02-18
**Valid until:** 2026-03-18 (stable -- no external dependency changes; pure internal refactor)
