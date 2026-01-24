# Mr. Funny Jokes - External Integrations & APIs

## Firebase Cloud Platform

### Primary Integration: Cloud Firestore
- **Service Type**: NoSQL Cloud Database
- **Configuration File**: `GoogleService-Info.plist`
- **Project ID**: `mr-funny-jokes`
- **Initialization**: `FirebaseApp.configure()` called in `MrFunnyJokesApp.swift`

#### Collections & Schema

**jokes** - Main content database
```
Fields:
- character: string (mr_funny, mr_potty, mr_bad, mr_love, mr_sad)
- text: string (full joke text)
- type: string (dad_joke, knock_knock, pickup_line)
- tags: array[string] (animals, food, work, school, sports, music, technology, science, health, weather, holidays, family, travel, wordplay, religious)
- sfw: boolean (content safety flag)
- source: string (classic, original, submitted)
- created_at: timestamp (server timestamp)
- updated_at: timestamp (server timestamp)
- likes: integer (like count)
- dislikes: integer (dislike count)
- rating_sum: integer (aggregate ratings)
- rating_count: integer (number of ratings)
- rating_avg: double (average rating)
- popularity_score: double (ranking metric)
```

**characters** - Character personas
```
Fields:
- name: string
- personality: string
- joke_types: array[string]
```

**daily_jokes** - Daily featured joke assignment
```
Document ID Format: YYYY-MM-dd (e.g., "2025-01-24")
Fields:
- joke_id: string (reference to jokes collection)
- created_at: timestamp
```

**rating_events** - User interaction analytics
```
Document ID Format: {deviceId}_{jokeId}_{weekId}
Fields:
- joke_id: string
- rating: integer (1-5)
- device_id: string (anonymous device identifier)
- week_id: string (ISO format: YYYY-Wxx)
- timestamp: timestamp
```

**weekly_rankings** - Top 10 jokes aggregation
```
Document ID Format: YYYY-Wxx (ISO week, e.g., "2025-W04")
Fields:
- week_id: string
- week_start: timestamp
- week_end: timestamp
- hilarious: array[{joke_id, count, rank}] (top 10 most hilarious)
- horrible: array[{joke_id, count, rank}] (top 10 most horrible)
- total_hilarious_ratings: integer
- total_horrible_ratings: integer
- computed_at: timestamp
```

#### Firestore Configuration
- **Caching**: 50MB persistent cache enabled
  - Path: `FirestoreService.swift` line 21-25
  - Strategy: Automatic cache with fallback to server on cache miss
- **Query Strategy**:
  - Force refresh for initial loads: `query.getDocuments(source: .server)`
  - Cache-first for pagination: `query.getDocuments()`
- **Timezone Handling**: Eastern Time (America/New_York) for week/day calculations
- **Pagination**: Cursor-based using `DocumentSnapshot`
- **Batch Limits**: Firestore "in" queries limited to 30 items (handled in `fetchJokes(byIds:)`)

#### Data Operations in Code
- **Service Location**: `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Services/FirestoreService.swift`
- **Models Location**: `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Models/FirestoreModels.swift`

### Firebase Features Enabled
From `GoogleService-Info.plist`:
- **IS_GCM_ENABLED**: true (Google Cloud Messaging for push notifications)
- **IS_SIGNIN_ENABLED**: true (Authentication support)
- **IS_APPINVITE_ENABLED**: true (App invitations)
- **IS_ADS_ENABLED**: false (No ad serving)
- **IS_ANALYTICS_ENABLED**: false (Analytics disabled)

### Storage
- **Storage Bucket**: `mr-funny-jokes.appspot.com`
- **Current Usage**: Not actively used in code (configured but not integrated)

## Local Notification Service

### Apple UserNotifications Framework
- **Service Class**: `NotificationManager.swift`
- **Location**: `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Services/NotificationManager.swift`
- **Notification ID**: `jokeOfTheDayNotification`

#### Features
- Daily "Joke of the Day" local push notifications
- Configurable time: Default 9:00 AM (stored in UserDefaults)
- User authorization tracking and sync
- Auto-reschedule on app update
- Permission request on first use
- Responds to app lifecycle events (didBecomeActive)

#### Integration Points
- Initialized in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
- Called from `MrFunnyJokesApp.swift` line 28
- Notification handler setup: `UNUserNotificationCenter.current().delegate = NotificationManager.shared`

## Network Connectivity

