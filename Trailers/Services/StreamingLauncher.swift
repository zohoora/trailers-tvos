// MARK: - StreamingLauncher.swift
// Trailers - tvOS App
// Service for launching streaming apps with search queries

import UIKit

/// Service for launching streaming apps on tvOS.
///
/// ## Overview
/// StreamingLauncher attempts to open streaming apps (Netflix, Disney+, etc.)
/// with a search query for the specified title. This provides a quick way
/// to find content on streaming services.
///
/// ## How It Works
/// 1. Constructs a URL scheme for the streaming service
/// 2. Attempts to open with a search query containing the title
/// 3. Falls back to just opening the app if search isn't supported
///
/// ## Supported Services
/// - Netflix: `nflx://`
/// - Disney+: `disneyplus://`
/// - Prime Video: `aiv://`
/// - Apple TV: `videos://`
/// - Crave: `crave://`
/// - Paramount+: `paramountplus://`
/// - Hulu: `hulu://`
///
/// ## Usage
/// ```swift
/// await StreamingLauncher.open(service: .netflix, title: "Inception")
/// ```
enum StreamingLauncher {

    // MARK: - Public API

    /// Opens a streaming service with a search for the given title.
    ///
    /// - Parameters:
    ///   - service: The streaming service to open
    ///   - title: The movie/show title to search for
    /// - Returns: True if the app was opened successfully
    @MainActor
    @discardableResult
    static func open(service: StreamingService, title: String) async -> Bool {
        let searchURL = searchURL(for: service, title: title)

        // Try search URL first
        if let url = searchURL, await openURL(url) {
            Log.app.info("Opened \(service.displayName) with search for: \(title)")
            return true
        }

        // Fall back to just opening the app
        if let appURL = appURL(for: service), await openURL(appURL) {
            Log.app.info("Opened \(service.displayName) app (no search)")
            return true
        }

        Log.app.warning("Failed to open \(service.displayName)")
        return false
    }

    /// Opens a streaming provider.
    ///
    /// - Parameters:
    ///   - provider: The watch provider to open
    ///   - title: The movie/show title to search for
    /// - Returns: True if the app was opened successfully
    @MainActor
    @discardableResult
    static func open(provider: WatchProvider, title: String) async -> Bool {
        guard let service = provider.serviceType else {
            Log.app.warning("No deep link support for provider: \(provider.name)")
            return false
        }

        return await open(service: service, title: title)
    }

    // MARK: - URL Construction

    /// Constructs a search URL for a streaming service.
    private static func searchURL(for service: StreamingService, title: String) -> URL? {
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        let urlString: String

        switch service {
        case .netflix:
            // Netflix search URL
            urlString = "nflx://www.netflix.com/search?q=\(encodedTitle)"

        case .disneyPlus:
            // Disney+ search
            urlString = "disneyplus://search?query=\(encodedTitle)"

        case .amazonPrime:
            // Prime Video search
            urlString = "aiv://aiv/search?searchString=\(encodedTitle)"

        case .appleTv:
            // Apple TV doesn't have a direct search scheme, use app URL
            return nil

        case .crave:
            // Crave search (if supported)
            urlString = "crave://search?q=\(encodedTitle)"

        case .paramountPlus:
            // Paramount+ search
            urlString = "paramountplus://search?q=\(encodedTitle)"

        case .hulu:
            // Hulu search
            urlString = "hulu://search?query=\(encodedTitle)"
        }

        return URL(string: urlString)
    }

    /// Constructs an app-open URL for a streaming service.
    private static func appURL(for service: StreamingService) -> URL? {
        URL(string: "\(service.urlScheme)://")
    }

    // MARK: - URL Opening

    /// Opens a URL on tvOS.
    @MainActor
    private static func openURL(_ url: URL) async -> Bool {
        let application = UIApplication.shared

        guard application.canOpenURL(url) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            application.open(url, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }
    }
}
