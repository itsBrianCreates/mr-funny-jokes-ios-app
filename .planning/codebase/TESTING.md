# Testing Framework & Patterns

Mr. Funny Jokes iOS app currently has no test files implemented. This document outlines the testing approach needed to establish comprehensive test coverage.

## Current Status

**Testing Framework:** None implemented
**Test Files:** 0
**Coverage:** 0%

**Search Results:**
- No XCTest files found
- No test targets in Xcode project
- No mock objects implemented
- No test utilities or fixtures

## Recommended Testing Architecture

### Framework Selection

**Primary Framework: XCTest** (Apple's native framework)
- Included with Xcode
- Supports unit tests, UI tests, performance tests
- Integration with GitHub Actions/CI-CD

**Additional Tools:**
- **Combine Publishers Testing**: `XCTestDynamicOverlay` (Swift Testing alternative)
- **Async/Await Support**: Use `async` test methods (Xcode 13+)

### Test Organization Structure

```
MrFunnyJokesTests/
├── Models/
│   ├── JokeTests.swift
│   ├── JokeCategoryTests.swift
│   └── JokeCharacterTests.swift
├── ViewModels/
│   ├── JokeViewModelTests.swift
│   ├── CharacterDetailViewModelTests.swift
│   └── WeeklyRankingsViewModelTests.swift
├── Services/
│   ├── FirestoreServiceTests.swift
│   ├── LocalStorageServiceTests.swift
│   └── NetworkMonitorTests.swift
├── Mocks/
│   ├── MockFirestoreService.swift
│   ├── MockLocalStorageService.swift
│   └── MockNetworkMonitor.swift
└── Fixtures/
    ├── JokeFixtures.swift
    └── TestData.swift
```

## Unit Testing Strategy

### Model Tests

**File Pattern:** `Models/*Tests.swift`

Example test structure for `Joke.swift`:

```swift
import XCTest
@testable import MrFunnyJokes

final class JokeTests: XCTestCase {

    // MARK: - Encoding/Decoding

    func testJokeDecodingWithAllFields() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "category": "Dad Jokes",
            "setup": "Why did the scarecrow win?",
            "punchline": "He was outstanding in his field!",
            "userRating": 5,
            "firestoreId": "abc123",
            "character": "mr_funny",
            "tags": ["wordplay", "work"],
            "sfw": true,
            "source": "classic",
            "ratingCount": 42,
            "ratingAvg": 4.5,
            "likes": 100,
            "dislikes": 5,
            "popularityScore": 95.5
        }
        """.data(using: .utf8)!

        let joke = try JSONDecoder().decode(Joke.self, from: json)
        XCTAssertEqual(joke.setup, "Why did the scarecrow win?")
        XCTAssertEqual(joke.userRating, 5)
        XCTAssertEqual(joke.character, "mr_funny")
    }

    func testJokeDecodingWithMissingOptionalFields() throws {
        // Test backward compatibility
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "category": "Dad Jokes",
            "setup": "Why?",
            "punchline": "Because!"
        }
        """.data(using: .utf8)!

        let joke = try JSONDecoder().decode(Joke.self, from: json)
        XCTAssertNil(joke.userRating)
        XCTAssertNil(joke.character)
        XCTAssertEqual(joke.sfw, true)  // Default
        XCTAssertEqual(joke.ratingCount, 0)  // Default
    }

    // MARK: - Formatting

    func testFormattedTextForSharingRegularJoke() {
        let joke = Joke(
            id: UUID(),
            category: .dadJoke,
            setup: "Why did the chicken cross?",
            punchline: "To get to the other side!",
            character: "mr_funny"
        )

        let formatted = joke.formattedTextForSharing(characterName: "Mr. Funny")
        XCTAssertTrue(formatted.contains("Why did the chicken cross?"))
        XCTAssertTrue(formatted.contains("To get to the other side!"))
        XCTAssertTrue(formatted.contains("Mr. Funny"))
    }

    func testFormattedTextForSharingKnockKnockJoke() {
        let joke = Joke(
            id: UUID(),
            category: .knockKnock,
            setup: "Knock, knock. Who's there? Nobel.",
            punchline: "Nobel who? Nobel... that's why I knocked.",
            character: "mr_funny"
        )

        let formatted = joke.formattedTextForSharing(characterName: "Mr. Funny")
        XCTAssertTrue(formatted.contains("Knock, knock."))
        XCTAssertTrue(formatted.contains("Who's there?"))
        XCTAssertTrue(formatted.contains("Nobel"))
    }

    // MARK: - Rating Emoji

    func testRatingEmojiMapping() {
        var joke = Joke(
            id: UUID(),
            category: .dadJoke,
            setup: "Test",
            punchline: "Test"
        )

        joke.userRating = 5
        XCTAssertEqual(joke.ratingEmoji, "😂")

        joke.userRating = 1
        XCTAssertEqual(joke.ratingEmoji, "🫠")

        joke.userRating = nil
        XCTAssertNil(joke.ratingEmoji)
    }
}
```

### Service Tests with Mocking

**Pattern:** Mock external dependencies (Firebase, UserDefaults)

Example for `FirestoreService`:

```swift
import XCTest
@testable import MrFunnyJokes

// MARK: - Mock Implementation

final class MockFirestoreService: FirestoreServiceProtocol {
    var fetchInitialJokesCallCount = 0
    var fetchInitialJokesResult: [Joke] = []
    var fetchInitialJokesError: Error?

    func fetchInitialJokes(limit: Int = 20, forceRefresh: Bool = false) async throws -> [Joke] {
        fetchInitialJokesCallCount += 1
        if let error = fetchInitialJokesError {
            throw error
        }
        return fetchInitialJokesResult
    }

    // Additional mock methods...
}

// MARK: - Tests

final class FirestoreServiceTests: XCTestCase {
    var mockFirestore: MockFirestoreService!

    override func setUp() {
        super.setUp()
        mockFirestore = MockFirestoreService()
    }

    func testFetchInitialJokesSuccess() async {
        // Arrange
        let expectedJokes = JokeFixtures.createMockJokes(count: 5)
        mockFirestore.fetchInitialJokesResult = expectedJokes

        // Act
        let jokes = try! await mockFirestore.fetchInitialJokes(limit: 5)

        // Assert
        XCTAssertEqual(jokes.count, 5)
        XCTAssertEqual(mockFirestore.fetchInitialJokesCallCount, 1)
    }

    func testFetchInitialJokesNetworkError() async {
        // Arrange
        let networkError = NSError(domain: "Network", code: -1, userInfo: nil)
        mockFirestore.fetchInitialJokesError = networkError

        // Act & Assert
        do {
            _ = try await mockFirestore.fetchInitialJokes()
            XCTFail("Should throw error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
```

### ViewModel Tests

**Pattern:** Test reactive state updates and business logic

Example for `JokeViewModel`:

```swift
import XCTest
import Combine
@testable import MrFunnyJokes

final class JokeViewModelTests: XCTestCase {
    var viewModel: JokeViewModel!
    var mockFirestore: MockFirestoreService!
    var mockStorage: MockLocalStorageService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockFirestore = MockFirestoreService()
        mockStorage = MockLocalStorageService()
        viewModel = JokeViewModel(
            firestoreService: mockFirestore,
            localStorageService: mockStorage
        )
        cancellables = []
    }

    // MARK: - Loading State Tests

    func testInitialLoadingState() {
        XCTAssertTrue(viewModel.isInitialLoading)
        XCTAssertTrue(viewModel.jokes.isEmpty)
    }

    func testLoadingStateChanges() {
        // Subscribe to loading state
        let loadingStateChanged = expectation(forNotification: NSNotification.Name("loadingStateChanged"), object: nil)

        // Trigger load
        viewModel.refresh()

        // Wait for completion
        wait(for: [loadingStateChanged], timeout: 1.0)

        // Assert loading completed
        XCTAssertFalse(viewModel.isLoading)
    }

    // MARK: - Rating Tests

    func testRateJoke() {
        // Arrange
        let joke = JokeFixtures.createMockJoke(userRating: nil)
        viewModel.jokes = [joke]

        // Act
        viewModel.rateJoke(joke, rating: 5)

        // Assert
        XCTAssertEqual(viewModel.jokes[0].userRating, 5)
    }

    func testFilteredJokes() {
        // Arrange
        let dadJokes = JokeFixtures.createMockJokes(category: .dadJoke, count: 3)
        let knockKnockJokes = JokeFixtures.createMockJokes(category: .knockKnock, count: 2)
        viewModel.jokes = dadJokes + knockKnockJokes

        // Act
        viewModel.selectCategory(.dadJoke)

        // Assert
        XCTAssertEqual(viewModel.filteredJokes.count, 3)
        XCTAssertTrue(viewModel.filteredJokes.allSatisfy { $0.category == .dadJoke })
    }

    // MARK: - Async/Await Tests

    func testLoadInitialContentAsync() async {
        // Arrange
        mockFirestore.fetchInitialJokesResult = JokeFixtures.createMockJokes(count: 5)

        // Act
        await viewModel.loadInitialContent()

        // Assert
        XCTAssertFalse(viewModel.isInitialLoading)
        XCTAssertEqual(viewModel.jokes.count, 5)
    }
}
```

## Mocking Strategy

### Protocol-Based Mocks

Create protocols for services to enable easy mocking:

```swift
protocol FirestoreServiceProtocol {
    func fetchInitialJokes(limit: Int, forceRefresh: Bool) async throws -> [Joke]
    func fetchMoreJokes(limit: Int) async throws -> [Joke]
    func fetchJokes(category: JokeCategory, limit: Int, forceRefresh: Bool) async throws -> [Joke]
}

// Make actual service conform
extension FirestoreService: FirestoreServiceProtocol { }

// Create mock
final class MockFirestoreService: FirestoreServiceProtocol {
    // Mock implementation
}
```

### Test Fixtures

Reusable test data factory:

```swift
enum JokeFixtures {
    static func createMockJoke(
        id: UUID = UUID(),
        category: JokeCategory = .dadJoke,
        setup: String = "Why?",
        punchline: String = "Because!",
        character: String? = "mr_funny",
        userRating: Int? = nil
    ) -> Joke {
        Joke(
            id: id,
            category: category,
            setup: setup,
            punchline: punchline,
            userRating: userRating,
            character: character
        )
    }

    static func createMockJokes(
        category: JokeCategory = .dadJoke,
        count: Int = 5
    ) -> [Joke] {
        (0..<count).map { index in
            createMockJoke(setup: "Joke \(index) setup", punchline: "Joke \(index) punchline")
        }
    }
}
```

## Test Coverage Goals

### Priority 1 (Critical Path)

- ✗ `Joke` model encoding/decoding
- ✗ `JokeViewModel` state management
- ✗ `FirestoreService` fetch operations
- ✗ `LocalStorageService` caching logic
- ✗ Rating and impression tracking

### Priority 2 (Important Features)

- ✗ `JokeCharacter` lookup and filtering
- ✗ `NetworkMonitor` connectivity detection
- ✗ `CharacterDetailViewModel` filtering
- ✗ Share and copy functionality

### Priority 3 (Polish & Edge Cases)

- ✗ Knock-knock joke formatting
- ✗ Pagination and infinite scroll
- ✗ Error handling and fallbacks
- ✗ Widget data synchronization

## Async/Await Testing Patterns

### Testing Async Functions

```swift
func testAsyncFetch() async throws {
    // Arrange
    mockFirestore.fetchInitialJokesResult = JokeFixtures.createMockJokes(count: 3)

    // Act
    let jokes = try await mockFirestore.fetchInitialJokes()

    // Assert
    XCTAssertEqual(jokes.count, 3)
}
```

### Testing Async Errors

```swift
func testAsyncErrorHandling() async {
    // Arrange
    let error = NSError(domain: "Test", code: 1)
    mockFirestore.fetchInitialJokesError = error

    // Act & Assert
    do {
        _ = try await mockFirestore.fetchInitialJokes()
        XCTFail("Should throw")
    } catch {
        XCTAssertEqual(error as NSError, error)
    }
}
```

## Performance Testing

### Memory Profiling

Test large joke arrays:

```swift
func testLargeJokeArrayPerformance() {
    measure {
        let jokes = JokeFixtures.createMockJokes(count: 1000)
        _ = jokes.filter { $0.userRating == 5 }
    }
}
```

### Sorting Performance

Test feed freshness sorting algorithm:

```swift
func testSortJokesForFreshFeedPerformance() {
    measure {
        let jokes = JokeFixtures.createMockJokes(count: 500)
        _ = viewModel.sortJokesForFreshFeed(jokes)
    }
}
```

## UI Testing (XCUITest)

**File Location:** `MrFunnyJokesUITests/`

Example UI test structure:

```swift
import XCTest

final class JokeCardUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testSwipeJokeCard() throws {
        let jokeCard = app.buttons["JokeCard_0"]
        XCTAssertTrue(jokeCard.exists)

        jokeCard.swipeLeft()

        let punchlineText = app.staticTexts.matching(identifier: "punchline").firstMatch
        XCTAssertTrue(punchlineText.exists)
    }

    func testRateJoke() throws {
        let rateButton = app.buttons["RateButton_5"]
        rateButton.tap()

        let ratingIndicator = app.staticTexts["😂"]
        XCTAssertTrue(ratingIndicator.exists)
    }
}
```

## Continuous Integration Recommendations

### GitHub Actions Workflow

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Unit Tests
        run: xcodebuild test -scheme MrFunnyJokes -configuration Debug
      - name: Run UI Tests
        run: xcodebuild test -scheme MrFunnyJokes -configuration Debug -testPlan UITests
      - name: Generate Coverage Report
        run: |
          xcrun xccov view --json coverage.json > coverage_report.json
      - name: Upload Coverage
        uses: codecov/codecov-action@v1
```

## Coverage Metrics

**Target Coverage:** 80% for critical paths

Use Xcode's code coverage tools:
1. Scheme > Test > Options > Code Coverage
2. Report > Coverage
3. Export results to CI/CD

## Test Dependencies

**XCTest**: Built-in (no additional dependencies)

**Optional Test Libraries:**
- `ViewInspector` - SwiftUI view testing
- `Combine` - Reactive stream testing
- `Quick` and `Nimble` - BDD-style testing

## Implementation Priority

1. **Week 1**: Create test infrastructure and mock classes
2. **Week 2**: Add model and service tests (Priority 1)
3. **Week 3**: Add ViewModel tests
4. **Week 4**: Add UI tests and coverage reporting

## Running Tests

```bash
# Run all tests
xcodebuild test -scheme MrFunnyJokes

# Run specific test class
xcodebuild test -scheme MrFunnyJokes -only-testing MrFunnyJokesTests/JokeViewModelTests

# Generate coverage report
xcodebuild test -scheme MrFunnyJokes -configuration Debug -enableCodeCoverage YES
```

## Summary

The codebase is well-structured for testing but currently lacks any test implementation. The recommended approach:

1. Establish mock service protocols
2. Create test fixtures for consistent test data
3. Start with model and service tests (easiest to implement)
4. Progress to ViewModel and UI tests
5. Integrate with CI/CD for continuous coverage reporting