### Apple Network Framework
- **Service Class**: `NetworkMonitor.swift`
- **Location**: `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Services/NetworkMonitor.swift`
- **Pattern**: Singleton with @Published property for reactive updates
- **Monitor Type**: `NWPathMonitor` with dispatch queue

#### Functionality
- Real-time connectivity status
- Provides boolean `isConnected` property
- Updates UI reactively via ObservableObject pattern
- Used to handle offline scenarios gracefully

## Deep Linking

### Custom URL Scheme
- **Scheme**: `mrfunnyjokes://`
- **Supported Hosts**:
  - `mrfunnyjokes://home` - Navigate to home tab
  - `mrfunnyjokes://me` - Navigate to "My Jokes" tab
  - `mrfunnyjokes://search` - Navigate to search tab
- **Implementation**: `MainContentView.handleDeepLink(_:)` in `MrFunnyJokesApp.swift`
- **URL Handling**: Registered via `Info.plist` CFBundleURLTypes

## Widget Extension

### Widget Framework
- **Target**: JokeOfTheDayWidget
- **Location**: `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/JokeOfTheDayWidget/`
- **Provider**: `JokeOfTheDayProvider.swift`
- **Data Source**: `SharedStorageService.swift` (App Group shared container)
- **Refresh Policy**: Once daily at midnight
- **Views**: `JokeOfTheDayWidgetViews.swift`

#### Data Synchronization
- **Mechanism**: App Groups container for cross-target data sharing
- **Shared Model**: `SharedJokeOfTheDay.swift`
- **Storage Service**: `SharedStorageService.swift`
- **Update Trigger**: Main app updates widget cache when Joke of the Day changes

## Analytics & Monitoring

### Not Currently Integrated
- Firebase Analytics: Disabled (IS_ANALYTICS_ENABLED: false)
- Third-party crash reporting: Not configured
- User tracking: Not implemented
- Event logging: Custom rating events tracked in Firestore only

### Potential Integration Points
- Rating events stored in `rating_events` collection for future analysis
- Weekly rankings computed and stored for metrics/trending

## External Content

### YouTube Promotion
- **Component**: `YouTubePromoCardView.swift`
- **Integration**: Not fully detailed in code (appears to be UI placeholder/promo)
- **Location**: `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/MrFunnyJokes/MrFunnyJokes/Views/YouTubePromoCardView.swift`

## Backend Scripts

### Joke Management
- **Script Location**: `/Users/brianvanaski/Documents/Code/mr-funny-jokes-ios-app/scripts/add-jokes.js`
- **Runtime**: Node.js
- **Purpose**: Batch add/update jokes to Firestore with duplicate checking
- **Authentication**: Firebase Admin SDK (requires `serviceAccountKey.json`)
- **Operations**:
  - Batch write (max 500 documents per batch)
  - Duplicate detection
  - Dry-run capability
  - Force override option

## Security & Configuration

### Firebase Security Rules
- **Type**: Not included in repository (server-side configuration)
- **Assumption**: Database rules configured in Firebase Console
- **Likely Controls**:
  - Read: Public or authenticated users
  - Write: Admin only (through service account)
  - Update: Restricted to rating fields and like/dislike counters

### API Keys & Credentials
- **Service Account Key**: `scripts/serviceAccountKey.json` (in .gitignore)
- **Firebase Config**: `GoogleService-Info.plist` (contains non-secret project config)
- **No hardcoded secrets**: API keys and GCM IDs use Firebase-provided values

## Data Flow Architecture

### Read Path (User App)
1. User opens app or navigates to section
2. `JokeViewModel` or specific ViewModel calls `FirestoreService`
3. Service queries Firestore (with cache-first strategy)
4. Models decoded from Firestore via Codable
5. Views reactively update via SwiftUI bindings

### Write Path (User Interactions)
1. User rates, likes, or dislikes a joke
2. ViewModel calls `FirestoreService.updateJokeRating()` or `.updateJokeLike()`
3. Firestore transaction/update is performed atomically
4. UI updates optimistically or waits for confirmation

### Notification Flow
1. App startup: `AppDelegate` checks notification authorization
2. User enables notifications in settings
3. `NotificationManager.scheduleJokeOfTheDayNotification()` schedules local notification
4. System delivers notification at scheduled time
5. App handles notification tap via NotificationCenter publisher

### Widget Flow
1. App fetches Joke of the Day from Firestore
2. Data stored in App Group shared container
3. Widget provider reads from shared container
4. Widget timeline refreshes at midnight
5. Widget displays current Joke of the Day to user
