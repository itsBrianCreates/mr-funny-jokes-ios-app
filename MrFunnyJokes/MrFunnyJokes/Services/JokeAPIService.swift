import Foundation

enum JokeAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noData
    case cancelled
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .cancelled:
            return "Request was cancelled"
        case .offline:
            return "No internet connection"
        }
    }
}

final class JokeAPIService: Sendable {
    static let shared = JokeAPIService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false // Don't wait - we want to fail fast for offline detection
        self.session = URLSession(configuration: config)
    }

    // MARK: - Dad Jokes API
    // GET https://icanhazdadjoke.com/
    // Headers: Accept: application/json, User-Agent: JokesApp

    func fetchDadJoke() async throws -> Joke {
        try Task.checkCancellation()

        guard let url = URL(string: "https://icanhazdadjoke.com/") else {
            throw JokeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("JokesApp", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw JokeAPIError.networkError(URLError(.badServerResponse))
            }

            let jokeResponse = try JSONDecoder().decode(DadJokeResponse.self, from: data)

            // Dad jokes come as a single string - split into setup/punchline
            let (setup, punchline) = splitJoke(jokeResponse.joke)

            return Joke(
                category: .dadJoke,
                setup: setup,
                punchline: punchline
            )
        } catch is CancellationError {
            throw JokeAPIError.cancelled
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw JokeAPIError.offline
        } catch let error as DecodingError {
            throw JokeAPIError.decodingError(error)
        } catch let error as JokeAPIError {
            throw error
        } catch {
            throw JokeAPIError.networkError(error)
        }
    }

    // MARK: - Knock-Knock Jokes API
    // GET https://official-joke-api.appspot.com/jokes/knock-knock/random
    // Response: [{ "id": 1, "type": "knock-knock", "setup": "...", "punchline": "..." }]

    func fetchKnockKnockJoke() async throws -> Joke {
        try Task.checkCancellation()

        guard let url = URL(string: "https://official-joke-api.appspot.com/jokes/knock-knock/random") else {
            throw JokeAPIError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw JokeAPIError.networkError(URLError(.badServerResponse))
            }

            // This API returns an array with one joke
            let jokes = try JSONDecoder().decode([OfficialJokeResponse].self, from: data)
            guard let first = jokes.first else {
                throw JokeAPIError.noData
            }

            return Joke(
                category: .knockKnock,
                setup: first.setup,
                punchline: first.punchline
            )
        } catch is CancellationError {
            throw JokeAPIError.cancelled
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw JokeAPIError.offline
        } catch let error as DecodingError {
            throw JokeAPIError.decodingError(error)
        } catch let error as JokeAPIError {
            throw error
        } catch {
            throw JokeAPIError.networkError(error)
        }
    }

    // MARK: - Pickup Lines API
    // GET http://ec2-3-7-73-121.ap-south-1.compute.amazonaws.com:8000/lines/random
    // Response: { "id": 1, "mood": "Flirty", "pickupline": "..." }

    func fetchPickupLine() async throws -> Joke {
        try Task.checkCancellation()

        guard let url = URL(string: "http://ec2-3-7-73-121.ap-south-1.compute.amazonaws.com:8000/lines/random") else {
            throw JokeAPIError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw JokeAPIError.networkError(URLError(.badServerResponse))
            }

            let pickupResponse = try JSONDecoder().decode(PickupLineResponse.self, from: data)

            // Convert pickup line to joke format
            // Use the pickup line as the punchline with a generic setup
            return Joke(
                category: .pickupLine,
                setup: "Try this pickup line:",
                punchline: pickupResponse.pickupline
            )
        } catch is CancellationError {
            throw JokeAPIError.cancelled
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw JokeAPIError.offline
        } catch let error as DecodingError {
            throw JokeAPIError.decodingError(error)
        } catch let error as JokeAPIError {
            throw error
        } catch {
            throw JokeAPIError.networkError(error)
        }
    }

    // MARK: - Category-Specific Fetching

    func fetchJoke(for category: JokeCategory) async throws -> Joke {
        switch category {
        case .dadJoke:
            return try await fetchDadJoke()
        case .knockKnock:
            return try await fetchKnockKnockJoke()
        case .pickupLine:
            return try await fetchPickupLine()
        }
    }

    func fetchJokes(for category: JokeCategory, count: Int) async -> [Joke] {
        guard !Task.isCancelled else { return [] }

        var jokes: [Joke] = []

        await withTaskGroup(of: Joke?.self) { group in
            for _ in 0..<count {
                guard !Task.isCancelled else { break }

                group.addTask {
                    guard !Task.isCancelled else { return nil }
                    do {
                        return try await self.fetchJoke(for: category)
                    } catch {
                        return nil
                    }
                }
            }

            for await joke in group {
                guard !Task.isCancelled else { break }
                if let joke = joke {
                    jokes.append(joke)
                }
            }
        }

        return jokes
    }

    // MARK: - Batch Fetching (Mixed Categories)

    /// Fetch jokes across all categories for initial load
    /// Returns jokes evenly distributed across categories
    func fetchInitialJokes(countPerCategory: Int = 5) async -> [Joke] {
        guard !Task.isCancelled else { return [] }

        var allJokes: [Joke] = []

        await withTaskGroup(of: [Joke].self) { group in
            for category in JokeCategory.allCases {
                group.addTask {
                    await self.fetchJokes(for: category, count: countPerCategory)
                }
            }

            for await jokes in group {
                guard !Task.isCancelled else { break }
                allJokes.append(contentsOf: jokes)
            }
        }

        return allJokes.shuffled()
    }

    /// Fetch more jokes (for infinite scrolling)
    /// If category is nil, fetches across all categories
    func fetchMoreJokes(category: JokeCategory?, count: Int = 5) async -> [Joke] {
        guard !Task.isCancelled else { return [] }

        if let category = category {
            // Fetch for specific category
            return await fetchJokes(for: category, count: count)
        } else {
            // Fetch across all categories (distribute count)
            let countPerCategory = max(1, count / JokeCategory.allCases.count)
            return await fetchInitialJokes(countPerCategory: countPerCategory)
        }
    }

    // MARK: - Helpers

    private func splitJoke(_ joke: String) -> (setup: String, punchline: String) {
        // Common patterns to split jokes
        let patterns = [
            "? ",      // Question mark followed by space
            "... ",    // Ellipsis
            "! ",      // Exclamation followed by space
            ". ",      // Period followed by space
        ]

        for pattern in patterns {
            if let range = joke.range(of: pattern) {
                let setup = String(joke[..<range.upperBound]).trimmingCharacters(in: .whitespaces)
                let punchline = String(joke[range.upperBound...]).trimmingCharacters(in: .whitespaces)

                if !punchline.isEmpty {
                    return (setup, punchline)
                }
            }
        }

        // If no pattern found, use the whole joke as punchline with a generic setup
        return ("Ready for a joke?", joke)
    }

    // MARK: - Network Connectivity Check

    /// Quick check if we can reach the network
    func checkConnectivity() async -> Bool {
        guard let url = URL(string: "https://icanhazdadjoke.com/") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
