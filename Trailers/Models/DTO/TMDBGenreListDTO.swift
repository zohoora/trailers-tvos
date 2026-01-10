// MARK: - TMDBGenreListDTO.swift
// Trailers - tvOS App
// DTO for genre list endpoint responses

import Foundation

/// DTO for individual genre in TMDB responses.
///
/// ## Overview
/// This DTO matches genre objects in both list and detail responses.
///
/// ## JSON Example
/// ```json
/// {"id": 28, "name": "Action"}
/// ```
struct TMDBGenreDTO: Decodable, Sendable, Identifiable {

    // MARK: - Properties

    /// TMDB genre ID.
    let id: Int

    /// Genre name (e.g., "Action", "Comedy").
    let name: String

    // MARK: - Domain Mapping

    /// Converts to domain Genre model.
    func toGenre() -> Genre {
        Genre(id: id, name: name)
    }
}

/// DTO for genre list response from `/genre/{type}/list` endpoints.
///
/// ## Overview
/// This DTO matches the response from:
/// - `/genre/movie/list`
/// - `/genre/tv/list`
///
/// ## JSON Example
/// ```json
/// {
///   "genres": [
///     {"id": 28, "name": "Action"},
///     {"id": 12, "name": "Adventure"},
///     {"id": 16, "name": "Animation"}
///   ]
/// }
/// ```
struct TMDBGenreListDTO: Decodable, Sendable {

    // MARK: - Properties

    /// Array of genre objects.
    let genres: [TMDBGenreDTO]

    // MARK: - Domain Mapping

    /// Converts all genres to domain Genre models.
    func toGenres() -> [Genre] {
        genres.map { $0.toGenre() }
    }
}

// MARK: - Array Extension

extension Array where Element == TMDBGenreDTO {

    /// Converts all DTOs to domain Genre models.
    var asDomainModels: [Genre] {
        map { $0.toGenre() }
    }
}
