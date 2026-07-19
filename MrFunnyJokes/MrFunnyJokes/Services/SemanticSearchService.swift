import Foundation
import NaturalLanguage

/// Provides on-device semantic + keyword ("hybrid") search over the joke catalog.
///
/// Keyword search alone only surfaces jokes that literally contain the query
/// string. This service augments that with Apple's on-device sentence
/// embeddings (`NLEmbedding`) so that a query like "food" also surfaces jokes
/// about pizza, burgers, or being hungry, and a natural-language query like
/// "tell me jokes about sports" is understood even when the tags are imperfect.
///
/// Everything runs locally: no network, no API cost, works offline. This fits
/// the app's existing "load the full catalog client-side and filter locally"
/// architecture, and is more than fast enough for a catalog of a few hundred
/// jokes.
///
/// Scoring blends two signals into a single relevance value per joke:
///   • Keyword score — how well the query's meaningful tokens literally match
///     the joke's text/tags/character. Weighted so literal matches stay on top.
///   • Semantic score — cosine similarity between the query embedding and the
///     joke embedding, so topically-related jokes surface even without a
///     literal match.
///
/// If sentence embeddings are unavailable on the device (they ship with iOS for
/// English, so this is rare), the service degrades gracefully to keyword-only
/// ranking.
final class SemanticSearchService {
    static let shared = SemanticSearchService()

    /// Apple's bundled English sentence embedding. `nil` only if the OS can't
    /// provide it, in which case we fall back to keyword-only ranking.
    private let embedding = NLEmbedding.sentenceEmbedding(for: .english)

    /// Cache of joke embedding vectors, keyed by Firestore document ID.
    /// Joke text is immutable for a given ID, so entries never need invalidation.
    private var vectorCache: [String: [Double]] = [:]
    private let cacheLock = NSLock()

    /// Serial queue for the (cheap) CPU work of embedding + ranking, keeping it
    /// off the main thread so search never blocks scrolling or typing.
    private let workQueue = DispatchQueue(label: "com.mrfunnyjokes.semanticsearch", qos: .userInitiated)

    /// Common filler words stripped from queries so "tell me some jokes about
    /// sports" keyword-matches on "sports", not on "tell"/"me"/"jokes".
    private static let stopwords: Set<String> = [
        "a", "an", "the", "of", "for", "to", "on", "in", "with", "and", "or",
        "about", "me", "my", "some", "any", "please", "tell", "give", "show",
        "find", "get", "want", "like", "that", "this", "these", "those", "is",
        "are", "do", "does", "can", "you", "your", "joke", "jokes", "funny",
        "something", "anything"
    ]

    /// Tokens shorter than this are ignored for keyword matching (too noisy).
    private static let minTokenLength = 3

    /// Semantic-only matches below this cosine similarity are treated as noise
    /// and excluded, so vague queries don't return the entire catalog.
    private static let semanticFloor = 0.30

    /// Relative weights for the blended score. Keyword-dominant so a literal
    /// match reliably outranks a purely topical one, while semantic similarity
    /// still breaks ties and pulls in related jokes.
    private static let keywordWeight = 0.60
    private static let semanticWeight = 0.55

    private init() {}

    /// Whether on-device semantic ranking is available. When `false`, results
    /// are keyword-only.
    var isSemanticAvailable: Bool { embedding != nil }

    // MARK: - Public API

