// MARK: - MediaSummary.swift
// Trailers - tvOS App
// Summary model for media items displayed in the grid

import Foundation

/// A summary of a media item for display in the poster grid.
///
/// ## Overview
/// MediaSummary contains the essential information needed to display a poster
/// card in the grid. It's lighter than MediaDetail and is used for list views.
///
/// ## Data Sources
/// MediaSummary is created from:
/// - Trending endpoint responses
/// - Discover endpoint responses
///
/// ## Usage
/// ```swift
/// let summary = MediaSummary(from: tmdbMovie)
/// print(summary.title) // "Inception"
/// print(summary.yearText) // "2010"
/// print(summary.ratingDisplay) // "8.8"
/// ```
struct MediaSummary: Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// The unique identifier combining type and TMDB ID.
    let id: MediaID

    /// The title (movie title or TV show name).
    let title: String

    /// Path to the poster image (e.g., "/abc123.jpg").
    let posterPath: String?

    /// Path to the backdrop image (e.g., "/xyz789.jpg").
    let backdropPath: String?

    /// Short description/synopsis of the media.
    let overview: String

    /// Release date for movies, first air date for TV shows.
    let releaseDate: Date?

    /// Average vote rating from TMDB (0-10 scale).
    let voteAverage: Double?

    /// Number of votes/ratings.
    let voteCount: Int?

    /// Array of genre IDs associated with this media.
    let genreIDs: [Int]

    /// Popularity score from TMDB (used for sorting).
    let popularity: Double?

    // MARK: - Computed Properties

    /// The media type (movie or TV).
    var mediaType: MediaType {
        id.type
    }

    /// Year text for display ("2025" or "TBA").
    var yearText: String {
        DateUtils.yearString(from: releaseDate)
    }

    /// Formatted rating for display ("8.8" or "-").
    var ratingDisplay: String {
        guard let rating = voteAverage, rating > 0 else {
            return Constants.UIStrings.ratingNotAvailable
        }
        return String(format: "%.1f", rating)
    }

    /// Full rating text with star ("★ 8.8").
    var ratingWithStar: String {
        "★ \(ratingDisplay)"
    }

    /// Full poster URL using the grid size.
    var posterURL: URL? {
        Config.posterURL(path: posterPath, size: .grid)
    }

    /// Full backdrop URL using the detail size.
    var backdropURL: URL? {
        Config.backdropURL(path: backdropPath, size: .detail)
    }

    /// Badge text for media type ("MOVIE" or "TV").
    var typeBadge: String {
        mediaType.badgeText
    }

    /// Accessibility label for VoiceOver.
    ///
    /// Format: "{Title}, {Year}, rated {Score} out of 10, {Movie|TV}"
    var accessibilityLabel: String {
        let typeLabel = mediaType == .movie ?
            Constants.Accessibility.movieType :
            Constants.Accessibility.tvShowType

        return String(
            format: Constants.Accessibility.posterCardFormat,
            title,
            yearText,
            ratingDisplay,
            typeLabel
        )
    }

    /// Returns true if this item has a poster image.
    var hasPoster: Bool {
        posterPath != nil
    }

    /// Returns true if this item has a backdrop image.
    var hasBackdrop: Bool {
        backdropPath != nil
    }

    // MARK: - Sorting Helpers

    /// Compares this item to another for popularity sorting.
    ///
    /// - Parameters:
    ///   - other: The other item to compare
    ///   - ascending: If true, less popular first
    /// - Returns: True if this item should come before other
    func compareByPopularity(to other: MediaSummary, ascending: Bool) -> Bool {
        let pop1 = popularity ?? 0
        let pop2 = other.popularity ?? 0
        return ascending ? pop1 < pop2 : pop1 > pop2
    }

    /// Compares this item to another for rating sorting.
    ///
    /// - Parameters:
    ///   - other: The other item to compare
    ///   - ascending: If true, lower ratings first
    /// - Returns: True if this item should come before other
    func compareByRating(to other: MediaSummary, ascending: Bool) -> Bool {
        let rating1 = voteAverage ?? (ascending ? Double.infinity : 0)
        let rating2 = other.voteAverage ?? (ascending ? Double.infinity : 0)
        return ascending ? rating1 < rating2 : rating1 > rating2
    }

    /// Compares this item to another for date sorting.
    ///
    /// - Parameters:
    ///   - other: The other item to compare
    ///   - ascending: If true, older dates first (oldest)
    /// - Returns: True if this item should come before other
    func compareByDate(to other: MediaSummary, ascending: Bool) -> Bool {
        DateUtils.compareDates(releaseDate, other.releaseDate, ascending: ascending)
    }
}

