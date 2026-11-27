import SwiftUI
import FirebaseCore
import UserNotifications

@main
struct MrFunnyJokesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared

        // Check current authorization status
        NotificationManager.shared.checkAuthorizationStatus()

        // Re-schedule notifications if enabled (in case app was updated)
        if NotificationManager.shared.notificationsEnabled {
            NotificationManager.shared.scheduleJokeOfTheDayNotification()
        }

        return true
    }
}

// MARK: - Root View

/// Manages the transition from splash screen to main content
/// Coordinates background loading during splash for a snappier experience
struct RootView: View {
    /// ViewModel is created lazily AFTER splash screen renders to avoid blocking the main thread
    @State private var jokeViewModel: JokeViewModel?
    @State private var showSplash = true
    @State private var splashMinimumTimePassed = false

    /// Minimum time to show splash (reduced for faster perceived startup)
    private let minimumSplashDuration: Double = 1.0

    /// Maximum time to show splash before forcing transition (prevents infinite freeze).
    /// A safety net only: `JokeViewModel` stops waiting on the network 1.5s after launch.
    private let maximumSplashDuration: Double = 3.0

    var body: some View {
        ZStack {
            // Main content - only created after viewModel is initialized
            if let jokeViewModel = jokeViewModel {
                SplashTransitionView(
                    jokeViewModel: jokeViewModel,
                    showSplash: $showSplash,
                    splashMinimumTimePassed: splashMinimumTimePassed
                )
            }

            // Splash screen overlay
            if showSplash {
                SplashScreenView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .zIndex(1)
            }
        }
        .onAppear {
            startSplashTimer()
            startMaximumSplashTimer()
            #if DEBUG
            ShareCardDebugRenderer.renderIfRequested()
            #endif
            // Pre-warm haptic engines on a background thread
            Task.detached { HapticManager.shared.warmUp() }
            // Defer ViewModel creation so the animated splash renders first.
            // JokeViewModel() triggers FirestoreService.shared init which is heavy
            // on first launch — this keeps it off the initial render path.
            DispatchQueue.main.async {
                jokeViewModel = JokeViewModel()
            }
        }
    }

    private func startSplashTimer() {
        // Ensure splash shows for minimum duration
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumSplashDuration) {
            splashMinimumTimePassed = true
        }
    }

    private func startMaximumSplashTimer() {
        // Fallback: Force transition after maximum duration to prevent infinite freeze
        DispatchQueue.main.asyncAfter(deadline: .now() + maximumSplashDuration) {
            guard showSplash else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                showSplash = false
            }
        }
    }
}

/// Helper view that properly observes the viewModel using @ObservedObject
/// This ensures SwiftUI receives updates when isInitialLoading changes
private struct SplashTransitionView: View {
    @ObservedObject var jokeViewModel: JokeViewModel
    @Binding var showSplash: Bool
    let splashMinimumTimePassed: Bool

    var body: some View {
        MainContentView(jokeViewModel: jokeViewModel)
            .opacity(showSplash ? 0 : 1)
            .onChange(of: jokeViewModel.isInitialLoading) { _, isLoading in
                checkTransitionConditions()
            }
            .onChange(of: splashMinimumTimePassed) { _, _ in
                checkTransitionConditions()
            }
            .onAppear {
                // Check immediately in case loading already finished
                checkTransitionConditions()
            }
    }

    private func checkTransitionConditions() {
        // Transition when both conditions are met:
        // 1. Minimum splash duration has passed
        // 2. Initial loading is complete
        guard splashMinimumTimePassed, !jokeViewModel.isInitialLoading else { return }

        withAnimation(.easeInOut(duration: 0.5)) {
            showSplash = false
        }
    }
}

// MARK: - Main Content View

