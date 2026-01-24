# Mr. Funny Jokes iOS App - Architecture Guide

## Overview

Mr. Funny Jokes is a SwiftUI-based iOS app featuring joke content delivered by different character personas. The architecture follows **MVVM (Model-View-ViewModel)** pattern with a clean separation of concerns across data access, business logic, and presentation layers.

## Architectural Pattern: MVVM

The app implements a classic MVVM pattern with the following key components:

### Layers

1. **Models (Data Layer)**
   - Define data structures and domain entities
   - Location: `/MrFunnyJokes/MrFunnyJokes/Models/`
   - Handles both app-specific and Firestore-mapped models

2. **ViewModels (Business Logic Layer)**
   - Manage state and coordinate between Views and Services
   - Handle data transformation and filtering
   - Track UI state (loading, errors, pagination)
   - Location: `/MrFunnyJokes/MrFunnyJokes/ViewModels/`

3. **Views (Presentation Layer)**
   - SwiftUI components that render UI
   - Observe ViewModels for state changes
   - Delegate user interactions to ViewModels
   - Location: `/MrFunnyJokes/MrFunnyJokes/Views/`

4. **Services (Data Access Layer)**
   - Encapsulate external dependencies (Firebase, UserDefaults, Network)
   - Singleton pattern for single instance throughout app lifetime
   - Location: `/MrFunnyJokes/MrFunnyJokes/Services/`

5. **Utilities (Helper Layer)**
   - Extensions and utility functions
   - Location: `/MrFunnyJokes/MrFunnyJokes/Utilities/`

## Data Flow Architecture

### Primary Data Flow: Home Feed

```
User Action (View)
    ↓
JokeFeedView (SwiftUI View)
    ↓
JokeViewModel (@ObservedObject + @MainActor)
    ↓
FirestoreService.shared (singleton)
    ↓
Firebase Firestore Database
    ↓ (documents cached locally via PersistentCacheSettings)
FirestoreJoke model (from Firestore)
    ↓ (converted to app model)
Joke model
    ↓ (stored in ViewModel)
JokeViewModel.jokes published property
    ↓ (triggers View redraw via @Published)
JokeFeedView renders updated UI
```

### State Management

#### Published Properties in ViewModels

**JokeViewModel** (primary state container):
- `@Published var jokes: [Joke]` - All fetched jokes
- `@Published var selectedCategory: JokeCategory?` - Current filter
- `@Published var isLoading: Bool` - Initial load state
- `@Published var isInitialLoading: Bool` - Splash screen sync
- `@Published var isLoadingMore: Bool` - Pagination state
- `@Published var isOffline: Bool` - Network connectivity
- `@Published var hasMoreJokes: Bool` - Pagination end flag
- `@Published var copiedJokeId: UUID?` - Temporary copy feedback state
- `@Published var jokeOfTheDayId: String?` - Daily featured joke ID

#### Derived Properties (Computed)

```swift
var filteredJokes: [Joke] {
    guard let category = selectedCategory else { return jokes }
    return jokes.filter { $0.category == category }
}

var ratedJokes: [Joke] { jokes.filter { $0.userRating != nil } }
var hilariousJokes: [Joke] { jokes.filter { $0.userRating == 5 } }
// ... filtered by rating (1-5)
```

## Key Components

### 1. Entry Point

**File:** `/MrFunnyJokes/MrFunnyJokes/App/MrFunnyJokesApp.swift`

```swift
@main
struct MrFunnyJokesApp: App
```

- Initializes Firebase (`FirebaseApp.configure()`)
- Sets up App Delegate for notifications
- Renders `RootView()`

**RootView Responsibilities:**
- Controls splash screen lifecycle
- Defers ViewModel creation to avoid blocking main thread
- Ensures minimum splash duration (1.0s) and maximum (5.0s)
- Manages transition from splash to main content

**MainContentView:**
- TabView with 3 tabs (Home, Me, Search)
- Handles deep linking (scheme: `mrfunnyjokes://`)
- Manages navigation stack
- Stores notification listener

### 2. Models