// MARK: - Init from MediaDetail

extension MediaSummary {
    /// Creates a summary from a detail model.
    ///
    /// - Parameter detail: The detail model to convert
    init(from detail: MediaDetail) {
        self.id = detail.id
        self.title = detail.title
        self.posterPath = detail.posterPath
        self.backdropPath = detail.backdropPath
        self.overview = detail.overview
        self.releaseDate = detail.releaseDate
        self.voteAverage = detail.voteAverage
        self.voteCount = detail.voteCount
        self.genreIDs = detail.genres.map { $0.id }
        self.popularity = detail.popularity
    }
}

// MARK: - Codable

extension MediaSummary: Codable {}

// MARK: - Custom String Convertible

extension MediaSummary: CustomStringConvertible {
    var description: String {
        "\(title) (\(yearText)) - \(mediaType.displayName)"
    }
}

// MARK: - Equatable (by ID only)

extension MediaSummary {
    /// Two summaries are equal if they have the same MediaID.
    ///
    /// This is used for deduplication in the grid.
    static func == (lhs: MediaSummary, rhs: MediaSummary) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Merge Comparator

/// Comparator for merging movie and TV results in "All" mode.
///
/// ## Comparison Order
/// 1. Primary: chosen sort field
/// 2. Tie-breaker 1: popularity descending
/// 3. Tie-breaker 2: media type (movies before TV)
/// 4. Tie-breaker 3: ID ascending
enum MediaSummaryComparator {

    /// Compares two media summaries for merge sorting.
    ///
    /// - Parameters:
    ///   - a: First item
    ///   - b: Second item
    ///   - sort: The active sort option
    /// - Returns: True if a should come before b
    static func compare(_ a: MediaSummary, _ b: MediaSummary, sort: SortOption) -> Bool {
        // Primary comparison based on sort
        switch sort {
        case .trending, .popularity:
            // For popularity (and trending which uses same logic for merged results)
            if (a.popularity ?? 0) != (b.popularity ?? 0) {
                return (a.popularity ?? 0) > (b.popularity ?? 0)
            }

        case .releaseDateNewest:
            let dateComparison = DateUtils.compareDates(a.releaseDate, b.releaseDate, ascending: false)
            if a.releaseDate != b.releaseDate {
                return dateComparison
            }

        case .releaseDateOldest:
            let dateComparison = DateUtils.compareDates(a.releaseDate, b.releaseDate, ascending: true)
            if a.releaseDate != b.releaseDate {
                return dateComparison
            }

        case .ratingHighest:
            let rating1 = a.voteAverage ?? 0
            let rating2 = b.voteAverage ?? 0
            if rating1 != rating2 {
                return rating1 > rating2
            }

        case .ratingLowest:
            let rating1 = a.voteAverage ?? Double.infinity
            let rating2 = b.voteAverage ?? Double.infinity
            if rating1 != rating2 {
                return rating1 < rating2
            }
        }

        // Tie-breaker 1: popularity descending
        if (a.popularity ?? 0) != (b.popularity ?? 0) {
            return (a.popularity ?? 0) > (b.popularity ?? 0)
        }

        // Tie-breaker 2: movies before TV
        if a.id.type != b.id.type {
            return a.id.type == .movie
        }

        // Tie-breaker 3: ID ascending
        return a.id.id < b.id.id
    }
}

// MARK: - Array Extensions

extension Array where Element == MediaSummary {

    /// Deduplicates items by MediaID, keeping the first occurrence.
    var deduplicated: [MediaSummary] {
        var seen = Set<MediaID>()
        return filter { item in
            if seen.contains(item.id) {
                return false
            }
            seen.insert(item.id)
            return true
        }
    }

    /// Sorts items using the merge comparator.
    ///
    /// - Parameter sort: The sort option to use
    /// - Returns: Sorted array
    func sorted(by sort: SortOption) -> [MediaSummary] {
        sorted { MediaSummaryComparator.compare($0, $1, sort: sort) }
    }
}
