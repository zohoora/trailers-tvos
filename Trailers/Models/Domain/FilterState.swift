// MARK: - FilterState.swift
// Trailers - tvOS App
// Filter state management with business rule enforcement

import Foundation

// MARK: - Content Type

/// Content type filter options.
///
/// Determines which media types to include in results.
enum ContentType: String, CaseIterable, Identifiable, Sendable {
    /// Show both movies and TV shows.
    case all

    /// Show only movies.
    case movies

    /// Show only TV shows.
    case tvShows

    var id: String { rawValue }

    /// Display label for UI.
    var displayName: String {
        switch self {
        case .all:
            return Constants.FilterLabels.contentTypeAll
        case .movies:
            return Constants.FilterLabels.contentTypeMovies
        case .tvShows:
            return Constants.FilterLabels.contentTypeTVShows
        }
    }

    /// Returns the media type if this is a single-type filter.
    var singleType: MediaType? {
        switch self {
        case .all:
            return nil
        case .movies:
            return .movie
        case .tvShows:
            return .tv
        }
    }

    /// Returns true if this includes movies.
    var includesMovies: Bool {
        self == .all || self == .movies
    }

    /// Returns true if this includes TV shows.
    var includesTV: Bool {
        self == .all || self == .tvShows
    }
}

// MARK: - Sort Option

/// Sort order options for content.
enum SortOption: String, CaseIterable, Identifiable, Sendable {
    /// Trending content (uses trending endpoints).
    case trending

    /// Most popular first.
    case popularity

    /// Newest releases first.
    case releaseDateNewest

    /// Oldest releases first.
    case releaseDateOldest

    /// Highest rated first.
    case ratingHighest

    /// Lowest rated first.
    case ratingLowest

    var id: String { rawValue }

    /// Display label for UI.
    var displayName: String {
        switch self {
        case .trending:
            return Constants.FilterLabels.sortTrending
        case .popularity:
            return Constants.FilterLabels.sortPopularity
        case .releaseDateNewest:
            return Constants.FilterLabels.sortReleaseDateNewest
        case .releaseDateOldest:
            return Constants.FilterLabels.sortReleaseDateOldest
        case .ratingHighest:
            return Constants.FilterLabels.sortRatingHighest
        case .ratingLowest:
            return Constants.FilterLabels.sortRatingLowest
        }
    }

    /// TMDB sort_by parameter value for discover endpoints.
    ///
    /// - Parameter mediaType: The media type (affects date field name)
    /// - Returns: Sort parameter value, or nil for trending
    func sortByParameter(for mediaType: MediaType) -> String? {
        switch self {
        case .trending:
            return nil // Uses trending endpoint instead
        case .popularity:
            return "popularity.desc"
        case .releaseDateNewest:
            return mediaType.releaseDateNewestSort
        case .releaseDateOldest:
            return mediaType.releaseDateOldestSort
        case .ratingHighest:
            return "vote_average.desc"
        case .ratingLowest:
            return "vote_average.asc"
        }
    }

    /// Returns true if this sort requires vote count minimum.
    var requiresVoteCountMinimum: Bool {
        self == .ratingHighest || self == .ratingLowest
    }
}

// MARK: - Date Range

/// Date range filter options.
enum DateRange: String, CaseIterable, Identifiable, Sendable {
    /// Future releases only.
    case upcoming

    /// Current month only.
    case thisMonth

    /// Last 30 days.
    case last30Days

    /// Last 90 days.
    case last90Days

    /// Current year.
    case thisYear

    /// No date restrictions.
    case allTime

    var id: String { rawValue }

    /// Display label for UI.
    var displayName: String {
        switch self {
        case .upcoming:
            return Constants.FilterLabels.dateRangeUpcoming
        case .thisMonth:
            return Constants.FilterLabels.dateRangeThisMonth
        case .last30Days:
            return Constants.FilterLabels.dateRangeLast30Days
        case .last90Days:
            return Constants.FilterLabels.dateRangeLast90Days
        case .thisYear:
            return Constants.FilterLabels.dateRangeThisYear
        case .allTime:
            return Constants.FilterLabels.dateRangeAllTime
        }
    }

    /// Returns true if this is an active filter (not "All Time").
    var isActive: Bool {
        self != .allTime
    }

