// MARK: - Genre.swift
// Trailers - tvOS App
// Genre model for categorizing media content

import Foundation

/// Represents a genre for categorizing movies and TV shows.
///
/// ## Overview
/// Genres come from TMDB's genre APIs and are used for filtering content.
/// Movie and TV genres have different IDs but often share names.
///
/// ## Genre Mapping
/// When filtering in "All" content type mode, genres must be mapped between
/// movie and TV IDs. Some genres have different IDs for the same name:
/// - Action: movie=28, tv=10759
/// - Sci-Fi: movie=878, tv=10765
/// - War: movie=10752, tv=10768
///
/// ## Usage
/// ```swift
/// let actionGenre = Genre(id: 28, name: "Action")
/// print(actionGenre.displayName) // "Action"
/// ```
struct Genre: Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// The TMDB genre ID.
    ///
    /// - Note: IDs differ between movies and TV for some genre names.
    let id: Int

    /// The genre name (e.g., "Action", "Comedy").
    let name: String

    // MARK: - Computed Properties

    /// Display name for UI (same as name).
    var displayName: String { name }
}

// MARK: - Codable

extension Genre: Codable {}

// MARK: - Equatable by Name

extension Genre {
    /// Checks if two genres have the same name (case-insensitive).
    ///
    /// This is useful for mapping genres between movie and TV lists.
    ///
    /// - Parameter other: The other genre to compare
    /// - Returns: True if the names match (case-insensitive)
    func hasSameName(as other: Genre) -> Bool {
        name.lowercased() == other.name.lowercased()
    }
}

// MARK: - Custom String Convertible

extension Genre: CustomStringConvertible {
    var description: String {
        "\(name) (\(id))"
    }
}

// MARK: - Genre Display Model

/// A unified genre for display in the filter UI when in "All" content type mode.
///
/// This model combines movie and TV genre IDs that share the same name,
/// allowing the filter to work across both content types.
struct GenreDisplay: Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// Unique identifier for SwiftUI (uses name for stability).
    var id: String { name }

    /// The display name for this genre.
    let name: String

    /// The movie genre ID, if this genre applies to movies.
    let movieGenreID: Int?

    /// The TV genre ID, if this genre applies to TV shows.
    let tvGenreID: Int?

    // MARK: - Computed Properties

    /// Returns true if this genre applies to movies.
    var appliesToMovies: Bool { movieGenreID != nil }

    /// Returns true if this genre applies to TV shows.
    var appliesToTV: Bool { tvGenreID != nil }

    /// Returns true if this genre applies to both movies and TV shows.
    var appliesToBoth: Bool { appliesToMovies && appliesToTV }

    // MARK: - Factory Methods

    /// Creates a GenreDisplay from a movie genre only.
    ///
    /// - Parameter genre: The movie genre
    /// - Returns: A GenreDisplay with only movie ID set
    static func fromMovie(_ genre: Genre) -> GenreDisplay {
        GenreDisplay(name: genre.name, movieGenreID: genre.id, tvGenreID: nil)
    }

    /// Creates a GenreDisplay from a TV genre only.
    ///
    /// - Parameter genre: The TV genre
    /// - Returns: A GenreDisplay with only TV ID set
    static func fromTV(_ genre: Genre) -> GenreDisplay {
        GenreDisplay(name: genre.name, movieGenreID: nil, tvGenreID: genre.id)
    }

    /// Creates a GenreDisplay combining movie and TV genres.
    ///
    /// - Parameters:
    ///   - movie: The movie genre (optional)
    ///   - tv: The TV genre (optional)
    ///   - name: The display name to use
    /// - Returns: A GenreDisplay with both IDs set where available
    static func combined(movie: Genre?, tv: Genre?, name: String) -> GenreDisplay {
        GenreDisplay(name: name, movieGenreID: movie?.id, tvGenreID: tv?.id)
    }
}

// MARK: - Genre Mapping

/// Utility for mapping genres between movie and TV lists.
///
/// ## Hardcoded Overrides
/// Some genres have the same meaning but different IDs between movies and TV.
/// These are handled with explicit mappings:
/// - Action: movie 28 ↔ tv 10759
/// - Sci-Fi/Science Fiction & Fantasy: movie 878 ↔ tv 10765
/// - War/War & Politics: movie 10752 ↔ tv 10768
enum GenreMapping {

    /// Known genre name mappings between movies and TV.
    ///
    /// Format: [Movie Genre Name: TV Genre Name]
    static let knownNameMappings: [String: String] = [
        "Science Fiction": "Sci-Fi & Fantasy",
        "War": "War & Politics"
    ]

    /// Hardcoded genre ID mappings for known mismatches.
    ///
    /// Format: [(movieID, tvID, displayName)]
    static let hardcodedMappings: [(movieID: Int, tvID: Int, name: String)] = [
        (28, 10759, "Action"),
        (878, 10765, "Sci-Fi"),
        (10752, 10768, "War")
    ]

    /// Creates a unified genre list from separate movie and TV genre lists.
    ///
    /// This function:
    /// 1. Matches genres by name (case-insensitive)
    /// 2. Applies hardcoded overrides for known mismatches
    /// 3. Includes genres unique to either list
    ///
    /// - Parameters:
    ///   - movieGenres: List of movie genres from TMDB
    ///   - tvGenres: List of TV genres from TMDB
    /// - Returns: Unified list of GenreDisplay items
    static func createUnifiedGenres(movieGenres: [Genre], tvGenres: [Genre]) -> [GenreDisplay] {
        var result: [GenreDisplay] = []
        var usedMovieIDs = Set<Int>()
        var usedTVIDs = Set<Int>()

        // First, apply hardcoded mappings
        for mapping in hardcodedMappings {
            let hasMovie = movieGenres.contains { $0.id == mapping.movieID }
            let hasTV = tvGenres.contains { $0.id == mapping.tvID }

            if hasMovie || hasTV {
                result.append(GenreDisplay(
                    name: mapping.name,
                    movieGenreID: hasMovie ? mapping.movieID : nil,
                    tvGenreID: hasTV ? mapping.tvID : nil
                ))
                if hasMovie { usedMovieIDs.insert(mapping.movieID) }
                if hasTV { usedTVIDs.insert(mapping.tvID) }
            }
        }

        // Match remaining genres by name
        for movieGenre in movieGenres where !usedMovieIDs.contains(movieGenre.id) {
            let matchingTV = tvGenres.first { tvGenre in
                !usedTVIDs.contains(tvGenre.id) &&
                tvGenre.name.lowercased() == movieGenre.name.lowercased()
            }

            result.append(GenreDisplay(
                name: movieGenre.name,
                movieGenreID: movieGenre.id,
                tvGenreID: matchingTV?.id
            ))

            usedMovieIDs.insert(movieGenre.id)
            if let tvID = matchingTV?.id {
                usedTVIDs.insert(tvID)
            }
        }

        // Add remaining TV-only genres
        for tvGenre in tvGenres where !usedTVIDs.contains(tvGenre.id) {
            result.append(GenreDisplay(
                name: tvGenre.name,
                movieGenreID: nil,
                tvGenreID: tvGenre.id
            ))
        }

        // Sort alphabetically
        return result.sorted { $0.name < $1.name }
    }
}
