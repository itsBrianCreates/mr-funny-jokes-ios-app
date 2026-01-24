# Mr. Funny Jokes - Technology Stack

## Platform & Runtime
- **Platform**: iOS
- **Minimum Deployment Target**: iOS 18.0
- **Language**: Swift (primary)
- **UI Framework**: SwiftUI

## Core Frameworks & Libraries

### Apple Native Frameworks
- **SwiftUI**: Modern declarative UI framework
- **UIKit**: Foundation for app lifecycle and system integration
- **WidgetKit**: For "Joke of the Day" lock screen and home screen widgets
- **UserNotifications**: Local push notifications for daily joke reminders
- **Network**: Network connectivity monitoring via `NWPathMonitor`
- **Foundation**: Core data types and utilities

## Third-Party Dependencies

### Firebase (Backend-as-a-Service)
- **FirebaseCore**: Foundation SDK initialization
- **FirebaseFirestore**: Cloud database for jokes, characters, ratings, and weekly rankings
  - Collection: `jokes` - Main joke documents with character, type, tags, ratings
  - Collection: `characters` - Character metadata and personality
  - Collection: `daily_jokes` - Daily joke assignment
  - Collection: `weekly_rankings` - Top 10 jokes aggregation
  - Collection: `rating_events` - User rating events for analytics
  - Caching: 50MB persistent cache enabled for offline performance

### Configuration Files
- **GoogleService-Info.plist**: Firebase project configuration
  - Project ID: `mr-funny-jokes`
  - Bundle ID: `com.bvanaski.MrFunnyJokes`
  - Storage Bucket: `mr-funny-jokes.appspot.com`
  - Firebase Features Enabled: GCM, Sign-in, App Invites

## Architecture & Patterns

### MVVM (Model-View-ViewModel)
- **Models**:
  - `Joke.swift` - App representation of a joke
  - `FirestoreModels.swift` - Firestore-specific models (FirestoreJoke, FirestoreCharacter, WeeklyRankings)
  - `JokeCategory.swift` - Joke type enumeration (dadJoke, knockKnock, pickupLine)
  - `Character.swift` - Character persona model

- **ViewModels**:
  - `JokeViewModel.swift` - Main joke feed and filtering logic
  - `CharacterDetailViewModel.swift` - Character-specific joke loading
  - `WeeklyRankingsViewModel.swift` - Top 10 weekly jokes

- **Views**:
  - SwiftUI view hierarchy with tab-based navigation
  - Skeleton loading screens with shimmer animations
  - Character carousel and detail views
  - Search and filtering interface

### Services Layer
- **FirestoreService.swift** - Data access layer for Firestore operations
  - Pagination with cursor-based navigation
  - Search functionality (client-side filtering)
  - Rating and like/dislike updates
  - Weekly ranking aggregation
  - Caching strategy for performance

- **NotificationManager.swift** - Local push notification scheduling
  - UserDefaults-based preferences persistence
  - Configurable daily notification time
  - Authorization status tracking

- **NetworkMonitor.swift** - Real-time connectivity monitoring
  - Observes network path changes
  - Provides isConnected/@Published state

- **LocalStorageService.swift** - Local data persistence
- **SharedStorageService.swift** - App Group shared data for widgets

## Build Configuration
- **Xcode Build System**: Modern build system
- **Deployment Target**: iOS 18.0
- **Swift Version**: Swift 5.x
- **Code Signing**: Required for iOS app deployment

## Data Persistence
- **UserDefaults**: Notification preferences, user settings
- **Firestore Persistent Cache**: 50MB local cache for offline access
- **App Groups**: Shared container for widget data synchronization (via `SharedStorageService`)

## Key Technical Features

### Performance Optimizations
- Lazy view initialization to prevent white screen startup
- Persistent cache for faster loads on subsequent launches
- Skeleton loading states during data fetch
- Pagination with cursor-based Firestore queries
- Batch processing for data fetching (max 30 items per "in" query)

### Accessibility & UX
- Dark mode support via SwiftUI colors
- Haptic feedback (HapticManager.swift)
- Native iOS navigation patterns (NavigationStack)
- Tab-based navigation with deep linking support
- Search functionality with text filtering
- Rating/ranking UI with visual feedback

### Widget Support
- **JokeOfTheDayWidget**: Home screen and lock screen widget
- **Timeline Provider**: Daily refresh at midnight
- **Shared Storage**: Data synchronization between app and widget via App Groups

## External Service Integrations
See `INTEGRATIONS.md` for detailed integration information.