    /// Computes the date range boundaries.
    ///
    /// - Returns: DateRange with start and end dates
    func dateRange() -> DateUtils.DateRange {
        switch self {
        case .upcoming:
            return DateUtils.upcomingDateRange()
        case .thisMonth:
            return DateUtils.thisMonthDateRange()
        case .last30Days:
            return DateUtils.last30DaysDateRange()
        case .last90Days:
            return DateUtils.last90DaysDateRange()
        case .thisYear:
            return DateUtils.thisYearDateRange()
        case .allTime:
            return DateUtils.allTimeDateRange()
        }
    }
}

// MARK: - Filter State

/// The complete state of all filters applied to content.
///
/// ## Overview
/// FilterState is an immutable value type that represents the current filter configuration.
/// It enforces business rules through mutation methods that return new state.
///
/// ## Business Rules (enforced automatically)
/// 1. Leaving Movies clears certification
/// 2. If Sort = Trending AND any filter is active → Sort auto-switches to Popularity
/// 3. If Date Range = Upcoming AND Sort is Trending/Popularity → Sort auto-switches to Release Date (Newest)
///
/// ## Usage
/// ```swift
/// var state = FilterState()
/// state = state.withContentType(.movies)
/// state = state.withGenre(actionGenre)
/// // Sort automatically changed from Trending to Popularity if needed
/// ```
struct FilterState: Equatable, Sendable {

    // MARK: - Properties

    /// The content type filter (All, Movies, or TV Shows).
    let contentType: ContentType

    /// The sort order.
    let sort: SortOption

    /// The selected genre, or nil for "All Genres".
    let genre: GenreDisplay?

    /// The date range filter.
    let dateRange: DateRange

    /// The certification filter (movies only), or nil for "All Certifications".
    let certification: String?

    // MARK: - Initialization

    /// Creates a new FilterState with default values.
    ///
    /// Defaults:
    /// - Content Type: All
    /// - Sort: Trending
    /// - Genre: nil (All)
    /// - Date Range: All Time
    /// - Certification: nil (All)
    init(
        contentType: ContentType = .all,
        sort: SortOption = .trending,
        genre: GenreDisplay? = nil,
        dateRange: DateRange = .allTime,
        certification: String? = nil
    ) {
        self.contentType = contentType
        self.sort = sort
        self.genre = genre
        self.dateRange = dateRange
        self.certification = certification
    }

    // MARK: - Computed Properties

    /// Returns true if any filter is active (not default).
    ///
    /// Active filters include:
    /// - Genre selection
    /// - Certification selection
    /// - Date range other than "All Time"
    var hasActiveFilters: Bool {
        genre != nil || certification != nil || dateRange.isActive
    }

    /// Count of active filters (for display badge).
    var activeFilterCount: Int {
        var count = 0
        if genre != nil { count += 1 }
        if certification != nil { count += 1 }
        if dateRange.isActive { count += 1 }
        return count
    }

    /// Returns true if using trending endpoint is possible.
    ///
    /// Trending can only be used when:
    /// - Sort is set to Trending
    /// - No filters are active
    var canUseTrendingEndpoint: Bool {
        sort == .trending && !hasActiveFilters
    }

    /// Summary text for filter bar display.
    ///
    /// Format: "[All • Trending • Action] [2 filters]"
    var summaryText: String {
        var parts: [String] = [
            contentType.displayName,
            sort.displayName
        ]

        if let genre = genre {
            parts.append(genre.name)
        }

        let summary = parts.joined(separator: " • ")

        if activeFilterCount > 0 {
            return "\(summary) [\(activeFilterCount) filter\(activeFilterCount == 1 ? "" : "s")]"
        }

        return summary
    }

    // MARK: - Mutation Methods (return new state)

    /// Creates a new state with the specified content type.
    ///
    /// - Note: Clears certification when leaving Movies.
    /// - Parameter newContentType: The new content type
    /// - Returns: New FilterState with rules applied
    func withContentType(_ newContentType: ContentType) -> FilterState {
        var newCertification = certification

        // Rule: Leaving Movies clears certification
        if newContentType != .movies {
            newCertification = nil
        }

        return FilterState(
            contentType: newContentType,
            sort: sort,
            genre: genre,
            dateRange: dateRange,
            certification: newCertification
        ).applyingInvariants()
    }

