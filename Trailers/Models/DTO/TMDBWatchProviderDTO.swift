// MARK: - TMDBWatchProviderDTO.swift
// Trailers - tvOS App
// DTO for watch provider objects in TMDB responses

import Foundation

/// DTO for watch providers response from TMDB.
///
/// ## Overview
/// This DTO matches the response from the watch/providers endpoint.
/// Results are organized by country code.
///
/// ## JSON Example
/// ```json
/// {
///   "id": 27205,
///   "results": {
///     "CA": {
///       "link": "https://www.themoviedb.org/movie/27205/watch?locale=CA",
///       "flatrate": [...],
///       "rent": [...],
///       "buy": [...]
///     }
///   }
/// }
/// ```
struct TMDBWatchProvidersResponseDTO: Decodable, Sendable {

    /// The media ID.
    let id: Int

    /// Results by country code.
    let results: [String: TMDBWatchProviderCountryDTO]
}

/// DTO for a country's watch provider data.
struct TMDBWatchProviderCountryDTO: Decodable, Sendable {

    /// Link to TMDB/JustWatch page.
    let link: String?

    /// Subscription streaming providers.
    let flatrate: [TMDBWatchProviderDTO]?

    /// Rental providers.
    let rent: [TMDBWatchProviderDTO]?

    /// Purchase providers.
    let buy: [TMDBWatchProviderDTO]?

    // MARK: - Domain Mapping

    /// Converts to domain WatchProvidersResult.
    func toWatchProvidersResult() -> WatchProvidersResult {
        WatchProvidersResult(
            streaming: flatrate?.map { $0.toWatchProvider() } ?? [],
            rent: rent?.map { $0.toWatchProvider() } ?? [],
            buy: buy?.map { $0.toWatchProvider() } ?? [],
            link: link
        )
    }
}

/// DTO for a single watch provider.
struct TMDBWatchProviderDTO: Decodable, Sendable {

    /// The provider ID.
    let providerId: Int

    /// The provider name.
    let providerName: String

    /// Path to the logo image.
    let logoPath: String?

    /// Display priority (lower = more prominent).
    let displayPriority: Int

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
        case displayPriority = "display_priority"
    }

    // MARK: - Domain Mapping

    /// Converts to domain WatchProvider model.
    func toWatchProvider() -> WatchProvider {
        WatchProvider(
            id: providerId,
            name: providerName,
            logoPath: logoPath,
            displayPriority: displayPriority
        )
    }
}
