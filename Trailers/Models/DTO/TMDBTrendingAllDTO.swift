// MARK: - TMDBTrendingAllDTO.swift
// Trailers - tvOS App
// DTO for trending/all endpoint that may return people (which we skip)

import Foundation

/// Result item from the `/trending/all/week` endpoint.
///
/// ## Overview
/// The trending/all endpoint returns a mixed array of movies, TV shows, and people.
/// This enum handles the polymorphic decoding and allows us to skip people results.
///
/// ## Important
/// The decoder MUST tolerate unknown media types and skip them rather than failing.
/// This is critical because TMDB may add new media types in the future.
///
/// ## JSON Structure
/// Each result has a `media_type` field:
/// ```json
/// {
///   "media_type": "movie",  // or "tv" or "person"
///   // ... type-specific fields
/// }
/// ```
enum TMDBTrendingAllResult: Decodable, Sendable {

    /// A movie result.
    case movie(TMDBMovieListDTO)

    /// A TV show result.
    case tv(TMDBTVListDTO)

    /// An unsupported media type (person or unknown).
    /// These are silently skipped when converting to domain models.
    case unsupported

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
    }

    // MARK: - Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mediaType = try container.decode(String.self, forKey: .mediaType)

        switch mediaType {
        case "movie":
            // Decode as movie DTO
            let movieDTO = try TMDBMovieListDTO(from: decoder)
            self = .movie(movieDTO)

        case "tv":
            // Decode as TV DTO
            let tvDTO = try TMDBTVListDTO(from: decoder)
            self = .tv(tvDTO)

        default:
            // Unknown media type (person, etc.) - skip it
            Log.data.debug("Skipping unsupported media type: \(mediaType)")
            self = .unsupported
        }
    }

    // MARK: - Domain Mapping

    /// Converts to MediaSummary if this is a movie or TV result.
    ///
    /// - Returns: MediaSummary, or nil for unsupported types
    func toMediaSummary() -> MediaSummary? {
        switch self {
        case .movie(let dto):
            return dto.toMediaSummary()
        case .tv(let dto):
            return dto.toMediaSummary()
        case .unsupported:
            return nil
        }
    }

    /// Returns true if this is a supported media type (movie or TV).
    var isSupported: Bool {
        switch self {
        case .movie, .tv:
            return true
        case .unsupported:
            return false
        }
    }

    /// Returns the media type if supported.
    var mediaType: MediaType? {
        switch self {
        case .movie:
            return .movie
        case .tv:
            return .tv
        case .unsupported:
            return nil
        }
    }
}

// MARK: - Paginated Response Alias

/// Type alias for paginated trending/all response.
typealias TMDBTrendingAllResponse = TMDBPaginatedDTO<TMDBTrendingAllResult>

// MARK: - Response Extension

extension TMDBPaginatedDTO where T == TMDBTrendingAllResult {

    /// Converts all supported results to MediaSummary, skipping unsupported types.
    ///
    /// - Returns: Array of MediaSummary (excluding people and unknown types)
    func toMediaSummaries() -> [MediaSummary] {
        results.compactMap { $0.toMediaSummary() }
    }

    /// Count of supported results (movies + TV shows).
    var supportedCount: Int {
        results.filter { $0.isSupported }.count
    }

    /// Count of unsupported results (people, etc.).
    var unsupportedCount: Int {
        results.filter { !$0.isSupported }.count
    }
}

// MARK: - Array Extension

extension Array where Element == TMDBTrendingAllResult {

    /// Filters to only movie results.
    var movies: [TMDBMovieListDTO] {
        compactMap {
            if case .movie(let dto) = $0 {
                return dto
            }
            return nil
        }
    }

    /// Filters to only TV results.
    var tvShows: [TMDBTVListDTO] {
        compactMap {
            if case .tv(let dto) = $0 {
                return dto
            }
            return nil
        }
    }

    /// Converts all supported items to MediaSummary.
    var mediaItems: [MediaSummary] {
        compactMap { $0.toMediaSummary() }
    }
}
