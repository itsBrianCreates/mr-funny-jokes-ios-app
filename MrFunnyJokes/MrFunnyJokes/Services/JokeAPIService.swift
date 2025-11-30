import Foundation

enum JokeAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noData
    case cancelled

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
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    // MARK: - Dad Jokes API

    func fetchDadJoke() async throws -> Joke {
        // Check for cancellation before starting
        try Task.checkCancellation()

        guard let url = URL(string: "https://icanhazdadjoke.com") else {
            throw JokeAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("MrFunnyJokes iOS App", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            // Check for cancellation after network call
            try Task.checkCancellation()

            // Validate response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw JokeAPIError.networkError(URLError(.badServerResponse))
            }

            let jokeResponse = try JSONDecoder().decode(DadJokeResponse.self, from: data)

            // Dad jokes from this API come as a single string
            let (setup, punchline) = splitJoke(jokeResponse.joke)

            return Joke(
                category: .dadJoke,
                setup: setup,
                punchline: punchline
            )
        } catch is CancellationError {
            throw JokeAPIError.cancelled
        } catch let error as DecodingError {
            throw JokeAPIError.decodingError(error)
        } catch let error as JokeAPIError {
            throw error
        } catch {
            throw JokeAPIError.networkError(error)
        }
    }

    // MARK: - Official Joke API (Knock-Knock and General)

    func fetchKnockKnockJoke() async throws -> Joke {
        try Task.checkCancellation()

        guard let url = URL(string: "https://official-joke-api.appspot.com/jokes/knock-knock/random") else {
            throw JokeAPIError.invalidURL
        }

        return try await fetchFromOfficialAPI(url: url, category: .knockKnock)
    }

    func fetchRandomJoke() async throws -> Joke {
        try Task.checkCancellation()

        guard let url = URL(string: "https://official-joke-api.appspot.com/random_joke") else {
            throw JokeAPIError.invalidURL
        }

        // This API returns general jokes, we'll categorize as dad jokes
        return try await fetchFromOfficialAPI(url: url, category: .dadJoke)
    }

    private func fetchFromOfficialAPI(url: URL, category: JokeCategory) async throws -> Joke {
        do {
            let (data, response) = try await session.data(from: url)

            // Check for cancellation after network call
            try Task.checkCancellation()

            // Validate response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw JokeAPIError.networkError(URLError(.badServerResponse))
            }

            // Try parsing as array first (knock-knock endpoint returns array)
            if let jokes = try? JSONDecoder().decode([OfficialJokeResponse].self, from: data),
               let first = jokes.first {
                return Joke(
                    category: category,
                    setup: first.setup,
                    punchline: first.punchline
                )
            }

            // Try parsing as single object
            let jokeResponse = try JSONDecoder().decode(OfficialJokeResponse.self, from: data)
            return Joke(
                category: category,
                setup: jokeResponse.setup,
                punchline: jokeResponse.punchline
            )
        } catch is CancellationError {
            throw JokeAPIError.cancelled
        } catch let error as DecodingError {
            throw JokeAPIError.decodingError(error)
        } catch let error as JokeAPIError {
            throw error
        } catch {
            throw JokeAPIError.networkError(error)
        }
    }

    // MARK: - Helpers

    private func splitJoke(_ joke: String) -> (setup: String, punchline: String) {
        // Common patterns to split jokes
        let patterns = [
            "? ",      // Question mark followed by space
            "... ",    // Ellipsis
            "! ",      // Exclamation followed by space
            ". ",      // Period followed by space (take first occurrence)
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

    // MARK: - Batch Fetching

    func fetchMultipleJokes(count: Int = 5) async -> [Joke] {
        // Return empty if cancelled
        guard !Task.isCancelled else { return [] }

        var jokes: [Joke] = []

        await withTaskGroup(of: Joke?.self) { group in
            for i in 0..<count {
                // Check cancellation before adding each task
                guard !Task.isCancelled else { break }

                group.addTask {
                    // Check cancellation inside each task
                    guard !Task.isCancelled else { return nil }

                    do {
                        switch i % 3 {
                        case 0:
                            return try await self.fetchDadJoke()
                        case 1:
                            return try await self.fetchKnockKnockJoke()
                        default:
                            return try await self.fetchRandomJoke()
                        }
                    } catch {
                        // Silently handle errors - don't crash, just skip this joke
                        return nil
                    }
                }
            }

            for await joke in group {
                // Check cancellation while collecting results
                guard !Task.isCancelled else { break }

                if let joke = joke {
                    jokes.append(joke)
                }
            }
        }

        return jokes
    }
}
