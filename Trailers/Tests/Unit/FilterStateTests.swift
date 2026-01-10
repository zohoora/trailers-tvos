// MARK: - FilterStateTests.swift
// Trailers - tvOS App
// Unit tests for FilterState invariants and behavior

import XCTest
@testable import Trailers

/// Tests for FilterState business rules and invariants.
///
/// ## Tested Invariants
/// 1. Leaving Movies clears certification
/// 2. Trending + filters auto-switches to Popularity
/// 3. Upcoming + Trending/Popularity auto-switches to Release Date (Newest)
final class FilterStateTests: XCTestCase {

    // MARK: - Default State Tests

    func testDefaultState() {
        let state = FilterState()

        XCTAssertEqual(state.contentType, .all)
        XCTAssertEqual(state.sort, .trending)
        XCTAssertNil(state.genre)
        XCTAssertEqual(state.dateRange, .allTime)
        XCTAssertNil(state.certification)
        XCTAssertFalse(state.hasActiveFilters)
        XCTAssertEqual(state.activeFilterCount, 0)
        XCTAssertTrue(state.canUseTrendingEndpoint)
    }

    // MARK: - Content Type Tests

    func testLeavingMoviesClearsCertification() {
        // Given: Movies with certification set
        var state = FilterState(contentType: .movies, certification: "PG-13")

        // When: Change to All
        state = state.withContentType(.all)

        // Then: Certification is cleared
        XCTAssertNil(state.certification, "Certification should be cleared when leaving Movies")
    }

    func testLeavingMoviesToTVClearsCertification() {
        // Given: Movies with certification set
        var state = FilterState(contentType: .movies, certification: "R")

        // When: Change to TV Shows
        state = state.withContentType(.tvShows)

        // Then: Certification is cleared
        XCTAssertNil(state.certification)
    }

    func testCertificationIgnoredForNonMovies() {
        // Given: TV Shows selected
        let state = FilterState(contentType: .tvShows)

        // When: Try to set certification
        let newState = state.withCertification("PG-13")

        // Then: Certification is not set
        XCTAssertNil(newState.certification, "Certification should not be set for TV Shows")
    }

    // MARK: - Trending + Filters Invariant Tests

    func testTrendingWithGenreAutoSwitchesToPopularity() {
        // Given: Trending sort with no filters
        var state = FilterState(sort: .trending)
        XCTAssertEqual(state.sort, .trending)

        // When: Add genre filter
        let genre = GenreDisplay(name: "Action", movieGenreID: 28, tvGenreID: 10759)
        state = state.withGenre(genre)

        // Then: Sort auto-switches to Popularity
        XCTAssertEqual(state.sort, .popularity, "Sort should auto-switch from Trending to Popularity when genre is set")
    }

    func testTrendingWithCertificationAutoSwitchesToPopularity() {
        // Given: Movies with Trending sort
        var state = FilterState(contentType: .movies, sort: .trending)

        // When: Add certification
        state = state.withCertification("PG-13")

        // Then: Sort auto-switches to Popularity
        XCTAssertEqual(state.sort, .popularity)
    }

    func testTrendingWithDateRangeAutoSwitchesToPopularity() {
        // Given: Trending sort
        var state = FilterState(sort: .trending)

        // When: Add date range (not All Time and not Upcoming)
        state = state.withDateRange(.thisMonth)

        // Then: Sort auto-switches to Popularity
        XCTAssertEqual(state.sort, .popularity)
    }

    func testClearingFiltersAllowsTrendingAgain() {
        // Given: State with filters and auto-switched to Popularity
        var state = FilterState(sort: .trending)
        let genre = GenreDisplay(name: "Action", movieGenreID: 28, tvGenreID: 10759)
        state = state.withGenre(genre)
        XCTAssertEqual(state.sort, .popularity)

        // When: Clear filters and set Trending
        state = state.cleared()
        state = state.withSort(.trending)

        // Then: Trending is allowed
        XCTAssertEqual(state.sort, .trending)
        XCTAssertTrue(state.canUseTrendingEndpoint)
    }

    // MARK: - Upcoming + Sort Invariant Tests

