// MARK: - PrefetchService.swift
// Trailers - tvOS App
// Service for prefetching detail data on focus

import Foundation

/// Service for prefetching media detail data when user focuses on a poster.
///
/// ## Overview
/// PrefetchService implements a debounced prefetch strategy:
/// - When a poster gains focus, a timer starts (default 350ms)
/// - If focus remains when timer fires, detail data is prefetched
/// - If focus moves away, the pending prefetch is cancelled
///
/// This ensures detail views load instantly for titles users pause on,
/// while avoiding wasted fetches for titles they scroll past quickly.
///
/// ## Usage
/// ```swift
/// // When poster gains focus
/// PrefetchService.shared.schedulePrefetch(for: mediaID)
///
/// // When poster loses focus
/// PrefetchService.shared.cancelPrefetch(for: mediaID)
/// ```
actor PrefetchService {

    // MARK: - Singleton

    /// Shared instance for app-wide access.
    static let shared = PrefetchService()

    // MARK: - Configuration

    /// Delay before prefetching (in seconds).
    /// User must stay focused this long before prefetch triggers.
    private let prefetchDelay: TimeInterval = 0.35

    // MARK: - State

    /// Currently scheduled prefetch tasks, keyed by media ID string.
    private var pendingTasks: [String: Task<Void, Never>] = [:]

    /// Set of media IDs that have been prefetched this session.
    private var prefetchedIDs: Set<String> = []

    // MARK: - Dependencies

    /// TMDB service for fetching details.
    private let tmdbService = TMDBService.shared

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Schedules a prefetch for the given media ID after the debounce delay.
    ///
    /// If the user moves focus away before the delay, call `cancelPrefetch`
    /// to prevent the fetch.
    ///
    /// - Parameter mediaID: The media item to prefetch
    func schedulePrefetch(for mediaID: MediaID) {
        let key = mediaID.cacheKey

        // Skip if already prefetched this session
        guard !prefetchedIDs.contains(key) else {
            return
        }

        // Cancel any existing task for this ID
        pendingTasks[key]?.cancel()

        // Schedule new prefetch task
        let task = Task { [weak self] in
            // Wait for debounce delay
            try? await Task.sleep(nanoseconds: UInt64(350_000_000)) // 350ms

            // Check if cancelled during sleep
            guard !Task.isCancelled else { return }

            // Perform prefetch
            await self?.performPrefetch(for: mediaID)
        }

        pendingTasks[key] = task
    }

    /// Cancels any pending prefetch for the given media ID.
    ///
    /// Call this when the poster loses focus.
    ///
    /// - Parameter mediaID: The media item to cancel prefetch for
    func cancelPrefetch(for mediaID: MediaID) {
        let key = mediaID.cacheKey
        pendingTasks[key]?.cancel()
        pendingTasks[key] = nil
    }

    /// Clears the prefetched IDs set.
    ///
    /// Call this when refreshing content to allow re-prefetching.
    func clearPrefetchHistory() {
        prefetchedIDs.removeAll()
    }

    // MARK: - Private Methods

    /// Performs the actual prefetch.
    private func performPrefetch(for mediaID: MediaID) async {
        let key = mediaID.cacheKey

        // Clean up pending task
        pendingTasks[key] = nil

        // Mark as prefetched to avoid duplicates
        prefetchedIDs.insert(key)

        do {
            // Fetch detail (this will cache it via TMDBService)
            _ = try await tmdbService.fetchDetail(for: mediaID)
            Log.network.debug("Prefetched detail for \(mediaID)")
        } catch {
            // Remove from prefetched so it can be retried
            prefetchedIDs.remove(key)
            Log.network.debug("Prefetch failed for \(mediaID): \(error.localizedDescription)")
        }
    }
}
