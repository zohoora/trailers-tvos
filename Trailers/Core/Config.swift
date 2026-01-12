// MARK: - Config.swift
// Trailers - tvOS App
// Configuration management for API tokens and app settings

import Foundation

/// Configuration manager that reads settings from Info.plist and build configuration.
///
/// ## Overview
/// This enum provides centralized access to all configuration values required by the app,
/// including API keys, base URLs, and feature flags.
///
/// ## Security Note
/// The TMDB API key should be stored in a Config.xcconfig file that is NOT committed to version control.
/// Add `Config.xcconfig` to your `.gitignore` file.
///
/// ## Setup Instructions
/// 1. Create a `Config.xcconfig` file in the project root with:
///    ```
///    TMDB_API_KEY = your_api_key_here
///    ```
/// 2. In Xcode, go to Project Settings > Info tab
/// 3. Add a new key `TMDB_API_KEY` with value `$(TMDB_API_KEY)`
///
/// ## Usage
/// ```swift
/// let apiKey = Config.tmdbAPIKey
/// let imageBaseURL = Config.tmdbImageBaseURL
/// ```
enum Config {

    // MARK: - TMDB API Configuration

    /// The TMDB API Key for authentication.
    ///
    /// This key is read from Info.plist, which should reference the build configuration.
    /// If the key is not found, a fatal error is raised to prevent silent failures.
    ///
    /// - Important: Never commit the actual API key to version control.
    static var tmdbAPIKey: String {
        guard let apiKey = Bundle.main.infoDictionary?["TMDB_API_KEY"] as? String,
              !apiKey.isEmpty,
              !apiKey.hasPrefix("$(") else {
            #if DEBUG
            // In debug builds, provide a helpful error message
            fatalError("""
                TMDB_API_KEY not configured.

                To fix this:
                1. Create Config.xcconfig in the project root
                2. Add: TMDB_API_KEY = your_api_key_here
                3. Ensure Info.plist has TMDB_API_KEY = $(TMDB_API_KEY)

                Get your API key from: https://www.themoviedb.org/settings/api
                """)
            #else
            fatalError("API configuration error")
            #endif
        }
        return apiKey
    }

    /// Base URL for TMDB API v3 endpoints.
    static let tmdbAPIBaseURL = URL(string: "https://api.themoviedb.org/3")!

    /// Base URL for TMDB image CDN.
    ///
    /// Use this with poster/backdrop paths to construct full image URLs.
    /// Example: `\(tmdbImageBaseURL)/w500/abc123.jpg`
    static let tmdbImageBaseURL = URL(string: "https://image.tmdb.org/t/p")!

    // MARK: - Image Size Configuration

    /// Available poster sizes from TMDB CDN.
    ///
    /// - w92: Thumbnail (92px width)
    /// - w154: Small (154px width)
    /// - w185: Medium (185px width)
    /// - w342: Large (342px width)
    /// - w500: Extra large (500px width)
    /// - w780: Full size (780px width)
    /// - original: Original resolution
    enum PosterSize: String {
        case w92, w154, w185, w342, w500, w780, original

        /// Recommended size for tvOS grid display.
        static let grid = PosterSize.w500

        /// Recommended size for detail screen display.
        static let detail = PosterSize.w780
    }

    /// Available backdrop sizes from TMDB CDN.
    ///
    /// - w300: Small (300px width)
    /// - w780: Medium (780px width)
    /// - w1280: Large (1280px width)
    /// - original: Original resolution
    enum BackdropSize: String {
        case w300, w780, w1280, original

        /// Recommended size for tvOS detail screen backdrop.
        static let detail = BackdropSize.w1280
    }

    // MARK: - Cache Configuration

    /// Time-to-live values for different cache types.
    enum CacheTTL {
        /// Genre lists cache duration (7 days).
        static let genres: TimeInterval = 7 * 24 * 60 * 60

        /// Grid content cache duration (5 minutes).
        static let grid: TimeInterval = 5 * 60

        /// Detail content cache duration (30 minutes).
        static let detail: TimeInterval = 30 * 60
    }

