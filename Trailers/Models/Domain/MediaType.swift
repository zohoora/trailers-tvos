// MARK: - MediaType.swift
// Trailers - tvOS App
// Media type enumeration for movies and TV shows

import Foundation

/// Represents the type of media content.
///
/// ## Overview
/// MediaType is used throughout the app to distinguish between movies and TV shows.
/// It affects:
/// - API endpoint selection
/// - Genre list usage
/// - Certification/rating display
/// - Runtime formatting
///
/// ## Usage
/// ```swift
/// let type: MediaType = .movie
/// print(type.displayName) // "Movie"
/// print(type.tmdbPathComponent) // "movie"
/// ```
enum MediaType: String, Codable, Hashable, Sendable, CaseIterable {
    /// A theatrical movie.
    case movie

    /// A TV series.
    case tv

    // MARK: - Display Properties

    /// Human-readable display name for UI.
    ///
    /// - Returns: "Movie" or "TV Show"
    var displayName: String {
        switch self {
        case .movie:
            return "Movie"
        case .tv:
            return "TV Show"
        }
    }

    /// Short badge text for grid display.
    ///
    /// - Returns: "MOVIE" or "TV"
    var badgeText: String {
        switch self {
        case .movie:
            return Constants.UIStrings.movieBadge
        case .tv:
            return Constants.UIStrings.tvBadge
        }
    }

    // MARK: - API Properties

    /// TMDB API path component for this media type.
    ///
    /// - Returns: "movie" or "tv"
    var tmdbPathComponent: String {
        rawValue
    }

    /// TMDB discover endpoint path for this media type.
    ///
    /// - Returns: "/discover/movie" or "/discover/tv"
    var discoverPath: String {
        "/discover/\(rawValue)"
    }

    /// TMDB trending endpoint path for this media type.
    ///
    /// - Returns: "/trending/movie/week" or "/trending/tv/week"
    var trendingPath: String {
        "/trending/\(rawValue)/week"
    }

    /// TMDB detail endpoint path for this media type.
    ///
    /// - Parameter id: The media ID
    /// - Returns: "/movie/{id}" or "/tv/{id}"
    func detailPath(id: Int) -> String {
        "/\(rawValue)/\(id)"
    }

    /// TMDB genre list endpoint path for this media type.
    ///
    /// - Returns: "/genre/movie/list" or "/genre/tv/list"
    var genreListPath: String {
        "/genre/\(rawValue)/list"
    }

    // MARK: - Date Field Names

    /// The date field name used in discover API for this media type.
    ///
    /// - Returns: "primary_release_date" for movies, "first_air_date" for TV
    var dateFieldName: String {
        switch self {
        case .movie:
            return "primary_release_date"
        case .tv:
            return "first_air_date"
        }
    }

    /// Sort parameter for release date newest.
    var releaseDateNewestSort: String {
        "\(dateFieldName).desc"
    }

    /// Sort parameter for release date oldest.
    var releaseDateOldestSort: String {
        "\(dateFieldName).asc"
    }

    // MARK: - Append to Response

    /// Additional data to request in detail API calls.
    ///
    /// - Returns: "release_dates,videos" for movies, "content_ratings,videos" for TV
    var appendToResponse: String {
        switch self {
        case .movie:
            return "release_dates,videos"
        case .tv:
            return "content_ratings,videos"
        }
    }
}

// MARK: - Identifiable

extension MediaType: Identifiable {
    var id: String { rawValue }
}

// MARK: - CustomStringConvertible

extension MediaType: CustomStringConvertible {
    var description: String { displayName }
}