/// The main app content with tab navigation
/// Separated from ContentView to allow viewModel injection from RootView
struct MainContentView: View {
    @ObservedObject var jokeViewModel: JokeViewModel
    @State private var selectedTab: AppTab = .home
    @State private var navigationPath = NavigationPath()
    @State private var meNavigationPath = NavigationPath()
    @State private var searchNavigationPath = NavigationPath()
    @State private var showingSettings = false
    @State private var scrollToJokeOfTheDay = false
    /// The joke shown full screen: the Joke of the Day (card, widget, notification)
    /// or a joke opened from a shared link
    @State private var fullScreenJoke: FullScreenJoke?
    @State private var windowWidth: CGFloat = 0

    @Environment(\.colorScheme) private var colorScheme

    enum AppTab: Hashable {
        case home
        case me
        case search
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                homeTab
            }

            Tab("Me", systemImage: "person.fill", value: .me) {
                meTab
            }

            Tab(value: .search, role: .search) {
                searchTab
            }
        }
        .tint(.accessibleYellow)
        .reviewPrompt()
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onAppear {
            // Clear navigation state on app launch to prevent returning to
            // a frozen screen after force-close. SwiftUI's state restoration
            // can preserve navigationPath, so we reset it to ensure users
            // always start at the home screen.
            navigationPath = NavigationPath()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didTapJokeOfTheDayNotification)) { _ in
            // The daily notification opens today's joke full screen, over Home
            selectedTab = .home
            navigationPath = NavigationPath()
            scrollToJokeOfTheDay = true
            presentJokeOfTheDay()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .fullScreenCover(item: $fullScreenJoke) { presented in
            JokeFullScreenView(
                viewModel: jokeViewModel,
                openedJoke: presented.joke,
                isJokeOfTheDay: presented.isJokeOfTheDay,
                list: presented.list,
                isDark: colorScheme == .dark
            )
        }
        .environment(\.openFullScreenJoke, OpenFullScreenJokeAction { joke, isJokeOfTheDay, list in
            fullScreenJoke = FullScreenJoke(joke: joke, isJokeOfTheDay: isJokeOfTheDay, list: list)
        })
        // Sheets presented from here open joke pages on Home.
        // Each tab's stack replaces this with its own.
        .environment(\.openJokes, OpenJokesAction { destination in
            selectedTab = .home
            navigationPath.append(destination)
        })
        .environment(\.topicJokeCounts, topicJokeCounts)
        // Outermost so every tab, pushed screen and sheet sees it
        .environment(\.isWideLayout, windowWidth >= AdaptiveLayout.wideMinWidth)
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { width in
            windowWidth = width
        }
    }

    // MARK: - Topics

    /// Joke counts for the topics that have a page, for "More like this" chips
    private var topicJokeCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for entry in JokeTopic.browsable(in: jokeViewModel.jokes) {
            counts[entry.topic.id] = entry.count
        }
        return counts
    }

    // MARK: - Deep Linking

    private func handleDeepLink(_ url: URL) {
        // Universal Link from a shared joke: https://mrfunnyjokes.app/j/<jokeId>
        if url.scheme == "https" || url.scheme == "http" {
            let parts = url.pathComponents.filter { $0 != "/" }
            if url.host?.hasSuffix("mrfunnyjokes.app") == true, parts.count == 2, parts[0] == "j" {
                openSharedJoke(id: parts[1])
            } else {
                selectedTab = .home
            }
            return
        }

        guard url.scheme == "mrfunnyjokes" else { return }

        switch url.host {
        case "jotd":
            // Widget tap: Home, with today's joke full screen
            selectedTab = .home
            presentJokeOfTheDay()
        case "joke":
            // mrfunnyjokes://joke/<jokeId>: the same joke page a shared link opens
            if let id = url.pathComponents.dropFirst().first {
                openSharedJoke(id: id)
            } else {
                selectedTab = .home
            }
        case "home":
            selectedTab = .home
        case "me":
            selectedTab = .me
        case "search":
            selectedTab = .search
        case "topic":
            // mrfunnyjokes://topic/<topicId>: the topic's page on the Search tab,
            // as if it had been tapped in Browse. An unknown ID just opens Search.
            selectedTab = .search
            let topicId = url.pathComponents.dropFirst().first
            if let topic = JokeTopic.all.first(where: { $0.id == topicId }) {
                AnalyticsService.shared.logTopicSelected(topicId: topic.id, source: "deep_link")
                // Replaces the path, so opening links twice doesn't stack pages
                searchNavigationPath = NavigationPath([JokeDestination.topic(topic)])
            }
        default:
            selectedTab = .home
        }
    }

    /// Shows today's joke full screen. On a cold launch (widget, notification) the
    /// joke may still be loading, so this waits a moment for it.
    private func presentJokeOfTheDay() {
        Task { @MainActor in
            for _ in 0..<30 {
                if let joke = jokeViewModel.jokeOfTheDay, !jokeViewModel.isLoadingJokeOfTheDay {
                    fullScreenJoke = FullScreenJoke(joke: joke, isJokeOfTheDay: true)
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            if let joke = jokeViewModel.jokeOfTheDay {
                fullScreenJoke = FullScreenJoke(joke: joke, isJokeOfTheDay: true)
            }
        }
    }

    /// Opens the joke a shared link points at, full screen. An unknown ID opens Home.
    private func openSharedJoke(id: String) {
        selectedTab = .home
        AnalyticsService.shared.logShareLinkOpened(jokeId: id)
        Task { @MainActor in
            guard let joke = await jokeViewModel.jokeForLink(firestoreId: id) else { return }
            fullScreenJoke = FullScreenJoke(
                joke: joke,
                isJokeOfTheDay: joke.firestoreId == jokeViewModel.jokeOfTheDay?.firestoreId
            )
        }
    }

    // MARK: - Home Tab

    private var headerTitle: String {
        if let category = jokeViewModel.selectedCategory {
            return category.rawValue
        }
        return "All Jokes"
    }

    private var homeTab: some View {
        NavigationStack(path: $navigationPath) {
            JokeFeedView(
                viewModel: jokeViewModel,
                onCharacterTap: { character in
                    AnalyticsService.shared.logCharacterSelected(characterId: character.id)
                    navigationPath.append(character)
                }
            )
            .navigationTitle(headerTitle)
            // Small and in the bar: it only says which joke type is showing, and a
            // large title pushed the characters and the joke of the day down
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .navigationDestination(for: JokeCharacter.self) { character in
                CharacterDetailView(character: character)
            }
            .jokeDestinations(viewModel: jokeViewModel)
        }
        .environment(\.openJokes, OpenJokesAction { navigationPath.append($0) })
    }

    private var filterMenu: some View {
        Menu {
            Button {
                jokeViewModel.selectCategory(nil)
            } label: {
                Label("All Jokes", systemImage: "sparkles")
            }

            Divider()

            ForEach(JokeCategory.allCases) { category in
                Button {
                    jokeViewModel.selectCategory(category)
                } label: {
                    Label(category.rawValue, systemImage: category.icon)
                }
            }
        } label: {
            Image(systemName: jokeViewModel.selectedCategory == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
                .font(.title3)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Me Tab

    private var meTab: some View {
        NavigationStack(path: $meNavigationPath) {
            MeView(viewModel: jokeViewModel)
                .navigationTitle("My Jokes")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .jokeDestinations(viewModel: jokeViewModel)
        }
        .environment(\.openJokes, OpenJokesAction { meNavigationPath.append($0) })
    }

    // MARK: - Search Tab

    private var searchTab: some View {
        NavigationStack(path: $searchNavigationPath) {
            SearchView(viewModel: jokeViewModel)
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.large)
                .jokeDestinations(viewModel: jokeViewModel)
        }
        .environment(\.openJokes, OpenJokesAction { searchNavigationPath.append($0) })
    }
}
