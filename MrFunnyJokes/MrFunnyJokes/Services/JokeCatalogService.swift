import Foundation

/// The whole joke catalog, kept on the device.
///
/// Feeds are built from this instead of from a "top N" Firestore query, which returned
/// the same jokes on every launch. The first sync downloads every joke; later syncs ask
/// only for documents whose `updated_at` moved, so a normal launch costs one small query.
/// A full download repeats weekly to drop deleted jokes and refresh rating counts.
@MainActor
final class JokeCatalogService {
    static let shared = JokeCatalogService()

    /// Every joke in the catalog, in no particular order. Empty until loaded or synced.
    private(set) var jokes: [Joke] = []

    private let firestoreService = FirestoreService.shared

    /// Newest `updated_at` already in `jokes`
    private var cursor: FirestoreService.CatalogCursor?
    private var lastFullSync: Date?
    private var hasLoadedFromDisk = false
    private var syncTask: Task<Bool, Error>?

    private let fullSyncInterval: TimeInterval = 7 * 24 * 60 * 60

    private struct Snapshot: Codable {
        var jokes: [Joke]
        var cursor: FirestoreService.CatalogCursor?
        var lastFullSync: Date?
    }

    private init() {}

    // MARK: - Loading

    /// The catalog saved by the last sync. Reads the file once; later calls return from memory.
    func loadFromDisk() async -> [Joke] {
        guard !hasLoadedFromDisk else { return jokes }

        let url = Self.fileURL
        let snapshot = await Task.detached(priority: .userInitiated) { () -> Snapshot? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Snapshot.self, from: data)
        }.value

        // A sync may have finished while the file was being read; it is newer
        guard !hasLoadedFromDisk else { return jokes }
        hasLoadedFromDisk = true

        if let snapshot {
            jokes = snapshot.jokes
            cursor = snapshot.cursor
            lastFullSync = snapshot.lastFullSync
        }
        return jokes
    }

    // MARK: - Syncing

    /// Brings the catalog up to date with Firestore.
    /// - Returns: True when `jokes` changed
    /// - Throws: When Firestore can't be reached; `jokes` is left as it was
    @discardableResult
    func sync() async throws -> Bool {
        if let syncTask {
            return try await syncTask.value
        }

        let task = Task { try await performSync() }
        syncTask = task
        defer { syncTask = nil }
        return try await task.value
    }

    private func performSync() async throws -> Bool {
        _ = await loadFromDisk()

        let fullSyncIsDue = lastFullSync.map { Date().timeIntervalSince($0) > fullSyncInterval } ?? true

        if jokes.isEmpty || fullSyncIsDue {
            let result = try await firestoreService.fetchCatalog()
            // An empty answer is a broken read, not an empty catalog
            guard !result.jokes.isEmpty else { return false }
            jokes = result.jokes
            cursor = result.cursor
            lastFullSync = Date()
            save()
            return true
        }

        guard let cursor else {
            // Catalog without a cursor can't ask "what changed"; the next sync starts over
            lastFullSync = nil
            return false
        }

        let result = try await firestoreService.fetchCatalog(updatedAfter: cursor)
        guard !result.jokes.isEmpty else { return false }

        var indexById: [String: Int] = [:]
        for (index, joke) in jokes.enumerated() {
            if let id = joke.firestoreId { indexById[id] = index }
        }
        for joke in result.jokes {
            if let id = joke.firestoreId, let index = indexById[id] {
                jokes[index] = joke
            } else {
                jokes.append(joke)
            }
        }
        self.cursor = result.cursor ?? cursor
        save()
        return true
    }

    // MARK: - Disk

    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("JokeCatalog.json")
    }

    private func save() {
        let snapshot = Snapshot(jokes: jokes, cursor: cursor, lastFullSync: lastFullSync)
        let url = Self.fileURL
        Task.detached(priority: .utility) {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
            } catch {
                print("Failed to save joke catalog: \(error)")
            }
        }
    }
}