    // MARK: - Network Configuration

    /// Maximum concurrent network requests allowed.
    static let maxConcurrentRequests = 4

    /// Request deduplication window in seconds.
    static let requestDeduplicationWindow: TimeInterval = 0.5

    /// Initial backoff delay for rate limiting (in seconds).
    static let initialBackoffDelay: TimeInterval = 1.0

    /// Maximum backoff delay for rate limiting (in seconds).
    static let maxBackoffDelay: TimeInterval = 30.0

    /// Maximum retry attempts for rate-limited requests.
    static let maxRetryAttempts = 5

    // MARK: - Pagination Configuration

    /// Number of rows from the end to trigger prefetch.
    static let prefetchRowThreshold = 3

    /// Debounce duration for pagination triggers (in seconds).
    static let paginationDebounce: TimeInterval = 0.3

    /// Target lookahead buffer size for "All" mode merge.
    static let mergeBufferLookahead = 40

    /// Maximum items to keep in memory.
    static let maxItemsInMemory = 500

    // MARK: - UI Configuration

    /// Number of columns in the poster grid.
    static let gridColumns = 5

    /// Poster aspect ratio (width:height as 2:3).
    static let posterAspectRatio: CGFloat = 2.0 / 3.0

    /// Corner radius for poster cards.
    static let posterCornerRadius: CGFloat = 12.0

    /// Scale factor for focused poster cards.
    static let focusScaleFactor: CGFloat = 1.08

    /// Debounce duration for accessibility announcements (in seconds).
    static let accessibilityAnnounceDebounce: TimeInterval = 0.5

    // MARK: - Filter Configuration

    /// Minimum vote count required for rating-based sorting.
    static let minimumVoteCountForRating = 50

    /// US region code for certification filtering.
    static let certificationRegion = "US"

    /// Available US movie certifications.
    static let movieCertifications = ["G", "PG", "PG-13", "R", "NC-17"]

    // MARK: - YouTube Server Configuration

    /// Base URL for the local YouTube extraction server.
    /// This server runs on your Mac and extracts direct video URLs using yt-dlp.
    ///
    /// To set up:
    /// 1. Run `python3 Server/yt_server.py` on your Mac
    /// 2. Update this URL with your Mac's IP address
    ///
    /// Example: "http://192.168.1.100:5000"
    static var youtubeServerURL: String {
        // Try to read from Info.plist first (for easy configuration)
        if let serverURL = Bundle.main.infoDictionary?["YOUTUBE_SERVER_URL"] as? String,
           !serverURL.isEmpty,
           !serverURL.hasPrefix("$(") {
            return serverURL
        }

        // Default fallback - update this with your Mac's IP
        // Find your Mac's IP: System Settings > Network, or run `ifconfig | grep inet`
        return "http://192.168.50.192:8080"
    }

    /// Preferred video quality for in-app playback.
    /// Options: "best", "1080", "720", "480", "worst"
    static let youtubePreferredQuality = "best"

    // MARK: - Helper Methods

    /// Constructs a full URL for a poster image.
    ///
    /// - Parameters:
    ///   - path: The poster path from TMDB (e.g., "/abc123.jpg")
    ///   - size: The desired poster size
    /// - Returns: Full URL to the poster image, or nil if path is nil
    static func posterURL(path: String?, size: PosterSize = .grid) -> URL? {
        guard let path = path else { return nil }
        return tmdbImageBaseURL.appendingPathComponent(size.rawValue).appendingPathComponent(path)
    }

    /// Constructs a full URL for a backdrop image.
    ///
    /// - Parameters:
    ///   - path: The backdrop path from TMDB (e.g., "/xyz789.jpg")
    ///   - size: The desired backdrop size
    /// - Returns: Full URL to the backdrop image, or nil if path is nil
    static func backdropURL(path: String?, size: BackdropSize = .detail) -> URL? {
        guard let path = path else { return nil }
        return tmdbImageBaseURL.appendingPathComponent(size.rawValue).appendingPathComponent(path)
    }
}
