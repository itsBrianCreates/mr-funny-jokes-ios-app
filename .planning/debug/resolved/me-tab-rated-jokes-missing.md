---
status: resolved
trigger: "Rated jokes from character views are not consistently showing up in the Me tab, but ratings from home view work correctly."
created: 2026-01-25T12:00:00Z
updated: 2026-01-25T12:20:00Z
---

## Current Focus

hypothesis: CONFIRMED - JokeViewModel.handleRatingNotification does not add jokes to array when not found
test: Code comparison between handleRatingNotification and rateJoke
expecting: N/A - root cause confirmed
next_action: Implement fix - include joke object in notification userInfo

## Symptoms

expected: Joke appears in Me tab immediately after rating
actual: Jokes appear inconsistently when rated via star rating from character views
errors: No errors visible in Xcode console
reproduction: Star rating on any joke from any character view - home view ratings work correctly
started: Used to work, now broken at some point

## Eliminated

## Evidence

- timestamp: 2026-01-25T12:05:00Z
  checked: JokeViewModel.handleRatingNotification (lines 214-239)
  found: |
    When notification received:
    1. Looks for joke in jokes array by firestoreId OR jokeId
    2. If found, updates userRating
    3. If NOT found, does NOTHING - joke is not added to array
  implication: Character view jokes not in JokeViewModel.jokes array will never appear in Me tab

- timestamp: 2026-01-25T12:05:00Z
  checked: JokeViewModel.rateJoke (lines 708-761)
  found: |
    When rating directly in home view:
    1. Looks for joke in jokes array
    2. If found, updates userRating
    3. If NOT found, ADDS the joke to array (line 734-738):
       ```
       } else {
           // Joke not in array (e.g., Joke of the Day from cache)
           // Add it to the array so it appears in the Me tab and triggers UI update
           var mutableJoke = joke
           mutableJoke.userRating = clampedRating
           jokes.append(mutableJoke)
       }
       ```
  implication: Home view ratings work because rateJoke adds missing jokes; character view uses notification which doesn't

- timestamp: 2026-01-25T12:05:00Z
  checked: CharacterDetailViewModel.rateJoke (lines 211-268)
  found: |
    1. Saves rating to local storage
    2. Updates CharacterDetailViewModel.jokes array
    3. Posts notification with firestoreId, jokeId, rating
    4. Does NOT include the full joke object in notification
  implication: JokeViewModel receives notification but cannot add joke because it doesn't have the full joke object

- timestamp: 2026-01-25T12:08:00Z
  checked: MeView.swift - how ratedJokes are displayed
  found: |
    MeView uses viewModel.ratedJokes which filters JokeViewModel.jokes where userRating != nil
    The Me tab ONLY shows jokes that are in JokeViewModel.jokes array
    Ratings are saved to LocalStorage, but jokes must also be in the array to appear
  implication: Even though rating is persisted in storage, if joke is not in JokeViewModel.jokes, it won't appear in Me tab

- timestamp: 2026-01-25T12:08:00Z
  checked: CharacterDetailViewModel vs JokeViewModel joke arrays
  found: |
    - CharacterDetailViewModel.jokes contains character-specific jokes from Firestore
    - JokeViewModel.jokes contains home feed jokes (different subset from Firestore)
    - These are separate arrays with potentially non-overlapping jokes
  implication: Jokes rated in character view are in CharacterDetailViewModel.jokes but may not be in JokeViewModel.jokes

## Resolution

root_cause: |
  JokeViewModel.handleRatingNotification (line 214-239) only updates userRating if the joke
  is ALREADY in JokeViewModel.jokes array. If the joke is not found, it does nothing.

  In contrast, JokeViewModel.rateJoke (line 732-739) has logic to ADD the joke to the array
  if it's not found:
  ```swift
  } else {
      // Joke not in array (e.g., Joke of the Day from cache)
      // Add it to the array so it appears in the Me tab and triggers UI update
      var mutableJoke = joke
      mutableJoke.userRating = clampedRating
      jokes.append(mutableJoke)
  }
  ```

  This is why home view ratings work (uses rateJoke directly) but character view ratings don't
  appear in Me tab (uses notification which lacks the add-joke behavior AND the joke object).

  The notification from CharacterDetailViewModel only contains firestoreId, jokeId, and rating -
  not the full Joke object, so handleRatingNotification cannot add the joke even if it wanted to.

fix: |
  1. Include the full Joke object in the notification userInfo from CharacterDetailViewModel
  2. Update JokeViewModel.handleRatingNotification to add the joke to the array when not found
     (similar to rateJoke behavior)

verification: |
  1. Build succeeded with xcodebuild
  2. Fix implements the same pattern as JokeViewModel.rateJoke for handling missing jokes
  3. Notification now includes full joke data via JSON encoding
  4. handleRatingNotification now adds jokes to array when not found (matching rateJoke behavior)

files_changed:
  - MrFunnyJokes/MrFunnyJokes/ViewModels/CharacterDetailViewModel.swift
  - MrFunnyJokes/MrFunnyJokes/ViewModels/JokeViewModel.swift
