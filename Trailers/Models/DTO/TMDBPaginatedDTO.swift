// MARK: - TMDBPaginatedDTO.swift
// Trailers - tvOS App
// Generic paginated response wrapper for TMDB API

import Foundation

/// Generic wrapper for paginated TMDB API responses.
///
/// ## Overview
/// Most TMDB list endpoints return paginated responses with this structure:
/// ```json
/// {
///   "page": 1,
///   "total_pages": 100,
///   "total_results": 2000,
///   "results": [...]
/// }
/// ```
///
/// ## Usage
/// ```swift
/// let response: TMDBPaginatedDTO<TMDBMovieListDTO> = try decoder.decode(...)
/// print(response.page) // 1
/// print(response.results.count) // 20
/// print(response.hasMorePages) // true
/// ```
struct TMDBPaginatedDTO<T: Decodable>: Decodable {

    // MARK: - Properties

    /// Current page number (1-indexed).
    let page: Int

    /// Total number of pages available.
    let totalPages: Int

    /// Total number of results across all pages.
    let totalResults: Int

    /// Results for this page.
    let results: [T]

    // MARK: - Computed Properties

    /// Returns true if there are more pages after this one.
    var hasMorePages: Bool {
        page < totalPages
    }

    /// Returns true if this is the first page.
    var isFirstPage: Bool {
        page == 1
    }

    /// Returns true if this is the last page.
    var isLastPage: Bool {
        page >= totalPages
    }

    /// The next page number, or nil if this is the last page.
    var nextPage: Int? {
        hasMorePages ? page + 1 : nil
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case page
        case totalPages = "total_pages"
        case totalResults = "total_results"
        case results
    }
}

// MARK: - Sendable

extension TMDBPaginatedDTO: Sendable where T: Sendable {}

// MARK: - Custom String Convertible

extension TMDBPaginatedDTO: CustomStringConvertible {
    var description: String {
        "Page \(page)/\(totalPages) (\(results.count) items, \(totalResults) total)"
    }
}
