import SwiftUI
import FirebaseCore

@main
struct MrFunnyJokesApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
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

    var body: some View {
        ZStack {
            // Main content - only created after viewModel is initialized
            if let viewModel = viewModel {
                MainContentView(viewModel: viewModel)
                    .opacity(showSplash ? 0 : 1)
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
            }
        }
        .onChange(of: viewModel?.isInitialLoading) { _, isLoading in
            checkTransitionConditions()
        }
    }

    private func startSplashTimer() {
        // Ensure splash shows for minimum duration
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumSplashDuration) {
            splashMinimumTimePassed = true
            checkTransitionConditions()
        }
    }

    private func checkTransitionConditions() {
        // Transition when both conditions are met:
        // 1. Minimum splash duration has passed
        // 2. Initial loading is complete (or viewModel not yet created)
        guard splashMinimumTimePassed, let vm = viewModel, !vm.isInitialLoading else { return }

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
