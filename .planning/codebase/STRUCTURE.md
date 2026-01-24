# Mr. Funny Jokes iOS App - Project Structure Guide

## Directory Layout

```
/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/
├── MrFunnyJokes/                                    # Xcode workspace root
│   ├── MrFunnyJokes.xcodeproj/                      # Project configuration
│   ├── MrFunnyJokes/                                # Main app target
│   │   ├── App/
│   │   │   └── MrFunnyJokesApp.swift                # Entry point, AppDelegate, RootView, MainContentView
│   │   ├── Models/                                  # Data structures
│   │   │   ├── Character.swift                      # JokeCharacter enum + definitions
│   │   │   ├── Joke.swift                           # Main Joke model with Codable
│   │   │   ├── JokeCategory.swift                   # Dad Jokes, Knock-Knock, Pickup Lines
│   │   │   └── FirestoreModels.swift                # Firestore mapping models
│   │   ├── ViewModels/                              # MVVM business logic
│   │   │   ├── JokeViewModel.swift                  # Primary state container
│   │   │   ├── CharacterDetailViewModel.swift       # Character view state
│   │   │   └── WeeklyRankingsViewModel.swift        # Weekly top 10 state
│   │   ├── Views/                                   # SwiftUI presentation layer
│   │   │   ├── CharacterCarouselView.swift          # Horizontal character list
│   │   │   ├── CharacterDetailView.swift            # Character jokes detail screen
│   │   │   ├── GrainOMeterView.swift                # "Grain-O-Meter" rating visualization
│   │   │   ├── JokeCardView.swift                   # Individual joke card
│   │   │   ├── JokeDetailSheet.swift                # Full joke detail modal
│   │   │   ├── JokeFeedView.swift                   # Main feed with infinite scroll
│   │   │   ├── JokeOfTheDayView.swift               # Featured daily joke hero card
│   │   │   ├── MeView.swift                         # User's rated jokes tab
│   │   │   ├── SearchView.swift                     # Joke search interface
│   │   │   ├── SettingsView.swift                   # App settings and notifications
│   │   │   ├── SplashScreenView.swift               # Launch splash screen
│   │   │   ├── YouTubePromoCardView.swift           # YouTube channel promo card
│   │   │   ├── Skeleton/                            # Loading state views
│   │   │   │   ├── ShimmerModifier.swift            # Shimmer animation
│   │   │   │   ├── SkeletonCardView.swift           # Loading card placeholder
│   │   │   │   ├── SkeletonFeedView.swift           # Loading feed placeholder
│   │   │   │   └── SkeletonJokeOfTheDayView.swift   # Loading JOTD placeholder
│   │   │   └── WeeklyTopTen/                        # Weekly rankings UI
│   │   │       ├── RankedJokeCard.swift             # Individual ranking card
│   │   │       ├── WeeklyTopTenCarouselView.swift   # Top 5 horizontal carousel
│   │   │       └── WeeklyTopTenDetailView.swift     # Full top 10 detail view
│   │   ├── Services/                                # Singleton services (data access)
│   │   │   ├── FirestoreService.swift               # Firebase Firestore queries
│   │   │   ├── LocalStorageService.swift            # UserDefaults persistence
│   │   │   ├── NetworkMonitor.swift                 # Network connectivity detection
│   │   │   └── NotificationManager.swift            # Push notifications + scheduling
│   │   ├── Utilities/                               # Helper extensions
│   │   │   ├── Color+Extensions.swift               # Custom color definitions
│   │   │   └── HapticManager.swift                  # Haptic feedback helper
│   │   ├── Resources/                               # Non-asset resources
│   │   ├── Assets.xcassets/                         # Image assets
│   │   │   ├── AppIcon.appiconset/                  # App icon variants
│   │   │   ├── Characters/                          # Character images
│   │   │   │   ├── MrFunny.imageset/
│   │   │   │   ├── MrBad.imageset/
│   │   │   │   ├── MrLove.imageset/
│   │   │   │   ├── MrPotty.imageset/
│   │   │   │   └── MrSad.imageset/
│   │   │   └── AccentColor.colorset/
│   │   ├── Preview Content/                         # SwiftUI preview assets
│   │   ├── GoogleService-Info.plist                 # Firebase configuration
│   │   ├── Info.plist                               # App metadata
│   │   ├── LaunchScreen.storyboard                  # Launch screen definition
│   │   ├── PrivacyInfo.xcprivacy                    # Privacy manifest
│   │   └── MrFunnyJokes.entitlements                # App capabilities (App Groups, Notifications)
│   ├── Shared/                                      # Shared framework between app and widget
│   │   ├── SharedJokeOfTheDay.swift                 # JOTD data model for widget
│   │   └── SharedStorageService.swift               # App Groups container access
│   ├── JokeOfTheDayWidget/                          # Widget extension target
│   │   ├── JokeOfTheDayWidget.swift                 # Widget configuration and entry
│   │   ├── JokeOfTheDayProvider.swift               # Widget data provider
│   │   ├── JokeOfTheDayWidgetViews.swift            # Widget UI components
│   │   └── Assets.xcassets/                         # Widget-specific assets
│   └── project.pbxproj                              # Xcode project configuration
├── scripts/                                         # Build and utility scripts
│   ├── add-jokes.js                                 # Firebase joke insertion script
│   └── videos/                                      # Video assets
├── docs/                                            # Documentation
├── .git/                                            # Git repository
└── CLAUDE.md                                        # Claude Code AI instructions

```

