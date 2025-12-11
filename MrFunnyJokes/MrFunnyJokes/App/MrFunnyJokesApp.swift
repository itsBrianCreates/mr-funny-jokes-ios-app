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
    @State private var viewModel: JokeViewModel?
    @State private var showSplash = true
    @State private var splashMinimumTimePassed = false

    /// Minimum time to show splash (reduced for faster perceived startup)
    private let minimumSplashDuration: Double = 1.0

    /// Maximum time to show splash before forcing transition (prevents infinite freeze)
    private let maximumSplashDuration: Double = 5.0

    var body: some View {
        ZStack {
            // Main content - only created after viewModel is initialized
            if let viewModel = viewModel {
                SplashTransitionView(
                    viewModel: viewModel,
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
            // Defer ViewModel creation to next run loop tick
            // This allows splash screen to render first, eliminating white screen
            Task { @MainActor in
                // Small yield to ensure splash is visible before heavy init
                await Task.yield()
                viewModel = JokeViewModel()
                startSplashTimer()
                startMaximumSplashTimer()
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
    @ObservedObject var viewModel: JokeViewModel
    @Binding var showSplash: Bool
    let splashMinimumTimePassed: Bool

    var body: some View {
        MainContentView(viewModel: viewModel)
            .opacity(showSplash ? 0 : 1)
            .onChange(of: viewModel.isInitialLoading) { _, isLoading in
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
        guard splashMinimumTimePassed, !viewModel.isInitialLoading else { return }

        withAnimation(.easeInOut(duration: 0.5)) {
            showSplash = false
        }
    }
}

// MARK: - Main Content View

/// The main app content with tab navigation
/// Separated from ContentView to allow viewModel injection from RootView
struct MainContentView: View {
    @ObservedObject var viewModel: JokeViewModel
    @State private var selectedTab: AppTab = .home
    @State private var navigationPath = NavigationPath()
    @State private var showingSettings = false
    @State private var scrollToJokeOfTheDay = false

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
            // Navigate to home tab when notification is tapped
            selectedTab = .home
            navigationPath = NavigationPath()
            scrollToJokeOfTheDay = true
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    // MARK: - Deep Linking

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "mrfunnyjokes" else { return }

        switch url.host {
        case "home":
            selectedTab = .home
        case "me":
            selectedTab = .me
        case "search":
            selectedTab = .search
        default:
            selectedTab = .home
        }
    }

    // MARK: - Home Tab

    private var headerTitle: String {
        if let category = viewModel.selectedCategory {
            return category.rawValue
        }
        return "All Jokes"
    }

    private var homeTab: some View {
        NavigationStack(path: $navigationPath) {
            JokeFeedView(
                viewModel: viewModel,
                onCharacterTap: { character in
                    navigationPath.append(character)
                }
            )
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
            }
            .navigationDestination(for: JokeCharacter.self) { character in
                CharacterDetailView(character: character)
            }
        }
    }

    private var filterMenu: some View {
        Menu {
            Button {
                viewModel.selectCategory(nil)
            } label: {
                Label("All Jokes", systemImage: "sparkles")
            }

            Divider()

            ForEach(JokeCategory.allCases) { category in
                Button {
                    viewModel.selectCategory(category)
                } label: {
                    Label(category.rawValue, systemImage: category.icon)
                }
            }
        } label: {
            Image(systemName: viewModel.selectedCategory == nil
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
                .font(.title3)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Me Tab

    private var meTab: some View {
        NavigationStack {
            MeView(viewModel: viewModel)
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
        }
    }

    // MARK: - Search Tab

    private var searchTab: some View {
        NavigationStack {
            SearchView(viewModel: viewModel)
                .navigationTitle("Search")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}