#### Joke.swift
```swift
struct Joke: Identifiable, Codable, Equatable {
    let id: UUID                          // Local UUID
    let category: JokeCategory            // Dad Jokes | Knock-Knock | Pickup Lines
    let setup: String
    let punchline: String
    var userRating: Int?                  // 1-5 scale, user-provided

    // Firestore fields
    var firestoreId: String?              // Firestore document ID
    var character: String?                // mr_funny, mr_potty, mr_bad, mr_love, mr_sad
    var tags: [String]?
    var sfw: Bool
    var source: String?                   // classic, original, submitted
    var ratingCount: Int                  // Count of community ratings
    var ratingAvg: Double                 // Average community rating
    var likes: Int                        // Community likes
    var dislikes: Int                     // Community dislikes
    var popularityScore: Double           // Computed popularity metric
}
```

**Key Features:**
- Dual ID system: `id` (UUID for local use) and `firestoreId` (for Firestore)
- User rating separate from community metrics
- Supports custom encoding/decoding for JSON serialization
- Includes formatting methods for sharing (special handling for knock-knock jokes)

#### Character.swift (JokeCharacter)
```swift
struct JokeCharacter: Identifiable, Hashable {
    let id: String                        // mr_funny, mr_potty, etc.
    let name: String
    let fullName: String
    let bio: String
    let imageName: String                 // Asset catalog reference
    let color: Color
    let backgroundColor: Color            // For featured cards
    let allowedCategories: [JokeCategory]
}
```

**Characters:**
- Mr. Funny (puns/wordplay) → `mr_funny`
- Mr. Potty (bathroom humor) → `mr_potty`
- Mr. Bad (dark humor) → `mr_bad`
- Mr. Love (romantic pickup lines) → `mr_love`
- Mr. Sad (melancholy/depressing) → `mr_sad`

#### JokeCategory.swift
```swift
enum JokeCategory: String, CaseIterable {
    case dadJoke = "Dad Jokes"
    case knockKnock = "Knock-Knock Jokes"
    case pickupLine = "Pick Up Lines"
}
```

#### FirestoreModels.swift
```swift
struct FirestoreJoke: Codable, Identifiable {
    @DocumentID var id: String?
    let text: String                      // Full joke text (setup + punchline)
    let type: String                      // Firestore type field
    let character: String?
    let tags: [String]?
    // ... ratings and metrics

    func toJoke() -> Joke { ... }         // Converts to app model
}

struct FirestoreCharacter: Codable, Identifiable {
    // Character data from Firestore
}

struct WeeklyRankings: Codable {
    // Weekly top 10 rankings
}
```

### 3. ViewModels

#### JokeViewModel.swift
**Primary state container for the entire app.**

```swift
@MainActor
final class JokeViewModel: ObservableObject {
    // State
    @Published var jokes: [Joke] = []
    @Published var selectedCategory: JokeCategory? = nil
    @Published var isInitialLoading = true
    @Published var isOffline = false
    @Published var jokeOfTheDayId: String?

    // Services (injected singletons)
    private let firestoreService = FirestoreService.shared
    private let storage = LocalStorageService.shared
    private let sharedStorage = SharedStorageService.shared
    private let networkMonitor = NetworkMonitor.shared

    // Async task management
    private var initialLoadTask: Task<Void, Never>?
    private var loadMoreTask: Task<Void, Never>?
}
```

**Key Methods:**

1. **Initial Load**
   - `loadInitialJokes()` - Fetches first batch
   - Waits for network readiness via `networkMonitor.isConnected`
   - Loads Joke of the Day
   - Preloads local storage cache

2. **Filtering**
   - `selectCategory(_ category: JokeCategory?)` - Updates filter
   - `filteredJokes` computed property applies category filter

3. **Pagination (Infinite Scroll)**
   - `loadMoreJokes()` - Fetches next batch
   - `loadMoreJokesForCategory()` - Pagination per category
   - Prevents concurrent load operations via task cancellation

4. **User Actions**
   - `rateJoke(_ joke: Joke, rating: Int)` - Updates local rating, sends to Firestore
   - `copyJoke(_ joke: Joke)` - Copies to clipboard with feedback
   - `shareJoke(_ joke: Joke)` - Opens share sheet
   - `markJokeImpression(_ joke: Joke)` - Tracks viewed jokes

5. **Search**
   - `searchJokes(_ text: String)` - Delegates to FirestoreService

