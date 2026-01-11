// MARK: - FilterViewModel.swift
// Trailers - tvOS App
// ViewModel for filter state management and genre loading

import Foundation
import Combine

/// ViewModel for managing filter state and genre lists.
///
/// ## Overview
/// FilterViewModel is responsible for:
/// - Managing current filter state
/// - Loading and caching genre lists
/// - Creating unified genre display for "All" mode
/// - Publishing filter change events
///
/// ## Filter State Invariants
/// The filter state automatically enforces business rules:
/// - Leaving Movies clears certification
/// - Trending + filters auto-switches to Popularity
/// - Upcoming + Trending/Popularity auto-switches to Release Date (Newest)
///
/// ## Usage
/// ```swift
/// @StateObject var filterVM = FilterViewModel()
///
/// // Change filters
/// filterVM.setContentType(.movies)
/// filterVM.setGenre(actionGenre)
///
/// // Observe changes
/// filterVM.$filterState
///     .sink { newState in
///         // Reload grid
///     }
/// ```
@MainActor
final class FilterViewModel: ObservableObject {

    // MARK: - Published State

    /// Current filter configuration.
    @Published private(set) var filterState = FilterState()

    /// Movie genres from TMDB.
    @Published private(set) var movieGenres: [Genre] = []

    /// TV genres from TMDB.
    @Published private(set) var tvGenres: [Genre] = []

    /// Unified genres for "All" content type mode.
    @Published private(set) var unifiedGenres: [GenreDisplay] = []

    /// Loading state for genres.
    @Published private(set) var isLoadingGenres = false

    /// Error loading genres.
    @Published private(set) var genreError: Error?

    // MARK: - Filter Change Events

    /// Publisher for filter change events.
    let filterChanged = PassthroughSubject<FilterChange, Never>()

    // MARK: - Private Properties

    /// TMDB service for fetching genres.
    private let tmdbService: TMDBService

    /// Whether genres have been loaded.
    private var genresLoaded = false

    // MARK: - Initialization

    /// Creates a new FilterViewModel.
    ///
    /// - Parameter tmdbService: Service for API calls (defaults to shared instance)
    init(tmdbService: TMDBService = .shared) {
        self.tmdbService = tmdbService
    }

    // MARK: - Genre Loading

    /// Loads genre lists from TMDB.
    ///
    /// Fetches both movie and TV genres and creates the unified list.
    /// Results are cached by TMDBService.
    ///
    /// - Parameter force: If true, reloads even if already loaded
    func loadGenres(force: Bool = false) async {
        guard !genresLoaded || force else { return }

        isLoadingGenres = true
        genreError = nil

        do {
            let (movie, tv) = try await tmdbService.fetchAllGenres()

            movieGenres = movie
            tvGenres = tv
            unifiedGenres = GenreMapping.createUnifiedGenres(movieGenres: movie, tvGenres: tv)
            genresLoaded = true

            Log.filter.info("Loaded \(movie.count) movie genres and \(tv.count) TV genres")
        } catch {
            genreError = error
            Log.filter.logError("Failed to load genres", error: error)
        }

        isLoadingGenres = false
    }

    // MARK: - Filter Intents

    /// Sets the content type filter.
    ///
    /// - Parameter contentType: New content type
    func setContentType(_ contentType: ContentType) {
        let previous = filterState
        filterState = filterState.withContentType(contentType)
        publishChange(from: previous)

        Log.filter.logFilterChange("contentType", value: contentType.displayName)
    }

    /// Sets the sort option.
    ///
    /// - Parameter sort: New sort option
    func setSort(_ sort: SortOption) {
        let previous = filterState
        filterState = filterState.withSort(sort)
        publishChange(from: previous)

        Log.filter.logFilterChange("sort", value: sort.displayName)
    }

    /// Sets the genre filter.
    ///
    /// - Parameter genre: New genre, or nil for "All Genres"
    func setGenre(_ genre: GenreDisplay?) {
        let previous = filterState
        filterState = filterState.withGenre(genre)
        publishChange(from: previous)

        Log.filter.logFilterChange("genre", value: genre?.name ?? "All")
    }

    /// Sets the date range filter.
    ///
    /// - Parameter dateRange: New date range
    func setDateRange(_ dateRange: DateRange) {
        let previous = filterState
        filterState = filterState.withDateRange(dateRange)
        publishChange(from: previous)

        Log.filter.logFilterChange("dateRange", value: dateRange.displayName)
    }

    /// Sets the certification filter (movies only).
    ///
    /// - Parameter certification: New certification, or nil for "All"
    func setCertification(_ certification: String?) {
        let previous = filterState
        filterState = filterState.withCertification(certification)
        publishChange(from: previous)

        Log.filter.logFilterChange("certification", value: certification ?? "All")
    }

    /// Clears all filters to defaults.
    func clearAllFilters() {
        let previous = filterState
        filterState = filterState.cleared()
        publishChange(from: previous)

        Log.filter.info("All filters cleared")
    }

    // MARK: - Private Methods

    /// Publishes a filter change event if state changed.
    private func publishChange(from previous: FilterState) {
        guard previous != filterState else { return }

        let change = FilterChange(previousState: previous, newState: filterState)
        filterChanged.send(change)
    }

    // MARK: - Computed Properties

    /// Genres to display based on current content type.
    var displayGenres: [GenreDisplay] {
        switch filterState.contentType {
        case .all:
            return unifiedGenres
        case .movies:
            return movieGenres.map { GenreDisplay.fromMovie($0) }
        case .tvShows:
            return tvGenres.map { GenreDisplay.fromTV($0) }
        }
    }

    /// Whether certification filter should be shown.
    var showCertification: Bool {
        filterState.contentType == .movies
    }

    /// Available certification options.
    var certificationOptions: [String] {
        Config.movieCertifications
    }

    /// Summary text for current filter state.
    var filterSummary: String {
        filterState.summaryText
    }

    /// Whether any filters are active.
    var hasActiveFilters: Bool {
        filterState.hasActiveFilters
    }

    /// Number of active filters.
    var activeFilterCount: Int {
        filterState.activeFilterCount
    }
}

// MARK: - Accessibility

extension FilterViewModel {

    /// Accessibility announcement for filter changes.
    ///
    /// - Parameter change: The filter change that occurred
    /// - Returns: Announcement string, or nil if no announcement needed
    func accessibilityAnnouncement(for change: FilterChange) -> String? {
        change.changeDescription
    }
}
