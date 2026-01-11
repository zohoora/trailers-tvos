// MARK: - WatchHistoryService.swift
// Trailers - tvOS App
// Service for tracking which trailers have been viewed

import Foundation

/// Service for tracking which media items have had their trailers viewed.
///
/// ## Overview
/// WatchHistoryService stores MediaIDs of items where the trailer has been
/// played. This is used to show a "watched" indicator on the grid.
///
/// ## Storage
/// Uses UserDefaults for persistent storage.
///
/// ## Usage
/// ```swift
/// // Mark as watched
/// WatchHistoryService.shared.markAsWatched(mediaID)
///
/// // Check if watched
/// let watched = WatchHistoryService.shared.hasWatched(mediaID)
/// ```
@MainActor
final class WatchHistoryService: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide access.
    static let shared = WatchHistoryService()

    // MARK: - Published State

    /// Set of watched media IDs (for reactive UI updates).
    @Published private(set) var watchedIDs: Set<String> = []

    // MARK: - Private Properties

    /// UserDefaults key for storing watched IDs.
    private let storageKey = "WatchedTrailerIDs"

    /// UserDefaults instance.
    private let defaults = UserDefaults.standard

    // MARK: - Initialization

    /// Set to true to clear history on next launch, then set back to false.
    private let shouldClearOnLaunch = false

    private init() {
        if shouldClearOnLaunch {
            defaults.removeObject(forKey: storageKey)
            Log.app.info("Watch history cleared on launch")
        }
        loadWatchedIDs()
    }

    // MARK: - Public Methods

    /// Marks a media item as watched.
    ///
    /// - Parameter mediaID: The media ID that was watched
    func markAsWatched(_ mediaID: MediaID) {
        let key = mediaID.cacheKey
        guard !watchedIDs.contains(key) else { return }

        watchedIDs.insert(key)
        saveWatchedIDs()

        Log.app.info("Marked as watched: \(mediaID)")
    }

    /// Checks if a media item has been watched.
    ///
    /// - Parameter mediaID: The media ID to check
    /// - Returns: True if the trailer has been viewed
    func hasWatched(_ mediaID: MediaID) -> Bool {
        watchedIDs.contains(mediaID.cacheKey)
    }

    /// Clears all watch history.
    func clearHistory() {
        watchedIDs.removeAll()
        saveWatchedIDs()
        Log.app.info("Cleared watch history")
    }

    /// The number of watched items.
    var watchedCount: Int {
        watchedIDs.count
    }

    // MARK: - Private Methods

    /// Loads watched IDs from UserDefaults.
    private func loadWatchedIDs() {
        if let stored = defaults.stringArray(forKey: storageKey) {
            watchedIDs = Set(stored)
            let count = watchedIDs.count
            Log.app.info("Loaded \(count) watched items from storage")
        }
    }

    /// Saves watched IDs to UserDefaults.
    private func saveWatchedIDs() {
        defaults.set(Array(watchedIDs), forKey: storageKey)
    }
}