## Key Locations Quick Reference

### To Find...

**App Entry Point**
→ `/MrFunnyJokes/MrFunnyJokes/App/MrFunnyJokesApp.swift`
- Main @main struct, AppDelegate, RootView, MainContentView

**Main Feed Screen**
→ `/MrFunnyJokes/MrFunnyJokes/Views/JokeFeedView.swift`
- Home tab implementation, character carousel, JOTD display

**Single Joke Display**
→ `/MrFunnyJokes/MrFunnyJokes/Views/JokeCardView.swift` (inline)
→ `/MrFunnyJokes/MrFunnyJokes/Views/JokeDetailSheet.swift` (full screen)

**User's Rated Jokes (Me Tab)**
→ `/MrFunnyJokes/MrFunnyJokes/Views/MeView.swift`

**Search Functionality**
→ `/MrFunnyJokes/MrFunnyJokes/Views/SearchView.swift`

**Settings & Notifications**
→ `/MrFunnyJokes/MrFunnyJokes/Views/SettingsView.swift`

**All State Management**
→ `/MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift`
- Handles jokes, ratings, impressions, categories, loading states

**Character Details**
→ `/MrFunnyJokes/MrFunnyJokes/ViewModels/CharacterDetailViewModel.swift` (state)
→ `/MrFunnyJokes/MrFunnyJokes/Views/CharacterDetailView.swift` (UI)

**Firebase/Firestore Access**
→ `/MrFunnyJokes/MrFunnyJokes/Services/FirestoreService.swift`
- All database queries, pagination, ratings

**Local Storage (Ratings, Impressions)**
→ `/MrFunnyJokes/MrFunnyJokes/Services/LocalStorageService.swift`

**Notifications Setup**
→ `/MrFunnyJokes/MrFunnyJokes/Services/NotificationManager.swift`

**Data Models**
→ `/MrFunnyJokes/MrFunnyJokes/Models/Joke.swift`
→ `/MrFunnyJokes/MrFunnyJokes/Models/Character.swift`
→ `/MrFunnyJokes/MrFunnyJokes/Models/JokeCategory.swift`
→ `/MrFunnyJokes/MrFunnyJokes/Models/FirestoreModels.swift`

**Colors & Styling**
→ `/MrFunnyJokes/MrFunnyJokes/Utilities/Color+Extensions.swift`

**Loading Animations**
→ `/MrFunnyJokes/MrFunnyJokes/Views/Skeleton/ShimmerModifier.swift`

**Widget Extension**
→ `/MrFunnyJokes/JokeOfTheDayWidget/`

**Firebase Config**
→ `/MrFunnyJokes/MrFunnyJokes/GoogleService-Info.plist`

**App Capabilities**
→ `/MrFunnyJokes/MrFunnyJokes/MrFunnyJokes.entitlements`

## File Organization Principles

### By Layer (MVVM)