    /// Pre-computes and caches embeddings for any jokes not yet cached.
    ///
    /// Safe to call repeatedly (and from `onAppear` / whenever the catalog
    /// grows) — it only does work for jokes it hasn't seen. Pre-warming means
    /// the user's first query is instant.
    func warmUp(with jokes: [Joke]) async {
        guard embedding != nil else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            workQueue.async { [weak self] in
                self?.ensureVectorsCached(for: jokes)
                continuation.resume()
            }
        }
    }

    /// Ranks jokes for a query and returns the matching Firestore IDs in
    /// descending relevance order.
    ///
    /// IDs (not `Joke` values) are returned so the caller can look up fresh joke
    /// data — matching the app's "store IDs, not stale value copies" pattern.
    /// Jokes without a `firestoreId` are excluded (parity with prior behavior).
    func rankedResultIds(for query: String, in jokes: [Joke], limit: Int = 100) async -> [String] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[String], Never>) in
            workQueue.async { [weak self] in
                let ids = self?.computeRankedResultIds(for: query, in: jokes, limit: limit) ?? []
                continuation.resume(returning: ids)
            }
        }
    }

    // MARK: - Ranking

    private func computeRankedResultIds(for query: String, in jokes: [Joke], limit: Int) -> [String] {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }

        let tokens = meaningfulTokens(from: normalizedQuery)

        // Embed the "cleaned" query (filler removed) for a sharper topical
        // signal; fall back to the raw query if cleaning left nothing.
        let queryVector: [Double]?
        if embedding != nil {
            let cleaned = tokens.isEmpty ? normalizedQuery : tokens.joined(separator: " ")
            queryVector = embedding?.vector(for: cleaned) ?? embedding?.vector(for: normalizedQuery)
        } else {
            queryVector = nil
        }

        // Make sure every joke we're about to score has a cached vector.
        if queryVector != nil {
            ensureVectorsCached(for: jokes)
        }

        struct Scored {
            let id: String
            let score: Double
            let popularity: Double
        }

        var scored: [Scored] = []
        scored.reserveCapacity(jokes.count)

        for joke in jokes {
            guard let id = joke.firestoreId else { continue }

            let keyword = keywordScore(for: joke, query: normalizedQuery, tokens: tokens)

            var semantic = 0.0
            if let queryVector, let jokeVector = cachedVector(for: id) {
                semantic = max(0.0, cosineSimilarity(queryVector, jokeVector))
            }

            // Include the joke if it has any literal match, or if it's
            // topically close enough to clear the noise floor.
            guard keyword > 0 || semantic >= Self.semanticFloor else { continue }

            let blended = keyword * Self.keywordWeight + semantic * Self.semanticWeight
            scored.append(Scored(id: id, score: blended, popularity: joke.popularityScore))
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.popularity > rhs.popularity
            }
            .prefix(limit)
            .map(\.id)
    }

    /// Literal-match score in `[0, 1]` based on how much of the query's
    /// meaningful vocabulary appears in the joke.
    private func keywordScore(for joke: Joke, query: String, tokens: [String]) -> Double {
        let haystack = searchableText(for: joke)
        let tags = (joke.tags ?? []).map { $0.lowercased() }

        // No meaningful tokens (e.g. a query of only filler/short words):
        // fall back to a whole-phrase substring test, matching legacy behavior.
        guard !tokens.isEmpty else {
            return haystack.contains(query) ? 0.9 : 0.0
        }

        var matched = 0
        var exactTagMatch = false
        for token in tokens {
            if tags.contains(token) {
                matched += 1
                exactTagMatch = true
            } else if haystack.contains(token) {
                matched += 1
            }
        }

        guard matched > 0 else { return 0.0 }

        let coverage = Double(matched) / Double(tokens.count)
        let tagBonus = exactTagMatch ? 0.1 : 0.0
        return min(1.0, coverage * 0.9 + tagBonus)
    }

    // MARK: - Embedding cache

    private func ensureVectorsCached(for jokes: [Joke]) {
        guard let embedding else { return }
        for joke in jokes {
            guard let id = joke.firestoreId else { continue }

            cacheLock.lock()
            let alreadyCached = vectorCache[id] != nil
            cacheLock.unlock()
            if alreadyCached { continue }

            let text = embeddingText(for: joke)
            guard let vector = embedding.vector(for: text) else { continue }

            cacheLock.lock()
            vectorCache[id] = vector
            cacheLock.unlock()
        }
    }

    private func cachedVector(for id: String) -> [Double]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return vectorCache[id]
    }

    // MARK: - Text builders

    /// Natural-language text used to build a joke's embedding. Character IDs
    /// (e.g. "mr_funny") are intentionally excluded — they add noise to the
    /// semantic signal but are still matched by keyword search below.
    private func embeddingText(for joke: Joke) -> String {
        var parts = [joke.setup, joke.punchline]
        if let tags = joke.tags, !tags.isEmpty {
            parts.append(tags.joined(separator: " "))
        }
        return parts.joined(separator: " ")
    }

    /// Lowercased text used for literal keyword matching (includes character).
    private func searchableText(for joke: Joke) -> String {
        var parts = [joke.setup, joke.punchline]
        if let tags = joke.tags, !tags.isEmpty {
            parts.append(tags.joined(separator: " "))
        }
        if let character = joke.character {
            parts.append(character)
        }
        return parts.joined(separator: " ").lowercased()
    }

    private func meaningfulTokens(from query: String) -> [String] {
        query
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= Self.minTokenLength && !Self.stopwords.contains($0) }
    }

    // MARK: - Math

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for i in a.indices {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        guard normA > 0, normB > 0 else { return 0.0 }
        return dot / (normA.squareRoot() * normB.squareRoot())
    }
}
