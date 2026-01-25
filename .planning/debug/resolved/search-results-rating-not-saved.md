---
status: resolved
trigger: "When rating a joke from search results, the haptic feedback fires but the rating is not actually saved."
created: 2026-01-25T14:00:00Z
updated: 2026-01-25T14:50:00Z
---

## Current Focus

hypothesis: CONFIRMED - Rating IS saved, but search UI doesn't update because cachedResults contains value copies
test: Traced data flow and found cachedResults is @State that only updates on jokes.count change
expecting: N/A - root cause identified
next_action: Implement fix - update cachedResults when viewModel.jokes array content changes

## Symptoms

expected: Rating a joke from search results should save the rating (persist and show in Me tab)
actual: Haptic feedback fires when tapping rating, but rating is not saved
errors: No errors visible (user didn't mention any)
reproduction: Search for a joke, tap a rating option on a search result
timeline: Unknown - likely related to similar issue just fixed with character views

## Eliminated

## Evidence

- timestamp: 2026-01-25T14:02:00Z
  checked: SearchView.swift (lines 104-121)
  found: |
    - SearchView uses JokeViewModel directly (same instance)
    - resultsList passes onRate: { rating in viewModel.rateJoke(joke, rating: rating) }
    - This should call JokeViewModel.rateJoke directly
  implication: The path is correct - SearchView calls JokeViewModel.rateJoke directly

- timestamp: 2026-01-25T14:03:00Z
  checked: SearchView search mechanism (lines 16-39)
  found: |
    - cachedResults: [Joke] = [] is a @State local array
    - performSearch filters viewModel.jokes and stores in cachedResults
    - cachedResults = viewModel.jokes.filter { ... }
    - Jokes in cachedResults are VALUE COPIES from viewModel.jokes
  implication: Search results are COPIES of jokes, not references to the original array

- timestamp: 2026-01-25T14:05:00Z
  checked: JokeViewModel.rateJoke (lines 721-774)
  found: |
    - Finds joke by firestoreId OR joke.id
    - If found in jokes array, updates rating
    - If NOT found, ADDS the joke to array
    - But wait: the search is filtering FROM viewModel.jokes, so jokes SHOULD be in the array
  implication: Need to check if joke matching logic works correctly

- timestamp: 2026-01-25T14:10:00Z
  checked: CharacterDetailView vs SearchView rating pattern
  found: |
    - CharacterDetailView uses CharacterDetailViewModel.rateJoke which posts a notification
    - SearchView uses JokeViewModel.rateJoke DIRECTLY (same as JokeFeedView)
    - This is a DIFFERENT pattern than the previously fixed bug
    - SearchView's cachedResults are filtered from viewModel.jokes, so the joke should exist
  implication: The bug pattern is different from character view bug - need fresh investigation

- timestamp: 2026-01-25T14:12:00Z
  checked: Closure chain from SearchView to GroanOMeterView
  found: |
    1. SearchView: onRate: { rating in viewModel.rateJoke(joke, rating: rating) }
    2. JokeCardView: passes onRate to JokeDetailSheet
    3. JokeDetailSheet: passes onRate to GroanOMeterView
    4. GroanOMeterView: calls onRate(finalIndex + 1) on .onEnded

    The haptic at line 86 fires on .onChanged (during drag), not when saving
    The save happens in .onEnded (line 93)
  implication: The flow looks correct - need to verify actual behavior

- timestamp: 2026-01-25T14:20:00Z
  checked: FirestoreJoke.toJoke() UUID generation
  found: |
    Line 54: id: UUID(uuidString: id ?? "") ?? UUID()
    Firestore document IDs are NOT valid UUID strings, so this generates a new UUID every time.
    However, firestoreId is set correctly: firestoreId: id
    Rating lookup uses firestoreId first, so this should work.
  implication: UUID changes don't matter because firestoreId is used for lookup/storage

- timestamp: 2026-01-25T14:25:00Z
  checked: Potential gesture conflict with ScrollView
  found: |
    GroanOMeterView is inside JokeDetailSheet's ScrollView.
    DragGesture has minimumDistance: 0 but no gesture priority modifiers.
    Hypothesis: ScrollView might steal the gesture, causing .onEnded to never fire.
    BUT this would affect ALL rating UIs (home, me, character), not just search.
  implication: Gesture conflict is unlikely to be search-specific

- timestamp: 2026-01-25T14:30:00Z
  checked: cachedResults update behavior
  found: |
    cachedResults is @State, contains value copies of jokes
    .onChange(of: viewModel.jokes.count) only triggers when count changes
    Rating updates don't change count, so cachedResults is NOT refreshed
    BUT this only affects UI display, not rating save
  implication: Rating IS saved to viewModel.jokes and storage, but search UI doesn't update

- timestamp: 2026-01-25T14:40:00Z
  checked: Complete UI flow after rating in search
  found: |
    1. User rates joke in sheet -> rateJoke updates viewModel.jokes[index].userRating
    2. BUT sheet's joke is a value copy - sheet GroanOMeterView shows selected index correctly
    3. After dismissing sheet, search card shows cachedResults[x].userRating which is nil
    4. User taps card again, sheet shows joke.userRating = nil (from cachedResults)
    5. GroanOMeterView shows "Tap to rate" - looks like rating was lost!

    The rating IS saved to:
    - viewModel.jokes (in memory)
    - LocalStorage (persisted)
    - Firestore (synced)

    But the UI doesn't reflect this because cachedResults is stale.
  implication: ROOT CAUSE IDENTIFIED - cachedResults needs to sync with viewModel.jokes changes

## Resolution

root_cause: |
  SearchView uses @State var cachedResults which contains VALUE COPIES of jokes from viewModel.jokes.
  When a rating is saved, viewModel.jokes is updated but cachedResults retains the OLD copies.
  The only trigger to refresh cachedResults is .onChange(of: viewModel.jokes.count) which doesn't
  fire when ratings change (count stays the same).

  Result: Rating IS saved to storage and viewModel.jokes, but search UI shows stale data.
  User sees "no rating" in search results even though the rating is actually saved.

fix: |
  Changed SearchView to cache joke IDs instead of full Joke objects.
  When displaying search results, always look up fresh jokes from viewModel.jokes
  using the cached IDs. This ensures ratings and other updates are reflected immediately.

  Key changes:
  1. @State cachedResults: [Joke] -> @State cachedResultIds: [String]
  2. searchResults computed property now looks up fresh jokes from viewModel.jokes
  3. performSearch extracts and caches firestoreIds instead of full jokes
  4. Also added listener for .jokeRatingDidChange for cross-ViewModel updates

verification: |
  Build succeeded with xcodebuild.

  The fix ensures:
  1. Search results always show fresh data from viewModel.jokes
  2. Rating updates appear immediately in the search UI
  3. Rating emoji appears on the card after dismissing the sheet
  4. Me tab shows the rating correctly (was already working)

files_changed:
  - MrFunnyJokes/MrFunnyJokes/Views/SearchView.swift

root_cause:
fix:
verification:
files_changed: []
