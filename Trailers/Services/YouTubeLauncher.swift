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
        guard video.isYouTube, let url = video.youtubeURL else {
            Log.app.warning("Cannot open non-YouTube video: \(video.site)")
            return false
        }

        return await open(url: url)
    }

    /// Opens a video by YouTube video key.
    ///
    /// - Parameter videoKey: The YouTube video ID
    /// - Returns: True if the URL was opened successfully
    @MainActor
    @discardableResult
    static func open(videoKey: String) async -> Bool {
        let url = Constants.YouTube.watchURL(videoKey: videoKey)
        return await open(url: url)
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

    /// Gets a thumbnail URL for this video.
    ///
    /// - Parameter quality: Thumbnail quality
    /// - Returns: URL to the thumbnail, or nil if not a YouTube video
    func thumbnailURL(quality: YouTubeLauncher.ThumbnailQuality = .high) -> URL? {
        guard isYouTube else { return nil }
        return YouTubeLauncher.thumbnailURL(for: key, quality: quality)
    }
}