    func testUpcomingWithTrendingAutoSwitchesToReleaseDateNewest() {
        // Given: Trending sort
        var state = FilterState(sort: .trending)

        // When: Set date range to Upcoming
        state = state.withDateRange(.upcoming)

        // Then: Sort auto-switches to Release Date (Newest)
        XCTAssertEqual(state.sort, .releaseDateNewest, "Sort should auto-switch to Release Date (Newest) for Upcoming")
    }

    func testUpcomingWithPopularityAutoSwitchesToReleaseDateNewest() {
        // Given: Popularity sort
        var state = FilterState(sort: .popularity)

        // When: Set date range to Upcoming
        state = state.withDateRange(.upcoming)

        // Then: Sort auto-switches to Release Date (Newest)
        XCTAssertEqual(state.sort, .releaseDateNewest)
    }

    func testUpcomingWithRatingHighestRemainsUnchanged() {
        // Given: Rating Highest sort
        var state = FilterState(sort: .ratingHighest)

        // When: Set date range to Upcoming
        state = state.withDateRange(.upcoming)

        // Then: Sort remains Rating Highest
        XCTAssertEqual(state.sort, .ratingHighest, "Non-Trending/Popularity sorts should not change for Upcoming")
    }

    // MARK: - Active Filter Count Tests

    func testActiveFilterCountWithGenre() {
        let genre = GenreDisplay(name: "Action", movieGenreID: 28, tvGenreID: nil)
        let state = FilterState(genre: genre)

        XCTAssertEqual(state.activeFilterCount, 1)
        XCTAssertTrue(state.hasActiveFilters)
    }

    func testActiveFilterCountWithCertification() {
        let state = FilterState(contentType: .movies, certification: "PG-13")

        XCTAssertEqual(state.activeFilterCount, 1)
    }

    func testActiveFilterCountWithDateRange() {
        let state = FilterState(dateRange: .thisYear)

        XCTAssertEqual(state.activeFilterCount, 1)
    }

    func testActiveFilterCountWithMultiple() {
        let genre = GenreDisplay(name: "Action", movieGenreID: 28, tvGenreID: nil)
        let state = FilterState(
            contentType: .movies,
            genre: genre,
            dateRange: .thisMonth,
            certification: "PG-13"
        )

        XCTAssertEqual(state.activeFilterCount, 3)
    }

    func testActiveFilterCountExcludesSortAndContentType() {
        let state = FilterState(contentType: .movies, sort: .ratingHighest)

        XCTAssertEqual(state.activeFilterCount, 0, "Sort and ContentType should not count as active filters")
        XCTAssertFalse(state.hasActiveFilters)
    }

    // MARK: - Trending Endpoint Eligibility Tests

    func testCanUseTrendingEndpointWithNoFilters() {
        let state = FilterState(sort: .trending)

        XCTAssertTrue(state.canUseTrendingEndpoint)
    }

    func testCannotUseTrendingEndpointWithWrongSort() {
        let state = FilterState(sort: .popularity)

        XCTAssertFalse(state.canUseTrendingEndpoint)
    }

    func testCannotUseTrendingEndpointWithFilters() {
        let genre = GenreDisplay(name: "Action", movieGenreID: 28, tvGenreID: nil)
        let state = FilterState(sort: .popularity, genre: genre)

        XCTAssertFalse(state.canUseTrendingEndpoint)
    }

    // MARK: - Cleared State Tests

    func testClearedState() {
        // Given: State with various filters
        let genre = GenreDisplay(name: "Action", movieGenreID: 28, tvGenreID: nil)
        let state = FilterState(
            contentType: .movies,
            sort: .ratingHighest,
            genre: genre,
            dateRange: .thisMonth,
            certification: "PG-13"
        )

        // When: Clear
        let cleared = state.cleared()

        // Then: All defaults restored
        XCTAssertEqual(cleared.contentType, .all)
        XCTAssertEqual(cleared.sort, .trending)
        XCTAssertNil(cleared.genre)
        XCTAssertEqual(cleared.dateRange, .allTime)
        XCTAssertNil(cleared.certification)
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        let state1 = FilterState(contentType: .movies, sort: .popularity)
        let state2 = FilterState(contentType: .movies, sort: .popularity)
        let state3 = FilterState(contentType: .tvShows, sort: .popularity)

        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
    }
}
