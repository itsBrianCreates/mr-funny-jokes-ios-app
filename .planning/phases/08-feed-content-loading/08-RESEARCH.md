# Phase 8: Feed Content Loading - Research

**Researched:** 2026-01-30
**Domain:** iOS SwiftUI infinite scroll, background data loading, feed filtering
**Confidence:** HIGH

## Summary

This phase implements automatic infinite scroll pagination, removes the manual "Load More" button, loads the full joke catalog silently in the background, and filters the feed to show only unrated jokes (sorted by popularity). The existing codebase already has strong foundations for this work: `CharacterDetailView` already implements infinite scroll with `.onAppear` threshold detection, skeleton loading states are already built (`SkeletonCardView`, `ShimmerModifier`), and the `JokeViewModel` has the required infrastructure for pagination and rating tracking.

Key implementation approach:
1. Replace the "Load More" button with automatic scroll-triggered loading using the existing `loadMoreIfNeeded` pattern from `CharacterDetailView`
2. Add a background catalog loader that runs silently after the user's first scroll
3. Filter `filteredJokes` to exclude rated jokes entirely (they're already accessible in the Me tab)
4. Order remaining unrated jokes by `popularityScore` (descending)

**Primary recommendation:** Adapt the existing `CharacterDetailViewModel.loadMoreIfNeeded` pattern to `JokeFeedView`, add a background catalog loading task that triggers on first scroll, and modify `filteredJokes` to exclude jokes with `userRating != nil`.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI (native) | iOS 17+ | UI framework | Project target, native infinite scroll with LazyVStack |
| Firebase Firestore iOS SDK | Already in project | Data source | Existing pagination with cursor-based queries |
| Combine | Native | Reactive state | Already used for network monitoring |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI `.refreshable` | iOS 15+ | Pull-to-refresh | Already available, needs implementation |
| `@MainActor` | Swift 5.5+ | Thread safety | All ViewModel operations |
| Swift Concurrency (Task) | Swift 5.5+ | Background work | Background catalog loading |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| LazyVStack with .onAppear | iOS 17 scrollPosition API | More complex, not needed for this use case |
| Manual threshold detection | scrollTargetBehavior (iOS 17) | Would require iOS 17 minimum, but already targeting iOS 17 |

**Installation:**
No new dependencies required - all tools already present in project.

## Architecture Patterns

### Recommended Changes to Existing Structure

The existing structure is already well-organized. Changes are isolated to:
```
MrFunnyJokes/
├── ViewModels/
│   └── JokeViewModel.swift     # Modify: add background loading, update filtering
├── Views/
│   └── JokeFeedView.swift      # Modify: remove Load More button, add onAppear trigger
└── Services/
    └── FirestoreService.swift  # No changes needed - pagination already works
```

### Pattern 1: Threshold-Based Infinite Scroll (Already in Codebase)

**What:** Trigger loading when user scrolls near the bottom
**When to use:** Feed pagination
**Example:**
```swift
// Source: CharacterDetailViewModel.swift (existing in codebase)
func loadMoreIfNeeded(currentItem: Joke) {
    let thresholdIndex = filteredJokes.index(
        filteredJokes.endIndex,
        offsetBy: -3,  // Trigger 3 items from end
        limitedBy: filteredJokes.startIndex
    ) ?? filteredJokes.startIndex

    guard let currentIndex = filteredJokes.firstIndex(where: { $0.id == currentItem.id }),
          currentIndex >= thresholdIndex else {
        return
    }

    loadMore()
}
```

### Pattern 2: Background Catalog Loading

**What:** Load full joke catalog silently after user engagement
**When to use:** When complete dataset enables better UX (sorting, filtering)
**Example:**
```swift
// Trigger background load on first scroll (not app launch per CONTEXT.md)
@Published private(set) var isBackgroundLoadingComplete = false
private var backgroundLoadTask: Task<Void, Never>?
private var hasTriggeredBackgroundLoad = false

func triggerBackgroundLoadIfNeeded() {
    guard !hasTriggeredBackgroundLoad && !isBackgroundLoadingComplete else { return }
    hasTriggeredBackgroundLoad = true

    backgroundLoadTask = Task { [weak self] in
        await self?.loadFullCatalogInBackground()
    }
}

private func loadFullCatalogInBackground() async {
    // Load in batches to avoid memory spikes
    // Design for 500-2000 jokes per CONTEXT.md
    while hasMoreJokes && !Task.isCancelled {
        do {
            let batch = try await firestoreService.fetchMoreJokes(limit: batchSize)
            if batch.isEmpty { break }
            // Merge with existing jokes, avoiding duplicates
            // No UI indicator per CONTEXT.md (completely silent)
        } catch {
            break  // Silent failure per CONTEXT.md
        }
    }
    isBackgroundLoadingComplete = true
}
```

### Pattern 3: Unrated-Only Feed Filtering

**What:** Show only unrated jokes, sorted by popularity
**When to use:** Feed display after background load completes
**Example:**
```swift
// Modified filteredJokes computed property
var filteredJokes: [Joke] {
    // Apply category filter if selected
    let categoryFiltered: [Joke]
    if let category = selectedCategory {
        categoryFiltered = jokes.filter { $0.category == category }
    } else {
        categoryFiltered = jokes
    }

    // Filter to unrated only (rated jokes stay visible for current session)
    // Per CONTEXT.md: "stays visible for current session, removed on next refresh"
    let unratedJokes = categoryFiltered.filter { $0.userRating == nil }

    // Sort by popularity score (descending) per CONTEXT.md
    return unratedJokes.sorted { $0.popularityScore > $1.popularityScore }
}
```

### Anti-Patterns to Avoid
- **Loading on app launch:** CONTEXT.md specifies trigger on scroll, not launch
- **UI progress indicators for background load:** Must be "completely silent"
- **Blocking main thread:** Use Swift Concurrency for all network operations
- **Fetching entire catalog at once:** Batch loading prevents memory spikes

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scroll threshold detection | Custom GeometryReader solution | `.onAppear` on last few items (already in CharacterDetailView) | Simpler, proven pattern |
| Pull-to-refresh | Custom drag gesture | SwiftUI `.refreshable` modifier | Native, handles indicator automatically |
| Skeleton loading | Custom placeholder shapes | Existing `SkeletonCardView` + `ShimmerModifier` | Already built and styled |
| Firestore pagination | Custom offset tracking | Existing `FirestoreService` cursor-based pagination | Already works correctly |
| Rating storage/lookup | New storage mechanism | Existing `LocalStorageService.getRatedJokeIdsFast()` | Memory-cached, fast |

**Key insight:** The codebase already has 80% of the required infrastructure. This phase is primarily about wiring existing components together differently and adding the background loading orchestration.

## Common Pitfalls

### Pitfall 1: onAppear Called Multiple Times
**What goes wrong:** `.onAppear` can fire multiple times as cells are recycled in LazyVStack
**Why it happens:** SwiftUI's view lifecycle differs from UIKit cell reuse
**How to avoid:** Use guard statements (`guard !isLoadingMore && hasMoreJokes`) - already in codebase
**Warning signs:** Multiple concurrent network requests, duplicate jokes in feed

### Pitfall 2: Memory Pressure with Large Catalogs
**What goes wrong:** Loading 2000 jokes into memory at once causes spikes
**Why it happens:** All jokes held in single array
**How to avoid:**
- Batch loading with delays between batches
- LazyVStack naturally handles view recycling
- Consider pagination in memory if >1000 jokes
**Warning signs:** Memory warnings in Instruments, app termination

### Pitfall 3: Race Conditions Between Loads
**What goes wrong:** Background load and scroll-triggered load conflict
**Why it happens:** Both modify the same `jokes` array
**How to avoid:**
- Use single source of truth (`jokes` array)
- Deduplicate on insert (already done: check by firestoreId or setup+punchline)
- Consider using AsyncSequence or Actor for state isolation
**Warning signs:** Duplicate jokes appearing, out-of-order content

### Pitfall 4: Pull-to-Refresh During Background Load
**What goes wrong:** Refresh resets state while background load is running
**Why it happens:** Background task continues after refresh clears data
**How to avoid:** Cancel `backgroundLoadTask` in refresh(), reset `hasTriggeredBackgroundLoad`
**Warning signs:** Stale data appearing after refresh

### Pitfall 5: Rated Jokes Disappearing Mid-Session
**What goes wrong:** User rates joke, it immediately vanishes from feed
**Why it happens:** Filter removes rated jokes
**How to avoid:** Per CONTEXT.md: "stays visible for current session, removed on next refresh"
- Track session-rated joke IDs
- Filter excludes rated jokes EXCEPT those rated this session
- Clear session-rated IDs on refresh
**Warning signs:** Jokes disappearing immediately after rating

## Code Examples

Verified patterns from existing codebase:

### Skeleton Loading at Bottom of Feed
```swift
// Source: JokeFeedView.swift lines 114-118 (existing)
// Loading more indicator (skeleton cards at bottom)
if viewModel.isLoadingMore {
    LoadingMoreView()
        .transition(.opacity)
}
```

### Minimum Loading Time for Smooth UX
```swift
// Source: JokeViewModel.swift lines 709-716 (existing)
private func ensureMinimumLoadingTime(startTime: Date) async {
    let minimumLoadingDuration: TimeInterval = 0.4
    let elapsed = Date().timeIntervalSince(startTime)
    if elapsed < minimumLoadingDuration {
        let remaining = minimumLoadingDuration - elapsed
        try? await Task.sleep(for: .milliseconds(Int(remaining * 1000)))
    }
}
```

### Pull-to-Refresh with Full Reset
```swift
// New implementation following CONTEXT.md decision
// "Pull-to-refresh: Full reset — reload from page 1, scroll to top"
ScrollView {
    // content
}
.refreshable {
    // Cancel any background loading
    backgroundLoadTask?.cancel()
    hasTriggeredBackgroundLoad = false

    // Clear session-rated tracking
    sessionRatedJokeIds.removeAll()

    // Reset pagination and refresh
    await viewModel.refresh()
}
```

### Retry Button on Load Failure
```swift
// Source: JokeFeedView.swift LoadMoreButton (existing styling)
// Reuse for retry button per CONTEXT.md
struct RetryLoadButton: View {
    let action: () -> Void

    private let primaryYellow = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("Retry Loading")  // Changed from "Load More Jokes"
                    .font(.headline.weight(.semibold))
                Image(systemName: "arrow.clockwise.circle.fill")  // Changed icon
                    .font(.title3)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(primaryYellow)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual "Load More" button | Automatic scroll-triggered loading | This phase | Better UX, no user action required |
| Show all jokes (rated/unrated) | Unrated-only feed | This phase | Fresher content, less clutter |
| Load on demand only | Background full catalog load | This phase | Enables proper popularity sorting |

**Deprecated/outdated:**
- `LoadMoreButton` component: Will be removed (keep code for retry button styling reference)
- Current `filteredJokes` behavior: Will change to exclude rated jokes

## Open Questions

Things that couldn't be fully resolved:

1. **Exact scroll threshold percentage**
   - What we know: CharacterDetailView uses "3 items from end"
   - What's unclear: Optimal number for main feed (may be different due to varied card heights)
   - Recommendation: Start with 3-5 items from end, tune based on testing

2. **Background loading on app backgrounded**
   - What we know: CONTEXT.md says "Claude's discretion (follow iOS guidelines)"
   - What's unclear: Should Task continue or be cancelled?
   - Recommendation: Let Task continue - Swift Concurrency handles suspension automatically. If app is terminated, task is cancelled. This is standard iOS behavior.

3. **Batch size for pagination**
   - What we know: Current `batchSize = 10` in JokeViewModel
   - What's unclear: Optimal balance between request frequency and efficiency
   - Recommendation: Keep 10 for visible scroll, use larger batches (50+) for background loading

## Sources

### Primary (HIGH confidence)
- Existing codebase: `JokeViewModel.swift`, `CharacterDetailViewModel.swift`, `JokeFeedView.swift`, `FirestoreService.swift`
- CONTEXT.md (Phase 8 user decisions)
- Apple SwiftUI documentation: LazyVStack, refreshable modifier

### Secondary (MEDIUM confidence)
- [SwiftUI Infinite Scroll Patterns](https://medium.com/whatnot-engineering/the-next-page-8950875d927a) - Whatnot Engineering
- [SwiftUI Pull to Refresh](https://www.swiftbysundell.com/articles/making-swiftui-views-refreshable/) - Swift by Sundell
- [LazyVStack Performance](https://www.strv.com/blog/swiftui-list-vs-lazyvstack) - STRV engineering blog
- [iOS Background Tasks](https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app) - Apple Documentation

### Tertiary (LOW confidence)
- N/A - All findings verified against codebase or official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools already in project, verified against codebase
- Architecture: HIGH - Patterns already proven in CharacterDetailView
- Pitfalls: HIGH - Based on actual iOS development experience and existing code patterns

**Research date:** 2026-01-30
**Valid until:** 60 days (stable iOS patterns, no major API changes expected)
