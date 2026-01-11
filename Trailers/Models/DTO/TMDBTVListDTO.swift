// MARK: - TMDBTVListDTO.swift
// Trailers - tvOS App
// DTO for TV show list items from TMDB trending/discover endpoints

import Foundation

/// DTO for TV show items in list responses (trending, discover).
///
/// ## Overview
/// This DTO matches the TV show objects returned by:
/// - `/trending/tv/week`
/// - `/discover/tv`
///
/// ## Key Differences from Movies
/// - Uses `name` instead of `title`
/// - Uses `first_air_date` instead of `release_date`
/// - Uses `origin_country` array instead of single country
///
/// ## Mapping to Domain Model
/// Use `toMediaSummary()` to convert to the app's domain model.
///
/// ## JSON Example
/// ```json
/// {
///   "id": 67890,
///   "name": "Breaking Bad",
///   "original_name": "Breaking Bad",
///   "poster_path": "/abc123.jpg",
///   "backdrop_path": "/xyz789.jpg",
///   "overview": "A high school chemistry teacher...",
///   "first_air_date": "2008-01-20",
///   "vote_average": 9.5,
///   "vote_count": 10000,
///   "genre_ids": [18, 80],
///   "popularity": 200.5,
///   "origin_country": ["US"],
///   "original_language": "en"
/// }
/// ```
struct TMDBTVListDTO: Decodable, Sendable {

    // MARK: - Properties

    /// TMDB TV show ID.
    let id: Int

    /// TV show name.
    let name: String

    /// Original name (may differ from localized name).
    let originalName: String?

    /// Path to poster image (e.g., "/abc123.jpg").
    let posterPath: String?

    /// Path to backdrop image.
    let backdropPath: String?

    /// TV show synopsis/description.
    let overview: String?

    /// First air date (YYYY-MM-DD format).
    let firstAirDate: String?

    /// Average vote score (0-10).
    let voteAverage: Double?

    /// Number of votes.
    let voteCount: Int?

    /// Array of genre IDs.
    let genreIds: [Int]?

    /// Popularity score.
    let popularity: Double?

    /// Origin country codes.
    let originCountry: [String]?

    /// Original language code.
    let originalLanguage: String?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case originalName = "original_name"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case overview
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genreIds = "genre_ids"
        case popularity
        case originCountry = "origin_country"
        case originalLanguage = "original_language"
    }

    // MARK: - Domain Mapping

    /// Converts this DTO to a MediaSummary domain model.
    ///
    /// - Returns: MediaSummary with TV type
    func toMediaSummary() -> MediaSummary {
        MediaSummary(
            id: MediaID(type: .tv, id: id),
            title: name,
            posterPath: posterPath,
            backdropPath: backdropPath,
            overview: overview ?? "",
            releaseDate: DateUtils.parseDate(firstAirDate),
            voteAverage: voteAverage,
            voteCount: voteCount,
            genreIDs: genreIds ?? [],
            popularity: popularity,
            originalLanguage: originalLanguage
        )
    }
}

// MARK: - Identifiable

extension TMDBTVListDTO: Identifiable {}

// MARK: - Custom String Convertible

extension TMDBTVListDTO: CustomStringConvertible {
    var description: String {
        "\(name) (TV #\(id))"
    }
}
