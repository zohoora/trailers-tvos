// MARK: - TMDBMovieListDTO.swift
// Trailers - tvOS App
// DTO for movie list items from TMDB trending/discover endpoints

import Foundation

/// DTO for movie items in list responses (trending, discover).
///
/// ## Overview
/// This DTO matches the movie objects returned by:
/// - `/trending/movie/week`
/// - `/discover/movie`
///
/// ## Mapping to Domain Model
/// Use `toMediaSummary()` to convert to the app's domain model.
///
/// ## JSON Example
/// ```json
/// {
///   "id": 12345,
///   "title": "Inception",
///   "original_title": "Inception",
///   "poster_path": "/abc123.jpg",
///   "backdrop_path": "/xyz789.jpg",
///   "overview": "A thief who steals...",
///   "release_date": "2010-07-16",
///   "vote_average": 8.8,
///   "vote_count": 30000,
///   "genre_ids": [28, 878, 53],
///   "popularity": 100.5,
///   "adult": false,
///   "video": false,
///   "original_language": "en"
/// }
/// ```
struct TMDBMovieListDTO: Decodable, Sendable {

    // MARK: - Properties

    /// TMDB movie ID.
    let id: Int

    /// Movie title.
    let title: String

    /// Original title (may differ from localized title).
    let originalTitle: String?

    /// Path to poster image (e.g., "/abc123.jpg").
    let posterPath: String?

    /// Path to backdrop image.
    let backdropPath: String?

    /// Movie synopsis/description.
    let overview: String?

    /// Theatrical release date (YYYY-MM-DD format).
    let releaseDate: String?

    /// Average vote score (0-10).
    let voteAverage: Double?

    /// Number of votes.
    let voteCount: Int?

    /// Array of genre IDs.
    let genreIds: [Int]?

    /// Popularity score.
    let popularity: Double?

    /// Whether this is adult content.
    let adult: Bool?

    /// Original language code.
    let originalLanguage: String?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case originalTitle = "original_title"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case overview
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genreIds = "genre_ids"
        case popularity
        case adult
        case originalLanguage = "original_language"
    }

    // MARK: - Domain Mapping

    /// Converts this DTO to a MediaSummary domain model.
    ///
    /// - Returns: MediaSummary with movie type
    func toMediaSummary() -> MediaSummary {
        MediaSummary(
            id: MediaID(type: .movie, id: id),
            title: title,
            posterPath: posterPath,
            backdropPath: backdropPath,
            overview: overview ?? "",
            releaseDate: DateUtils.parseDate(releaseDate),
            voteAverage: voteAverage,
            voteCount: voteCount,
            genreIDs: genreIds ?? [],
            popularity: popularity,
            originalLanguage: originalLanguage
        )
    }
}

// MARK: - Identifiable

extension TMDBMovieListDTO: Identifiable {}

// MARK: - Custom String Convertible

extension TMDBMovieListDTO: CustomStringConvertible {
    var description: String {
        "\(title) (Movie #\(id))"
    }
}
