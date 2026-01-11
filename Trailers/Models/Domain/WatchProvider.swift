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
        case 8: return .netflix           // Netflix
        case 337: return .disneyPlus      // Disney Plus
        case 9, 10, 119: return .amazonPrime  // Amazon Prime Video variants
        case 2, 350: return .appleTv      // Apple TV, Apple TV Plus
        case 230: return .crave           // Crave
        case 531: return .paramountPlus   // Paramount Plus
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
