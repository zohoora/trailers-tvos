// MARK: - YouTubeLauncher.swift
// Trailers - tvOS App
// Service for launching YouTube videos via Universal Links

import UIKit

/// Service for launching YouTube videos on tvOS.
///
/// ## Overview
/// YouTubeLauncher opens trailers in the YouTube tvOS app using Universal Links.
/// If the YouTube app is not installed, tvOS will open a limited web view.
///
/// ## How It Works
/// 1. Constructs a YouTube watch URL: `https://www.youtube.com/watch?v={videoKey}`
/// 2. Opens the URL via `UIApplication.shared.open()`
/// 3. tvOS routes to YouTube app if installed, otherwise opens web view
///
/// ## Usage
/// ```swift
/// // Open a video
/// await YouTubeLauncher.open(video: trailer)
///
/// // Or with just the key
/// await YouTubeLauncher.open(videoKey: "dQw4w9WgXcQ")
/// ```
///
/// ## Notes
/// - App does not auto-return after playback
/// - User must switch back to the app manually
/// - No callback when user returns
enum YouTubeLauncher {

    // MARK: - Public API

    /// Opens a video in the YouTube app.
    ///
    /// - Parameter video: The video to play
    /// - Returns: True if the URL was opened successfully
    @MainActor
    @discardableResult
    static func open(video: Video) async -> Bool {
        guard video.isYouTube else {
            Log.app.warning("Cannot open non-YouTube video: \(video.site)")
            return false
        }

        return await open(videoKey: video.key)
    }

    /// Opens a video by YouTube video key.
    ///
    /// On tvOS, this tries the YouTube app URL scheme first (`youtube://watch/{key}`),
    /// then falls back to the web URL if the app isn't installed.
    ///
    /// - Parameter videoKey: The YouTube video ID
    /// - Returns: True if the URL was opened successfully
    @MainActor
    @discardableResult
    static func open(videoKey: String) async -> Bool {
        // Try YouTube app URL scheme first (tvOS requires this)
        if let youtubeAppURL = URL(string: "youtube://watch/\(videoKey)") {
            Log.app.info("Trying YouTube app URL: \(youtubeAppURL.absoluteString)")

            if UIApplication.shared.canOpenURL(youtubeAppURL) {
                let success = await UIApplication.shared.open(youtubeAppURL, options: [:])
                if success {
                    Log.app.info("YouTube app URL opened successfully")
                    return true
                }
            }
        }

        // Fall back to web URL (opens in limited web view if YouTube app not installed)
        let webURL = Constants.YouTube.watchURL(videoKey: videoKey)
        return await open(url: webURL)
    }

    /// Opens a YouTube URL.
    ///
    /// - Parameter url: The YouTube watch URL
    /// - Returns: True if the URL was opened successfully
    @MainActor
    @discardableResult
    static func open(url: URL) async -> Bool {
        Log.app.info("Opening YouTube URL: \(url.absoluteString)")

        // Check if we can open the URL
        guard UIApplication.shared.canOpenURL(url) else {
            Log.app.error("Cannot open URL: \(url.absoluteString)")
            return false
        }

        // Open the URL
        let success = await UIApplication.shared.open(url, options: [:])

        if success {
            Log.app.info("YouTube URL opened successfully")
        } else {
            Log.app.error("Failed to open YouTube URL")
        }

        return success
    }

    // MARK: - TMDB Playback

    /// Opens a video on TMDB's embedded player.
    ///
    /// - Parameter video: The video to play
    /// - Returns: True if the URL was opened successfully
    @MainActor
    @discardableResult
    static func openOnTMDB(video: Video) async -> Bool {
        guard video.isYouTube, let url = video.tmdbVideoURL else {
            Log.app.warning("Cannot open non-YouTube video on TMDB: \(video.site)")
            return false
        }

        return await openOnTMDB(url: url)
    }

    /// Opens a TMDB video player URL.
    ///
    /// - Parameter url: The TMDB player URL
    /// - Returns: True if the URL was opened successfully
    @MainActor
    @discardableResult
    static func openOnTMDB(url: URL) async -> Bool {
        Log.app.info("Opening TMDB video URL: \(url.absoluteString)")

        guard UIApplication.shared.canOpenURL(url) else {
            Log.app.error("Cannot open TMDB URL: \(url.absoluteString)")
            return false
        }

        let success = await UIApplication.shared.open(url, options: [:])

        if success {
            Log.app.info("TMDB video URL opened successfully")
        } else {
            Log.app.error("Failed to open TMDB video URL")
        }

        return success
    }

    // MARK: - Utility Methods

    /// Checks if the YouTube app is available.
    ///
    /// - Note: This is advisory only. Even if false, the system web view can still open videos.
    /// - Returns: True if YouTube app URL scheme can be opened
    @MainActor
    static func isYouTubeAppAvailable() -> Bool {
        // Check YouTube app URL scheme
        if let youtubeAppURL = URL(string: "youtube://") {
            return UIApplication.shared.canOpenURL(youtubeAppURL)
        }
        return false
    }

    /// Creates a YouTube thumbnail URL for a video.
    ///
    /// - Parameters:
    ///   - videoKey: The YouTube video ID
    ///   - quality: Thumbnail quality (default, medium, high, maxres)
    /// - Returns: URL to the thumbnail image
    static func thumbnailURL(for videoKey: String, quality: ThumbnailQuality = .high) -> URL? {
        URL(string: "https://img.youtube.com/vi/\(videoKey)/\(quality.rawValue).jpg")
    }

    /// YouTube thumbnail quality options.
    enum ThumbnailQuality: String {
        /// Default quality (120x90)
        case `default` = "default"

        /// Medium quality (320x180)
        case medium = "mqdefault"

        /// High quality (480x360)
        case high = "hqdefault"

        /// Standard definition (640x480)
        case standardDefinition = "sddefault"

        /// Maximum resolution (1280x720)
        case maxRes = "maxresdefault"
    }
}

// MARK: - Video Extension

extension Video {

    /// Opens this video in the YouTube app.
    ///
    /// - Returns: True if opened successfully
    @MainActor
    func openInYouTube() async -> Bool {
        await YouTubeLauncher.open(video: self)
    }

    /// Opens this video on TMDB's embedded player.
    ///
    /// - Returns: True if opened successfully
    @MainActor
    func openOnTMDB() async -> Bool {
        await YouTubeLauncher.openOnTMDB(video: self)
    }

    /// Gets a thumbnail URL for this video.
    ///
    /// - Parameter quality: Thumbnail quality
    /// - Returns: URL to the thumbnail, or nil if not a YouTube video
    func thumbnailURL(quality: YouTubeLauncher.ThumbnailQuality = .high) -> URL? {
        guard isYouTube else { return nil }
        return YouTubeLauncher.thumbnailURL(for: key, quality: quality)
    }
}