6. **Me Tab (User's Rated Jokes)**
   - `var ratedJokes: [Joke]` - All rated jokes
   - Grouped by rating: `hilariousJokes`, `funnyJokes`, `mehJokes`, etc.

#### CharacterDetailViewModel.swift
**Manages state for character detail view.**

```swift
@MainActor
final class CharacterDetailViewModel: ObservableObject {
    @Published var jokes: [Joke] = []
    @Published var character: JokeCharacter
    @Published var isLoading = true
    @Published var hasMoreJokes = true

    private let firestoreService = FirestoreService.shared
}
```

**Responsibilities:**
- Fetch jokes for a specific character
- Handle pagination per character
- Manage character-specific loading state

#### WeeklyRankingsViewModel.swift
**Manages state for weekly top 10 rankings.**

```swift
@MainActor
final class WeeklyRankingsViewModel: ObservableObject {
    @Published var weeklyRankings: WeeklyRankings?
    @Published var rankedJokes: [String: Joke] = [:]
    @Published var isLoading = false
}
```

**Responsibilities:**
- Fetch current week's rankings
- Load ranked jokes by IDs
- Manage weekly top 10 carousel

### 4. Services

#### FirestoreService.swift
**Singleton service for Firebase Firestore database access.**

```swift
final class FirestoreService {
    static let shared = FirestoreService()

    private let db: Firestore
    private let jokesCollection = "jokes"
    private let charactersCollection = "characters"
    private let ratingEventsCollection = "rating_events"
    private let weeklyRankingsCollection = "weekly_rankings"

    // Pagination cursors
    private var lastDocument: DocumentSnapshot?
    private var lastDocumentsByCategory: [JokeCategory: DocumentSnapshot] = [:]
    private var lastDocumentsByCharacter: [String: DocumentSnapshot] = [:]
}
```

**Key Features:**

1. **Firestore Configuration**
   - Persistent cache enabled (50MB limit)
   - Optimized for offline-first experience
   - Server-side pagination with cursors

2. **Fetch Operations**
   - `fetchInitialJokes(limit: Int, forceRefresh: Bool)` - Top 20 jokes
   - `fetchMoreJokes(limit: Int)` - Next batch with cursor
   - `fetchJokes(category: JokeCategory)` - Category-filtered
   - `fetchInitialJokesAllCategories()` - Mixed categories, shuffled
   - `fetchJokeOfTheDay(date: Date)` - From daily_jokes collection
   - `fetchRandomJoke()` - Fallback for missing JOTD
   - `fetchJoke(byId: String)` - Single joke lookup
   - `fetchJokes(byCharacter: String)` - Character filtering
   - `searchJokes(searchText: String)` - Client-side full-text search

3. **Rating Updates**
   - `updateJokeRating(jokeId: String, rating: Int)` - Transaction-based update
   - `updateJokeLike(jokeId: String, isLike: Bool)` - Increment operations
   - `logRatingEvent(...)` - Track ratings for weekly rankings

4. **Weekly Rankings**
   - `fetchWeeklyRankings()` - Current week's top 10
   - `fetchJokes(byIds: [String])` - Batch fetch by IDs (handles 30-item limit)
   - `getCurrentWeekId()` - ISO week ID in Eastern Time

**Query Strategy:**
- Orders by `popularity_score` (descending)
- Uses Firestore cache for repeated queries
- Composite indexes required for character + popularity_score queries
- Handles inconsistent Firestore field values (e.g., "pickup_line" vs "pickup")

#### LocalStorageService.swift
**Singleton service for persisting user data locally.**

```swift
final class LocalStorageService: @unchecked Sendable {
    static let shared = LocalStorageService()

    private let userDefaults: UserDefaults
    private let ratingsKey = "jokeRatings"
    private let impressionsKey = "jokeImpressions"
    private let deviceIdKey = "anonymousDeviceId"
    private let queue = DispatchQueue(...)  // For thread safety
}
```

**Responsibilities:**
- Store user ratings locally (persists across sessions)
- Track joke impressions (views)
- Generate anonymous device ID for rating deduplication
- In-memory cache for fast access during startup
- Manages cache limits (50 jokes/category, 500 impressions max)

**Key Methods:**
- `saveRating(jokeId: String, rating: Int)` - Local only, separate from Firestore
- `loadRatings() -> [String: Int]` - All ratings
- `getRating(jokeId: String) -> Int?` - Single rating lookup
- `markImpression(jokeId: String)` - Track viewed jokes
- `hasImpression(jokeId: String) -> Bool` - Check if viewed
- `preloadMemoryCache()` - Async startup optimization

#### SharedStorageService.swift
**Cross-target shared storage for main app and widget extension.**

```swift
final class SharedStorageService {
    static let shared = SharedStorageService()
    static let appGroupIdentifier = "group.com.bvanaski.mrfunnyjokes"
}
```

**Responsibilities:**
- Share Joke of the Day between main app and widget
- Uses App Groups for container access
- Encodes/decodes `SharedJokeOfTheDay` data

#### NotificationManager.swift
**Singleton service for managing push notifications.**

**Responsibilities:**
- Request notification permissions
- Schedule daily "Joke of the Day" notifications
- Handle notification taps (deep link to home tab)
- Persist notification settings

#### NetworkMonitor.swift
**Singleton service for network connectivity detection.**

```swift
final class NetworkMonitor: ObservableObject {
    @Published var isConnected: Bool = true
}
```

**Responsibilities:**
- Monitor network status changes
- Update UI when offline/online
- Block initial data load until network ready

### 5. Views Layer

**SwiftUI Views use @ObservedObject to reactively observe ViewModels.**

#### Root Navigation Flow

```
MrFunnyJokesApp
    ↓
RootView (splash screen controller)
    ↓
MainContentView (TabView)
    ├─ Home Tab → JokeFeedView
    ├─ Me Tab → MeView
    └─ Search Tab → SearchView
```

#### Key Views

1. **JokeFeedView**
   - Main feed with infinite scroll
   - Shows character carousel (All only)
   - Shows Joke of the Day (All only)
   - Shows YouTube promo card (All only)
   - Shows Weekly Top 10 carousel (All only)
   - Filters jokes by category
   - Delegates interactions to JokeViewModel

2. **JokeCardView**
   - Individual joke display card
   - Setup/punchline rendering
   - Rating emoji feedback
   - Copy/share buttons
   - Like/dislike buttons

3. **CharacterDetailView**
   - Shows all jokes for a character
   - Pagination support
   - Uses CharacterDetailViewModel

4. **CharacterCarouselView**
   - Horizontal scrollable character list
   - Character tap navigation

5. **JokeDetailSheet**
   - Full-screen presentation of single joke
   - Rating interface (emoji scale 1-5)
   - Sharing options
   - Statistics display (likes, dislikes, ratings)

6. **MeView**
   - User's rated jokes
   - Filter by category
   - Group by rating (Hilarious, Funny, Meh, Groan, Horrible)
   - Statistics (jokes rated, average rating)

7. **SearchView**
   - Text input for joke search
   - Searches setup, punchline, tags, type
   - Displays matching results

8. **JokeOfTheDayView**
   - Hero card with character background
   - Special styling for featured joke
   - Rating action with emoji feedback

9. **SettingsView**
   - Toggle notifications on/off
   - Display current notification time
   - Privacy settings

10. **SplashScreenView**
    - App logo and branding
    - Loading animation
    - Appears during initial data load

#### Skeleton/Loading Views

**Skeleton Screens for better perceived performance:**
- `SkeletonFeedView` - Loading state for main feed
- `SkeletonJokeOfTheDayView` - Loading Joke of the Day
- `SkeletonCardView` - Generic loading card
- `ShimmerModifier` - Animation for skeleton loaders

#### Weekly Top 10 Views

- `WeeklyTopTenCarouselView` - Horizontal carousel of top 5
- `WeeklyTopTenDetailView` - Full screen with all 10

## Data Persistence Strategy

### Three-Tier Caching

1. **Firestore Remote Cache** (via PersistentCacheSettings)
   - 50MB persistent disk cache
   - Automatic offline access
   - Set in FirestoreService initialization

2. **Local UserDefaults Cache**
   - User ratings (persisted locally, synced to Firestore)
   - Joke impressions (views)
   - Anonymous device ID
   - App settings (notifications enabled, notification time)

3. **In-Memory Cache**
   - ViewModel.jokes array (all loaded jokes)
   - Pagination cursors (lastDocument, lastDocumentsByCategory, etc.)
   - Computed properties (filteredJokes, ratedJokes, etc.)

### Sync Strategy

- **Ratings**: Save to local storage immediately, then sync to Firestore asynchronously
- **Impressions**: Local tracking only (not synced to Firestore)
- **Joke of the Day**: Cached in SharedStorageService for widget access

## Network Handling

### Offline Detection

1. **Network Monitor** observes system connectivity
2. ViewModel subscribed to `networkMonitor.isConnected`
3. Shows "Offline" banner in feed
4. Uses Firestore cache for data access when offline
5. Defers Firestore operations until online (ratings, logging events)

### Retry Strategy

- Initial load waits for network via async/await
- No explicit retry logic (Firestore SDK handles retries)
- User can pull-to-refresh to force reload

## Pagination Architecture

### Cursor-Based Pagination

**FirestoreService maintains three pagination cursors:**

1. **Global Cursor** (`lastDocument`)
   - For "All Jokes" feed (no filter)

2. **Per-Category Cursors** (`lastDocumentsByCategory`)
   - Separate cursor for each JokeCategory
   - Allows switching between categories without losing position

3. **Per-Character Cursors** (`lastDocumentsByCharacter`)
   - Separate cursor for each character
   - Enables character detail view pagination

**Flow:**
```
Initial Load: fetchInitialJokes() → returns 20 jokes + sets lastDocument
Load More: fetchMoreJokes() → queries after lastDocument + updates cursor
Category Change: resetPagination() → clears appropriate cursor
```

## State Synchronization

### JokeViewModel State Sync

1. **Initial Load Sequence**
   - ViewModel created in RootView
   - `isInitialLoading = true` (shows skeleton)
   - `loadInitialJokes()` triggered
   - Waits for network via NetworkMonitor
   - Fetches jokes, loads JOTD, loads ratings
   - `isInitialLoading = false` (allows splash transition)

2. **Ongoing Updates**
   - User rates joke → Updates local storage + Firestore
   - ViewModel updates joke in jokes array
   - @Published triggers View redraw

3. **Navigation State**
   - MainContentView maintains `navigationPath: NavigationPath`
   - Cleared on app launch to prevent frozen states after force-close
   - NavigationStack controls back button behavior

## Widget Integration

### Joke of the Day Widget

**Flow:**
1. Main app fetches JOTD from `daily_jokes` collection
2. Saves to SharedStorageService via App Groups
3. Widget extension reads from same App Group container
4. Widget displays saved JOTD data
5. Tapping widget uses deep link to open app at home tab

**Files:**
- `JokeOfTheDayWidget.swift` - Widget configuration
- `JokeOfTheDayProvider.swift` - Data provider for widget
- `JokeOfTheDayWidgetViews.swift` - Widget UI components

## Dependency Injection

### Singleton Pattern (Implicit Injection)

Services are singletons accessed via `.shared`:
```swift
private let firestoreService = FirestoreService.shared
private let storage = LocalStorageService.shared
```

### ViewModel Injection

ViewModels are created directly in Views or parent Views:
```swift
@State private var jokeViewModel: JokeViewModel?
// In onAppear: jokeViewModel = JokeViewModel()

// Pass to child views:
JokeFeedView(viewModel: jokeViewModel, ...)
```

## Error Handling

### Strategy

1. **Silent Failures with Fallbacks**
   - Firestore errors don't crash app
   - Uses cached data when fetch fails
   - Shows "Offline" banner for network issues

2. **Error Types** (FirestoreError enum)
   - `.documentNotFound` - Document missing from Firestore
   - `.decodingError` - Malformed Firestore data
   - `.networkError(Error)` - Network connectivity issues

3. **No Explicit Error UI**
   - Errors logged via print()
   - App continues with partial data
   - Relies on Firestore cache for resilience

## Performance Optimizations

1. **Lazy Loading**
   - Skeleton screens hide load time
   - Infinite scroll loads batches on demand
   - Images lazy-loaded via asset catalog

2. **Pagination**
   - Limits initial load to 20 jokes
   - Loads 10 more on scroll
   - Prevents loading all jokes at once

3. **Caching**
   - 50MB Firestore persistent cache
   - Local UserDefaults for ratings/impressions
   - In-memory pagination cursors

4. **ViewModel Threading**
   - `@MainActor` ensures UI updates on main thread
   - Async/await for non-blocking I/O
   - Task cancellation prevents redundant requests

5. **View Optimization**
   - `LazyVStack` for feed rendering
   - `ScrollViewReader` for reliable scroll positioning
   - `.id()` modifiers for scroll targets

## Testing Architecture

**Not explicitly shown in codebase, but would leverage:**
- Mock FirestoreService for unit tests
- Mock LocalStorageService for storage tests
- ViewModel state assertions for business logic
- SwiftUI preview providers for UI snapshot tests

## Summary

The Mr. Funny Jokes app uses a **clean MVVM architecture** with:
- Clear separation of concerns (Models, ViewModels, Views, Services)
- Singleton services for dependency management
- @Published properties for reactive UI updates
- Firestore + UserDefaults for three-tier caching
- Pagination cursors for server-side data management
- NetworkMonitor for offline detection
- App Groups for main app ↔ widget integration
