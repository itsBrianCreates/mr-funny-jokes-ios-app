# Code Conventions & Patterns

Mr. Funny Jokes iOS app follows consistent Swift and SwiftUI conventions across the codebase. This document outlines the established patterns for naming, structure, and error handling.

## File Organization

The codebase is organized into clear functional modules:

```
MrFunnyJokes/
├── App/                  # Application entry point
├── Models/              # Data structures and Codable models
├── ViewModels/          # SwiftUI @ObservableObject classes
├── Views/               # SwiftUI View structs
├── Services/            # Business logic (Firebase, storage, network)
├── Utilities/           # Helper classes and extensions
└── Shared/              # Shared code with widgets
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/`

## Naming Conventions

### Type Naming

**Classes & ViewModels:**
- Use `ViewModel` suffix: `JokeViewModel`, `CharacterDetailViewModel`
- Use singular, descriptive names: `FirestoreService`, `LocalStorageService`
- Avoid generic names like "Manager" unless truly generic (e.g., `HapticManager`, `NetworkMonitor`)

**Structs & Models:**
- Use descriptive names: `Joke`, `JokeCharacter`, `FirestoreJoke`
- Enums use singular form: `JokeCategory`, not `JokeCategories`
- Avoid naming conflict with Swift stdlib: Named `JokeCharacter` instead of `Character` (see `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Models/Character.swift` line 4)

**Views:**
- Use `View` suffix: `JokeCardView`, `JokeFeedView`, `CharacterCarouselView`
- Use `OMeter` or similar for measurement views: `GrainOMeterView`, `CompactGroanOMeterView`

**Singletons:**
- Use static `shared` property: `FirestoreService.shared`, `LocalStorageService.shared`
- Private initializer: `private init()`

### Property Naming

**SwiftUI Published Properties:**
```swift
@Published var jokes: [Joke] = []
@Published var isLoading = false
@Published var isRefreshing = false
@Published var copiedJokeId: UUID?
```

- Boolean properties use `is` or `has` prefix: `isLoading`, `hasMoreJokes`
- Use `@Published` for reactive state changes
- Use `@Published private(set)` for read-only properties: `@Published private(set) var jokeOfTheDayId: String?`

**Private Properties:**
```swift
private let storage = LocalStorageService.shared
private let firestoreService = FirestoreService.shared
private var cancellables = Set<AnyCancellable>()
private let batchSize = 10
```

- Use meaningful names for constants: `batchSize`, `maxCachePerCategory`
- Use descriptive names for collections: `cachedImpressionIds`, `cachedRatedIds`

**Computed Properties:**
- Follow snake_case style but read naturally: `filteredJokes`, `jokeOfTheDay`, `hilariousJokes`
- Use guards and filters for clarity

### Function Naming

**Action Methods (no return value):**
```swift
func rateJoke(_ joke: Joke, rating: Int)
func shareJoke(_ joke: Joke)
func copyJoke(_ joke: Joke)
func selectCategory(_ category: JokeCategory?)
func markJokeImpression(_ joke: Joke)
```

**Async Methods:**
- Use `Async` suffix for async variants when both sync and async exist:
  ```swift
  func loadInitialContentAsync() async
  func preloadMemoryCache()              // sync
  func preloadMemoryCacheAsync() async   // async variant
  ```

**Fetch/Query Methods:**
```swift
func fetchJokes(category: JokeCategory, limit: Int = 20) async throws -> [Joke]
func fetchMoreJokes(limit: Int = 10) async throws -> [Joke]
func fetchInitialJokesAllCategories(countPerCategory: Int) async throws -> [Joke]
```

**Load/Cache Methods:**
```swift
func loadAllCachedJokes() -> [Joke]
func loadAllCachedJokesAsync() async -> [Joke]
func loadJokeOfTheDayFromStorage()
func initializeJokeOfTheDay()
```

## Code Style & Patterns

### MainActor Annotation

Classes that manage UI state use `@MainActor`:

```swift
@MainActor
final class JokeViewModel: ObservableObject {
    // ...
}

@MainActor
final class NetworkMonitor: ObservableObject {
    // ...
}
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` line 5

### Final Classes

Classes are marked `final` to prevent subclassing and improve compilation:

```swift
final class FirestoreService { ... }
final class LocalStorageService: @unchecked Sendable { ... }
final class HapticManager { ... }
```

### Computed Properties for Filtering

Consistent pattern for derived data:

```swift
var filteredJokes: [Joke] {
    guard let category = selectedCategory else {
        return jokes
    }
    return jokes.filter { $0.category == category }
}

var hilariousJokes: [Joke] {
    jokes.filter { $0.userRating == 5 }
}
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` lines 42-73

### Haptic Feedback Consistency

All user interactions trigger haptic feedback through `HapticManager`:

```swift
HapticManager.shared.lightTap()          // Card interactions
HapticManager.shared.mediumImpact()      // Punchline reveal
HapticManager.shared.selection()         // Ratings
HapticManager.shared.success()           // Copy/share
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Utilities/HapticManager.swift`

### MARK Comments

Code sections organized with MARK comments for navigation:

```swift
// MARK: - Filtered Rated Jokes (for Me tab)
// MARK: - Feed Algorithm (Freshness Sorting)
// MARK: - Initial Load
// MARK: - Refresh (Category Change)
// MARK: - Infinite Scroll (Load More)
// MARK: - Ratings
// MARK: - Sharing
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` multiple sections

## Error Handling Patterns

### Async/Await with Try/Catch

Standard pattern for network and database operations:

