// MARK: - WatchProvider.swift
// Trailers - tvOS App
// Watch provider model for streaming availability

import Foundation

/// Represents a streaming service where content is available.
///
/// ## Overview
/// WatchProvider contains information about where a movie or TV show
/// can be streamed, rented, or purchased. Data is sourced from JustWatch
/// via TMDB's API.
///
/// ## Provider Types
/// - `flatrate`: Subscription streaming (Netflix, Disney+, etc.)
/// - `rent`: Available for rental
/// - `buy`: Available for purchase
///
/// ## Usage
/// ```swift
/// let providers = await viewModel.watchProviders
/// for provider in providers.streaming {
///     StreamingLauncher.open(provider: provider, title: movieTitle)
/// }
/// ```
struct WatchProvider: Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// The unique provider ID from TMDB.
    let id: Int

    /// The provider name (e.g., "Netflix", "Disney Plus").
    let name: String

    /// Path to the provider logo image.
    let logoPath: String?

    /// Display priority (lower = more prominent).
    let displayPriority: Int

    // MARK: - Computed Properties

    /// The full URL for the provider logo.
    var logoURL: URL? {
        Config.posterURL(path: logoPath, size: .w154)
    }

    /// Returns the streaming service type for deep linking.
    var serviceType: StreamingService? {
        StreamingService.from(providerID: id)
    }

    /// Whether this provider supports deep linking.
    var supportsDeepLink: Bool {
        serviceType != nil
    }
}

// MARK: - Codable

extension WatchProvider: Codable {}

// MARK: - Streaming Service

/// Known streaming services with deep link support.
enum StreamingService: String, CaseIterable, Sendable {
    case netflix
    case disneyPlus
    case amazonPrime
    case appleTv
    case crave
    case paramountPlus
    case hulu

    /// Maps TMDB provider ID to streaming service.
    static func from(providerID: Int) -> StreamingService? {
        switch providerID {
        case 8, 1796: return .netflix     // Netflix, Netflix basic with Ads
        case 337, 390: return .disneyPlus // Disney Plus, Disney Plus Basic
        case 9, 10, 119, 1899, 1968, 2100: return .amazonPrime  // Amazon Prime Video variants
        case 2, 350: return .appleTv      // Apple TV, Apple TV Plus
        case 230: return .crave           // Crave
        case 531, 582, 1770, 1853, 2099, 675: return .paramountPlus   // Paramount+ variants
        case 15: return .hulu             // Hulu
        default: return nil
        }
    }

    /// The URL scheme for this streaming service on tvOS.
    var urlScheme: String {
        switch self {
        case .netflix: return "nflx"
        case .disneyPlus: return "disneyplus"
        case .amazonPrime: return "aiv"
        case .appleTv: return "videos"
        case .crave: return "crave"
        case .paramountPlus: return "paramountplus"
        case .hulu: return "hulu"
        }
    }

    /// Display name for the service.
    var displayName: String {
        switch self {
        case .netflix: return "Netflix"
        case .disneyPlus: return "Disney+"
        case .amazonPrime: return "Prime Video"
        case .appleTv: return "Apple TV"
        case .crave: return "Crave"
        case .paramountPlus: return "Paramount+"
        case .hulu: return "Hulu"
        }
    }
}

// MARK: - Watch Providers Result

/// Container for watch providers organized by availability type.
struct WatchProvidersResult: Sendable {

    /// Providers offering subscription streaming.
    let streaming: [WatchProvider]

    /// Providers offering rentals.
    let rent: [WatchProvider]

    /// Providers offering purchases.
    let buy: [WatchProvider]

    /// TMDB/JustWatch link for more info.
    let link: String?

    /// Whether any streaming providers are available.
    var hasStreaming: Bool {
        !streaming.isEmpty
    }

    /// Streaming providers deduplicated by service type or name.
    ///
    /// Multiple variants of the same service (e.g., Paramount+, Paramount+ with Showtime)
    /// are consolidated to a single entry, preferring the one with higher display priority.
    var deduplicatedStreaming: [WatchProvider] {
        var seenServices = Set<String>()
        var result: [WatchProvider] = []

        // Sort by display priority (lower = more prominent)
        let sorted = streaming.sorted { $0.displayPriority < $1.displayPriority }

        for provider in sorted {
            // Use streaming service type if known, otherwise normalize the name
            let key: String
            if let service = provider.serviceType {
                key = service.rawValue
            } else {
                // Aggressive name normalization to extract base service name
                key = Self.normalizeProviderName(provider.name)
            }

            if !seenServices.contains(key) {
                seenServices.insert(key)
                result.append(provider)
            }
        }

        return result
    }

    /// Normalizes a provider name to extract the base service name.
    ///
    /// Examples:
    /// - "Netflix basic with Ads" → "netflix"
    /// - "Amazon Prime Video" → "amazon"
    /// - "Prime Video" → "amazon" (via alias)
    /// - "Paramount+ with Showtime" → "paramount"
    private static func normalizeProviderName(_ name: String) -> String {
        var normalized = name.lowercased()

        // Remove common suffixes and qualifiers
        let removals = [
            " basic with ads", " with ads", " ads",
            " with showtime", " showtime",
            " plus", "+",
            " prime video", " prime", " video",
            " channel", " tv",
            " basic", " premium", " standard"
        ]

        for removal in removals {
            normalized = normalized.replacingOccurrences(of: removal, with: "")
        }

        // Take just the first word (base brand name)
        // e.g., "amazon prime video" → "amazon"
        var baseName: String
        if let firstWord = normalized.trimmingCharacters(in: .whitespaces).split(separator: " ").first {
            baseName = String(firstWord)
        } else {
            baseName = normalized.trimmingCharacters(in: .whitespaces)
        }

        // Map known aliases to canonical names
        let aliases: [String: String] = [
            "prime": "amazon",      // "Prime Video" → "amazon"
            "disney": "disneyplus", // "Disney+" variants
            "hbo": "max",           // HBO Max rebranded to Max
            "apple": "appletv"      // Apple TV variants
        ]

        return aliases[baseName] ?? baseName
    }

    /// Whether any providers are available at all.
    var hasAnyProvider: Bool {
        !streaming.isEmpty || !rent.isEmpty || !buy.isEmpty
    }

    /// All unique providers (streaming first, then rent, then buy).
    var allProviders: [WatchProvider] {
        var seen = Set<Int>()
        var result: [WatchProvider] = []

        for provider in streaming + rent + buy {
            if !seen.contains(provider.id) {
                seen.insert(provider.id)
                result.append(provider)
            }
        }

        return result
    }

    /// Empty result with no providers.
    static let empty = WatchProvidersResult(
        streaming: [],
        rent: [],
        buy: [],
        link: nil
    )
}
