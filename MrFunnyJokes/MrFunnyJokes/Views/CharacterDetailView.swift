import SwiftUI

/// Detail view for a character, showing their bio and jokes
/// Inspired by Apple Fitness+ trainer detail page
struct CharacterDetailView: View {
    @StateObject private var viewModel: CharacterDetailViewModel
    @Environment(\.dismiss) private var dismiss

    let character: JokeCharacter

    init(character: JokeCharacter) {
        self.character = character
        self._viewModel = StateObject(wrappedValue: CharacterDetailViewModel(character: character))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Hero section with character info
                heroSection

                // Filter and jokes section
                jokesSection
            }
        }
        .background(
            // Full-bleed gradient background
            LinearGradient(
                colors: [
                    character.color.opacity(0.3),
                    character.color.opacity(0.15),
                    character.color.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.4)
            )
            .ignoresSafeArea()
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadJokes()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 0) {
            // Character icon/image area
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(character.color.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Image(systemName: character.sfSymbol)
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(character.color)
                }
                .overlay(
                    Circle()
                        .strokeBorder(character.color.opacity(0.4), lineWidth: 3)
                )
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
            .frame(height: 200)

            // Character name and bio
            VStack(alignment: .leading, spacing: 16) {
                // Name
                Text(character.fullName)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                // Bio
                Text(character.bio)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Jokes Section

    private var jokesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with filter (only show filter if character has multiple categories)
            HStack {
                Text(character.id == "mr_love" ? "Pick up lines" : "Jokes")
                    .font(.title2.weight(.bold))

                Spacer()

                // Only show filter button if character has multiple categories
                if character.hasMultipleCategories {
                    filterMenu
                }
            }
            .padding(.horizontal, 20)

            // Jokes list
            if viewModel.isLoading && viewModel.jokes.isEmpty {
                // Loading state
                loadingView
            } else if viewModel.jokes.isEmpty {
                // Empty state
                emptyStateView
            } else {
                // Jokes list
                jokesList
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            Button {
                viewModel.selectJokeType(nil)
            } label: {
                HStack {
                    Text("All Types")
                    if viewModel.selectedJokeType == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            if !viewModel.availableJokeTypes.isEmpty {
                Divider()

                ForEach(viewModel.availableJokeTypes) { category in
                    Button {
                        viewModel.selectJokeType(category)
                    } label: {
                        HStack {
                            Label(category.rawValue, systemImage: category.icon)
                            if viewModel.selectedJokeType == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                Text("Filter")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(character.color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(character.color.opacity(0.15), in: Capsule())
        }
    }

    // MARK: - Jokes List

    private var jokesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredJokes) { joke in
                CharacterJokeCardView(
                    joke: joke,
                    isCopied: viewModel.copiedJokeId == joke.id,
                    onShare: { viewModel.shareJoke(joke) },
                    onCopy: { viewModel.copyJoke(joke) },
                    onRate: { rating in viewModel.rateJoke(joke, rating: rating) }
                )
                .onAppear {
                    viewModel.loadMoreIfNeeded(currentItem: joke)
                }
            }

            // Loading more indicator
            if viewModel.isLoadingMore {
                ProgressView()
                    .padding(.vertical, 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonCardView(lineCount: 2, lastLineWidth: 0.7)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.bubble")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No jokes yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("\(character.name) is working on some new material!")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 20)
    }
}

// MARK: - Character Joke Card View

/// A simplified joke card for the character detail view
/// Shows only category (not character) since character context is established
struct CharacterJokeCardView: View {
    let joke: Joke
    let isCopied: Bool
    let onShare: () -> Void
    let onCopy: () -> Void
    let onRate: (Int) -> Void

    @State private var showingSheet = false

    var body: some View {
        Button {
            HapticManager.shared.mediumImpact()
            showingSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Setup text
                Text(joke.setup)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Category and rating row
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: joke.category.icon)
                        Text(joke.category.rawValue)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    if let rating = joke.userRating {
                        CompactGroanOMeterView(rating: rating)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSheet) {
            JokeDetailSheet(
                joke: joke,
                isCopied: isCopied,
                onDismiss: { showingSheet = false },
                onShare: onShare,
                onCopy: onCopy,
                onRate: onRate
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CharacterDetailView(character: .mrFunny)
    }
}