1. **Models/** - Pure data structures, no dependencies
   - Defines domain entities
   - Handles Codable for JSON serialization
   - No business logic

2. **ViewModels/** - Business logic & state management
   - @MainActor for thread safety
   - @Published for reactive updates
   - Coordinates between Views and Services
   - Handles filtering, pagination, user actions

3. **Views/** - SwiftUI presentation
   - @ObservedObject for ViewModel binding
   - Delegates actions to ViewModel
   - No business logic
   - Organized in subdirectories by feature (Skeleton/, WeeklyTopTen/)

4. **Services/** - External dependencies & data access
   - Singletons (.shared)
   - Encapsulate Firebase, UserDefaults, Network APIs
   - No UI code
   - Async operations return via Task-based APIs

5. **Utilities/** - Shared helpers & extensions
   - Color definitions
   - Haptic feedback
   - Extension methods

### By Feature

- **Skeleton/** - Loading state components
- **WeeklyTopTen/** - Weekly rankings feature
- **Shared/** - Code shared with widget extension

## Naming Conventions

### Files
- PascalCase for Swift files: `JokeViewModel.swift`, `JokeFeedView.swift`
- kebab-case for asset folders: `MrFunny.imageset`, `AppIcon.appiconset`

### Types
- **Structs:** `Joke`, `JokeCharacter`, `JokeCategory`
- **Classes (Singletons):** `JokeViewModel`, `FirestoreService`
- **Enums:** `JokeCategory`, `AppTab`

### Variables & Functions
- camelCase: `selectedCategory`, `filteredJokes`, `rateJoke()`
- Boolean prefixes: `isLoading`, `isOffline`, `hasMoreJokes`

### Published Properties
- Track state changes: `@Published var jokes: [Joke]`
- Use descriptive names: `selectedCategory`, `isInitialLoading`, `copiedJokeId`

### Private Properties
- Services: `private let firestoreService = FirestoreService.shared`
- Tasks: `private var initialLoadTask: Task<Void, Never>?`
- Queue: `private let queue = DispatchQueue(...)`

## Where to Add New Code

### New Feature: Add a New Character View
1. **Model:** Define character data in `Models/Character.swift`
2. **ViewModel:** Create `ViewModels/[CharacterName]ViewModel.swift`
3. **View:** Create `Views/[CharacterName]View.swift`
4. **Add to Navigation:** Update `MainContentView` in `App/MrFunnyJokesApp.swift`

### New Filter Type
1. **Model:** Add case to `Models/JokeCategory.swift`
2. **ViewModel:** Add filter logic to `JokeViewModel.swift`
3. **View:** Add filter UI to relevant view

### New Service Feature (e.g., Caching)
1. **Service:** Create `Services/[Feature]Service.swift`
2. **ViewModel:** Inject and use in appropriate ViewModel
3. **Error Handling:** Add error types if needed

### New Utility
1. **Utility:** Create `Utilities/[Category]+Extensions.swift` or `Utilities/[Name]Helper.swift`
2. **Export:** Import in files that need it

### New Loading State
1. **View:** Create `Views/Skeleton/Skeleton[ComponentName]View.swift`
2. **Use:** Replace content in relevant view during loading

## Firebase Collections & Documents

### Firestore Structure

```
Firestore Database
├── jokes/                          # Main jokes collection
│   ├── {autoId}                    # Document per joke
│   │   ├── character: "mr_funny"   # Character ID
│   │   ├── text: String            # Full joke text
│   │   ├── type: "dad_joke"        # Joke type
│   │   ├── tags: ["wordplay", ...]
│   │   ├── popularity_score: 42.5
│   │   ├── rating_count: 123
│   │   ├── rating_avg: 4.2
│   │   ├── likes: 50
│   │   ├── dislikes: 5
│   │   ├── created_at: Timestamp
│   │   └── updated_at: Timestamp
│   └── ...
├── daily_jokes/                    # Joke of the Day assignments
│   ├── "2025-01-24"                # Date as document ID
│   │   └── joke_id: "{autoId}"     # Reference to joke
│   └── ...
├── characters/                     # Character metadata
│   └── {characterId}
│       └── (character details)
├── rating_events/                  # Rating event logging
│   ├── "{deviceId}_{jokeId}_{weekId}"  # Composite key for deduplication
│   │   ├── joke_id: String
│   │   ├── rating: Int (1-5)
│   │   ├── device_id: String
│   │   └── timestamp: Timestamp
│   └── ...
└── weekly_rankings/                # Weekly top 10 data
    ├── "2025-W04"                  # ISO week ID as document
    │   ├── top_jokes: [String]     # Array of top 10 joke IDs
    │   ├── ranking_data: {...}
    │   └── generated_at: Timestamp
    └── ...
```

### Firestore Indexes

**Required composite index:**
- Collection: `jokes`
- Fields: `character` (Ascending), `popularity_score` (Descending)
- Used for: Character detail view pagination

**Automatic indexes:**
- Single-field indexes on: `type`, `popularity_score`, `created_at`

## UserDefaults Schema

**App-Level Settings:**
```swift
// NotificationManager
"notificationsEnabled": Bool
"jokeNotificationTime": String      // "08:00"

// LocalStorageService
"jokeRatings": [String: Int]        // [jokeId: rating]
"jokeImpressions": [String]         // [jokeId, jokeId, ...]
"anonymousDeviceId": String         // UUID

// SharedStorageService (via App Groups)
"group.com.bvanaski.mrfunnyjokes" {
    "jokeOfTheDay": Data            // Encoded SharedJokeOfTheDay
}
```

## Target Memberships

### MrFunnyJokes (Main App)
- All Swift files in `/MrFunnyJokes/MrFunnyJokes/`
- Google Service Info plist
- Assets
- Entitlements (App Groups capability)

### JokeOfTheDayWidget (Widget Extension)
- `JokeOfTheDayWidget.swift`
- `JokeOfTheDayProvider.swift`
- `JokeOfTheDayWidgetViews.swift`
- `Shared/` files (SharedStorageService, SharedJokeOfTheDay)
- Widget-specific assets

### Shared Framework
- `Shared/SharedStorageService.swift`
- `Shared/SharedJokeOfTheDay.swift`
- Used by both main app and widget

## Build & Configuration Files

### Entitlements
`/MrFunnyJokes/MrFunnyJokes/MrFunnyJokes.entitlements`
```xml
<key>com.apple.security.application-groups</key>
<array>
  <string>group.com.bvanaski.mrfunnyjokes</string>
</array>
```

### Info.plist
`/MrFunnyJokes/MrFunnyJokes/Info.plist`
- Privacy info
- Version and build number
- Supported device types

### GoogleService-Info.plist
`/MrFunnyJokes/MrFunnyJokes/GoogleService-Info.plist`
- Firebase project configuration
- API keys (not committed to git)

## Asset Organization

### Colors
- **Primary:** accessibleYellow
- **Character Colors:** red (Mr. Bad), blue (Mr. Sad), pink (Mr. Love), brown (Mr. Potty)
- **Background Colors:** Variants per character with light/dark modes

### Character Images
- MrFunny.imageset
- MrBad.imageset
- MrLove.imageset
- MrPotty.imageset
- MrSad.imageset
- Brian.imageset (app creator)

### App Icon
- AppIcon.appiconset (multiple sizes)
- LaunchScreen.storyboard

## Code Style Guidelines

### View Structure
```swift
struct MyView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: JokeViewModel
    @State private var showDetail = false

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack {
                // Content
            }
        }
    }

    // MARK: - Helpers
    private var filteredContent: [Joke] {
        // Computed property
    }

    private func handleAction() {
        // Private method
    }
}
```

### ViewModel Structure
```swift
@MainActor
final class MyViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var items: [Item] = []
    @Published var isLoading = false

    // MARK: - Private Properties
    private let service = MyService.shared
    private var task: Task<Void, Never>?

    // MARK: - Public Methods
    func loadItems() async {
        // Implementation
    }

    // MARK: - Private Methods
    private func processData() {
        // Implementation
    }
}
```

### Comments & Documentation
- Use `// MARK: -` for section organization
- Document public methods with doc comments
- Add inline comments for complex logic

## Common Patterns

### Infinite Scroll in Feed
```swift
// In View:
ScrollView {
    LazyVStack {
        ForEach(viewModel.filteredJokes) { joke in
            JokeCardView(joke: joke)
                .onAppear {
                    if shouldLoadMore(joke) {
                        Task { await viewModel.loadMoreJokes() }
                    }
                }
        }
    }
}
```

### Category Filtering
```swift
// In ViewModel:
var filteredJokes: [Joke] {
    guard let category = selectedCategory else {
        return jokes
    }
    return jokes.filter { $0.category == category }
}

// In View:
Menu {
    Button("All") { viewModel.selectCategory(nil) }
    ForEach(JokeCategory.allCases) { category in
        Button(category.rawValue) {
            viewModel.selectCategory(category)
        }
    }
}
```

### Loading States
```swift
// In View:
if viewModel.isInitialLoading {
    SkeletonFeedView()
} else if viewModel.jokes.isEmpty {
    Text("No jokes found")
} else {
    ForEach(viewModel.jokes) { joke in
        JokeCardView(joke: joke)
    }
}
```

### Networking with Error Handling
```swift
// In Service:
func fetchJokes() async throws -> [Joke] {
    let snapshot = try await db.collection("jokes")
        .order(by: "popularity_score", descending: true)
        .limit(to: 20)
        .getDocuments()

    return snapshot.documents.compactMap { doc in
        try? doc.data(as: FirestoreJoke.self).toJoke()
    }
}

// In ViewModel:
Task {
    do {
        isLoading = true
        jokes = try await firestoreService.fetchJokes()
    } catch {
        print("Error fetching jokes: \(error)")
        // Use cached data or show error
    }
    isLoading = false
}
```

## Summary

**Mr. Funny Jokes** follows a clean, scalable structure:
- **MVVM architecture** with clear layer separation
- **Singleton services** for dependency management
- **SwiftUI views** with reactive binding to ViewModels
- **Firestore + UserDefaults** for multi-tier caching
- **Feature-based organization** in Views/ (Skeleton/, WeeklyTopTen/)
- **Consistent naming conventions** and code style
- **Well-documented** with MARK comments and docstrings

To add new features, follow the patterns established for Views, ViewModels, Services, and Models.