```swift
do {
    let newJokes = try await firestoreService.fetchInitialJokesAllCategories(
        countPerCategory: initialLoadPerCategory
    )

    guard !Task.isCancelled else { return }

    if !newJokes.isEmpty {
        // Process jokes
    }
} catch {
    print("Firestore fetch error: \(error)")
    // Fallback to cached content
    if jokes.isEmpty {
        loadLocalJokes()
    }
}
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` lines 425-462

### Task Cancellation Handling

Tasks are checked for cancellation to respect system lifecycle:

```swift
loadMoreTask?.cancel()
loadMoreTask = Task {
    await performLoadMore()
}

// Inside async function:
guard !Task.isCancelled else {
    isLoadingMore = false
    return
}
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` lines 585-610

### Fallback Strategies

Graceful degradation when primary data source fails:

**Cache-First Pattern:**
1. Load from UserDefaults cache (instant)
2. Show cached content immediately
3. Fetch fresh from Firebase in background
4. Update UI when Firebase data arrives

```swift
// PHASE 1: Preload memory cache
await storage.preloadMemoryCacheAsync()

// PHASE 2: Load cached jokes
let cached = await storage.loadAllCachedJokesAsync()

if !cached.isEmpty {
    jokes = sortJokesForFreshFeed(cached)
    await completeInitialLoading()
    // PHASE 3: Fetch fresh in background
    await fetchInitialAPIContentBackground()
} else {
    // No cache, must wait for Firebase
    await fetchInitialAPIContent()
}
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` lines 308-328

### Optional Handling

**Safe Unwrapping Pattern:**
```swift
guard let savedJoke = sharedStorage.loadJokeOfTheDay() else { return }
guard let character = JokeCharacter.find(byId: characterId) else { fallback }
```

**Nil-Coalescing for Defaults:**
```swift
let characterName: String
if let characterId = joke.character,
   let character = JokeCharacter.find(byId: characterId) {
    characterName = character.name
} else {
    characterName = "Mr. Funny Jokes"  // Fallback
}
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` lines 721-728

## SwiftUI View Patterns

### View Composition

Views are decomposed into smaller, focused views:
- `JokeCardView` - Individual joke card
- `JokeFeedView` - Feed list with infinite scroll
- `CharacterCarouselView` - Character selection carousel
- `JokeDetailSheet` - Expanded joke view with actions

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Views/`

### Private Computed View Properties

Complex view logic extracted to computed properties:

```swift
private var cardPreviewText: String {
    if joke.category == .knockKnock {
        return formatKnockKnockPreview(joke.setup)
    }
    return joke.setup
}

private func formatKnockKnockPreview(_ setup: String) -> String {
    // Complex formatting logic
}
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Views/JokeCardView.swift` lines 18-39

### Callback Pattern in Views

Views accept closures for actions:

```swift
struct JokeCardView: View {
    let joke: Joke
    let isCopied: Bool
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void
}
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Views/JokeCardView.swift` lines 3-8

## Coding Best Practices

### Memory Management

**Weak Self in Closures:**
```swift
.sink { [weak self] notification in
    self?.handleRatingNotification(notification)
}
```

**Sendable Protocol:**
For thread-safe classes: `final class LocalStorageService: @unchecked Sendable`

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Services/LocalStorageService.swift` line 3

### Type Safety

**Enum Coding Keys for Firestore Mapping:**
```swift
enum CodingKeys: String, CodingKey {
    case id
    case text
    case type
    case createdAt = "created_at"
    case ratingCount = "rating_count"
}
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Models/FirestoreModels.swift` lines 23-38

### Constants and Magic Numbers

Magic numbers avoided with named constants:

```swift
private let batchSize = 10
private let initialLoadPerCategory = 8
private let maxCachePerCategory = 50
private let maxImpressions = 500
private let minimumLoadingDuration: TimeInterval = 0.4
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` lines 37-40

## Notification Pattern

Custom notifications for cross-ViewModel communication:

```swift
extension Notification.Name {
    static let jokeRatingDidChange = Notification.Name("jokeRatingDidChange")
}

// Post:
NotificationCenter.default.post(
    name: .jokeRatingDidChange,
    object: nil,
    userInfo: ["rating": rating, "jokeId": jokeId]
)

// Subscribe:
NotificationCenter.default.publisher(for: .jokeRatingDidChange)
    .sink { [weak self] notification in
        self?.handleRatingNotification(notification)
    }
    .store(in: &cancellables)
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/ViewModels/CharacterDetailViewModel.swift` lines 5-7

## Documentation

### Doc Comments for Public APIs

Public methods include clear documentation:

```swift
/// Fetches initial jokes from Firestore
/// - Parameters:
///   - limit: Number of jokes to fetch (default 20)
///   - forceRefresh: If true, bypasses Firestore cache and fetches from server
/// - Returns: Array of Joke objects
func fetchInitialJokes(limit: Int = 20, forceRefresh: Bool = false) async throws -> [Joke]
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Services/FirestoreService.swift` lines 34-38

### Inline Comments for Complex Logic

Algorithms include explanatory comments:

```swift
// PHASE 1: Preload memory cache for fast sorting (critical for performance)
await storage.preloadMemoryCacheAsync()

// PHASE 2: Load cached jokes asynchronously (off main thread)
let cached = await storage.loadAllCachedJokesAsync()
```

**Location:** `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift` lines 309-313

## Linting & Formatting

**Status:** No SwiftLint or SwiftFormat configuration file found in the repository. The codebase follows Swift style guidelines manually.

**Recommendations:**
- Add `.swiftlint.yml` for consistent lint rules
- Add `.swiftformat` for automated formatting
- Run swiftformat as pre-commit hook

**Total Swift Files:** 38 files across all modules
