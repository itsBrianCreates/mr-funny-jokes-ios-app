import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = JokeViewModel()
    @State private var selectedTab: AppTab = .home

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
        NavigationStack {
            ZStack {
                // Skeleton loading view - shown during initial load
                if viewModel.isInitialLoading {
                    SkeletonFeedView()
                        .transition(.opacity)
                }

                // Actual content - shown after loading completes
                if !viewModel.isInitialLoading {
                    JokeFeedView(viewModel: viewModel)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: viewModel.isInitialLoading)
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    filterMenu
                }
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

#Preview {
    ContentView()
}