    /// Creates a new state with the specified sort option.
    ///
    /// - Parameter newSort: The new sort option
    /// - Returns: New FilterState with rules applied
    func withSort(_ newSort: SortOption) -> FilterState {
        FilterState(
            contentType: contentType,
            sort: newSort,
            genre: genre,
            dateRange: dateRange,
            certification: certification
        ).applyingInvariants()
    }

    /// Creates a new state with the specified genre.
    ///
    /// - Parameter newGenre: The new genre, or nil for "All Genres"
    /// - Returns: New FilterState with rules applied
    func withGenre(_ newGenre: GenreDisplay?) -> FilterState {
        FilterState(
            contentType: contentType,
            sort: sort,
            genre: newGenre,
            dateRange: dateRange,
            certification: certification
        ).applyingInvariants()
    }

    /// Creates a new state with the specified date range.
    ///
    /// - Parameter newDateRange: The new date range
    /// - Returns: New FilterState with rules applied
    func withDateRange(_ newDateRange: DateRange) -> FilterState {
        FilterState(
            contentType: contentType,
            sort: sort,
            genre: genre,
            dateRange: newDateRange,
            certification: certification
        ).applyingInvariants()
    }

    /// Creates a new state with the specified certification.
    ///
    /// - Note: Only applies when content type is Movies.
    /// - Parameter newCertification: The new certification, or nil for "All"
    /// - Returns: New FilterState with rules applied
    func withCertification(_ newCertification: String?) -> FilterState {
        // Only allow certification for movies
        let effectiveCertification = contentType == .movies ? newCertification : nil

        return FilterState(
            contentType: contentType,
            sort: sort,
            genre: genre,
            dateRange: dateRange,
            certification: effectiveCertification
        ).applyingInvariants()
    }

    /// Creates a new state with all filters cleared to defaults.
    ///
    /// - Returns: New FilterState with default values
    func cleared() -> FilterState {
        FilterState()
    }

    // MARK: - Private Methods

    /// Applies business rule invariants and returns corrected state.
    ///
    /// ## Rules Applied
    /// 1. If Sort = Trending AND hasActiveFilters → Sort = Popularity
    /// 2. If Date Range = Upcoming AND Sort in [Trending, Popularity] → Sort = Release Date (Newest)
    ///
    /// - Returns: FilterState with invariants enforced
    private func applyingInvariants() -> FilterState {
        var newSort = sort

        // Rule 1: Trending + filters → Popularity
        if newSort == .trending && hasActiveFilters {
            newSort = .popularity
            Log.filter.info("Sort auto-switched from Trending to Popularity due to active filters")
        }

        // Rule 2: Upcoming + (Trending|Popularity) → Release Date Newest
        if dateRange == .upcoming && (newSort == .trending || newSort == .popularity) {
            newSort = .releaseDateNewest
            Log.filter.info("Sort auto-switched to Release Date (Newest) due to Upcoming date range")
        }

        // Return self if no changes needed
        if newSort == sort {
            return self
        }

        return FilterState(
            contentType: contentType,
            sort: newSort,
            genre: genre,
            dateRange: dateRange,
            certification: certification
        )
    }
}

// MARK: - Filter Change Event

/// Represents a change in filter state for observation.
struct FilterChange: Equatable, Sendable {
    /// The previous filter state.
    let previousState: FilterState

    /// The new filter state.
    let newState: FilterState

    /// Returns true if the sort was automatically changed by invariant rules.
    var sortWasAutoAdjusted: Bool {
        previousState.sort != newState.sort &&
        previousState.sort == .trending
    }

    /// Description of what changed (for accessibility announcements).
    var changeDescription: String? {
        if sortWasAutoAdjusted {
            return String(
                format: Constants.Accessibility.sortAutoSwitchedFormat,
                newState.sort.displayName
            )
        }
        return nil
    }
}

// MARK: - Custom String Convertible

extension FilterState: CustomStringConvertible {
    var description: String {
        "FilterState(type: \(contentType), sort: \(sort), genre: \(genre?.name ?? "All"), dateRange: \(dateRange), cert: \(certification ?? "All"))"
    }
}
