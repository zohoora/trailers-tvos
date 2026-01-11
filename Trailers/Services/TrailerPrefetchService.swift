// MARK: - TrailerPrefetchService.swift
// Trailers - tvOS App
// Service for prefetching trailer stream URLs and pre-buffering

import Foundation
import AVFoundation

/// Service for prefetching trailer stream URLs and pre-buffering video.
///
/// ## Overview
/// TrailerPrefetchService improves trailer playback by:
/// 1. Prefetching stream URLs when detail view loads
/// 2. Creating AVPlayer and starting buffer while user reads details
/// 3. Providing instant playback when user presses Play
///
/// ## Usage
/// ```swift
/// // When detail view loads
/// await TrailerPrefetchService.shared.prefetch(videoKey: trailer.key)
///
/// // When playing trailer
/// if let player = await TrailerPrefetchService.shared.getPreBufferedPlayer(for: videoKey) {
///     // Use pre-buffered player - instant playback!
/// }
/// ```
actor TrailerPrefetchService {

    // MARK: - Singleton

    /// Shared instance for app-wide access.
    static let shared = TrailerPrefetchService()

    // MARK: - Types

    /// Cached stream data for a video.
    struct CachedStream {
        let url: URL
        let player: AVPlayer
        let timestamp: Date

        /// Whether this cache entry is still valid (URLs expire after ~4 hours, we use 1 hour to be safe).
        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < 3600 // 1 hour
        }
    }

    // MARK: - State

    /// Cached streams keyed by video key.
    private var cache: [String: CachedStream] = [:]

    /// Currently prefetching video keys (to avoid duplicate requests).
    private var prefetching: Set<String> = []

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Prefetches the stream URL and starts buffering for a video.
    ///
    /// This should be called when the detail view loads. The prefetch happens
    /// in the background and the result is cached for when the user presses Play.
    ///
    /// - Parameter videoKey: The YouTube video key (e.g., "dQw4w9WgXcQ")
    func prefetch(videoKey: String) async {
        // Skip if already cached and valid
        if let cached = cache[videoKey], cached.isValid {
            Log.network.debug("Trailer already cached: \(videoKey)")
            return
        }

        // Skip if already prefetching
        guard !prefetching.contains(videoKey) else {
            Log.network.debug("Trailer already prefetching: \(videoKey)")
            return
        }

        prefetching.insert(videoKey)
        defer { prefetching.remove(videoKey) }

        Log.network.debug("Prefetching trailer: \(videoKey)")

        // Fetch stream URL from yt-dlp server
        guard let streamURL = await fetchStreamURL(videoKey: videoKey) else {
            Log.network.debug("Failed to prefetch trailer: \(videoKey)")
            return
        }

        // Create player and start buffering
        let player = AVPlayer(url: streamURL)

        // Configure for background buffering
        player.automaticallyWaitsToMinimizeStalling = true

        // Start buffering by setting rate to 0 (paused but buffering)
        // The player will buffer automatically when given a URL
        await MainActor.run {
            player.pause()
        }

        // Cache the result
        cache[videoKey] = CachedStream(
            url: streamURL,
            player: player,
            timestamp: Date()
        )

        Log.network.debug("Trailer prefetched and buffering: \(videoKey)")
    }

    /// Gets the cached stream URL for a video.
    ///
    /// - Parameter videoKey: The YouTube video key
    /// - Returns: The cached URL if available and valid, nil otherwise
    func getCachedURL(for videoKey: String) -> URL? {
        guard let cached = cache[videoKey], cached.isValid else {
            return nil
        }
        return cached.url
    }

    /// Gets the pre-buffered player for a video.
    ///
    /// The returned player has already been buffering, so playback
    /// should start almost instantly.
    ///
    /// - Parameter videoKey: The YouTube video key
    /// - Returns: The pre-buffered AVPlayer if available, nil otherwise
    func getPreBufferedPlayer(for videoKey: String) -> AVPlayer? {
        guard let cached = cache[videoKey], cached.isValid else {
            return nil
        }

        // Remove from cache since we're handing off the player
        cache.removeValue(forKey: videoKey)

        return cached.player
    }

    /// Clears all cached streams.
    ///
    /// Call this when memory pressure is detected or app goes to background.
    func clearCache() {
        // Stop all players to release resources
        for (_, cached) in cache {
            cached.player.pause()
        }
        cache.removeAll()
        Log.network.debug("Trailer prefetch cache cleared")
    }

    /// Clears a specific cached stream.
    ///
    /// - Parameter videoKey: The video key to remove from cache
    func clearCache(for videoKey: String) {
        if let cached = cache[videoKey] {
            cached.player.pause()
        }
        cache.removeValue(forKey: videoKey)
    }

    // MARK: - Private Methods

    /// Fetches stream URL from the local yt-dlp server.
    private func fetchStreamURL(videoKey: String) async -> URL? {
        let serverURL = Config.youtubeServerURL
        let quality = Config.youtubePreferredQuality

        guard let apiURL = URL(string: "\(serverURL)/stream/\(videoKey)?quality=\(quality)") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: apiURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let urlString = json["url"] as? String,
                  let url = URL(string: urlString) else {
                return nil
            }

            return url

        } catch {
            Log.network.debug("Trailer prefetch network error: \(error.localizedDescription)")
            return nil
        }
    }
}
