// MARK: - DTODecodingTests.swift
// Trailers - tvOS App
// Unit tests for TMDB DTO decoding

import XCTest
@testable import Trailers

/// Tests for DTO decoding from TMDB API responses.
///
/// ## Tested Scenarios
/// - Movie list decoding
/// - TV list decoding
/// - Trending/all skips people without failing
/// - Detail decoding with videos and ratings
/// - Edge cases (missing fields, null values)
final class DTODecodingTests: XCTestCase {

    // MARK: - Properties

    var decoder: JSONDecoder!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        decoder = JSONDecoder()
        // Note: DTOs use explicit CodingKeys, so don't use convertFromSnakeCase
    }

    // MARK: - Movie List Tests

    func testMovieListDTODecoding() throws {
        let json = """
        {
            "id": 12345,
            "title": "Inception",
            "original_title": "Inception",
            "poster_path": "/abc123.jpg",
            "backdrop_path": "/xyz789.jpg",
            "overview": "A thief who steals corporate secrets",
            "release_date": "2010-07-16",
            "vote_average": 8.8,
            "vote_count": 30000,
            "genre_ids": [28, 878, 53],
            "popularity": 100.5,
            "adult": false,
            "original_language": "en"
        }
        """.data(using: .utf8)!

        let movie = try decoder.decode(TMDBMovieListDTO.self, from: json)

        XCTAssertEqual(movie.id, 12345)
        XCTAssertEqual(movie.title, "Inception")
        XCTAssertEqual(movie.posterPath, "/abc123.jpg")
        XCTAssertEqual(movie.releaseDate, "2010-07-16")
        XCTAssertEqual(movie.voteAverage, 8.8)
        XCTAssertEqual(movie.genreIds?.count, 3)
    }

    func testMovieListDTOWithMissingOptionalFields() throws {
        let json = """
        {
            "id": 12345,
            "title": "Unknown Movie"
        }
        """.data(using: .utf8)!

        let movie = try decoder.decode(TMDBMovieListDTO.self, from: json)

        XCTAssertEqual(movie.id, 12345)
        XCTAssertEqual(movie.title, "Unknown Movie")
        XCTAssertNil(movie.posterPath)
        XCTAssertNil(movie.releaseDate)
        XCTAssertNil(movie.voteAverage)
    }

    func testMovieListDTOToMediaSummary() throws {
        let json = """
        {
            "id": 12345,
            "title": "Test Movie",
            "poster_path": "/poster.jpg",
            "release_date": "2024-01-15",
            "vote_average": 7.5,
            "genre_ids": [28],
            "popularity": 50.0
        }
        """.data(using: .utf8)!

        let movie = try decoder.decode(TMDBMovieListDTO.self, from: json)
        let summary = movie.toMediaSummary()

        XCTAssertEqual(summary.id.type, .movie)
        XCTAssertEqual(summary.id.id, 12345)
        XCTAssertEqual(summary.title, "Test Movie")
        XCTAssertEqual(summary.posterPath, "/poster.jpg")
    }

    // MARK: - TV List Tests

    func testTVListDTODecoding() throws {
        let json = """
        {
            "id": 67890,
            "name": "Breaking Bad",
            "original_name": "Breaking Bad",
            "poster_path": "/abc123.jpg",
            "backdrop_path": "/xyz789.jpg",
            "overview": "A high school chemistry teacher diagnosed with cancer",
            "first_air_date": "2008-01-20",
            "vote_average": 9.5,
            "vote_count": 10000,
            "genre_ids": [18, 80],
            "popularity": 200.5,
            "origin_country": ["US"],
            "original_language": "en"
        }
        """.data(using: .utf8)!

        let tv = try decoder.decode(TMDBTVListDTO.self, from: json)

        XCTAssertEqual(tv.id, 67890)
        XCTAssertEqual(tv.name, "Breaking Bad")
        XCTAssertEqual(tv.firstAirDate, "2008-01-20")
        XCTAssertEqual(tv.voteAverage, 9.5)
    }

    func testTVListDTOToMediaSummary() throws {
        let json = """
        {
            "id": 67890,
            "name": "Test Show",
            "first_air_date": "2024-06-01",
            "vote_average": 8.0
        }
        """.data(using: .utf8)!

        let tv = try decoder.decode(TMDBTVListDTO.self, from: json)
        let summary = tv.toMediaSummary()

        XCTAssertEqual(summary.id.type, .tv)
        XCTAssertEqual(summary.id.id, 67890)
        XCTAssertEqual(summary.title, "Test Show")
    }

    // MARK: - Trending All Tests

    func testTrendingAllSkipsPeople() throws {
        let json = """
        {
            "page": 1,
            "total_pages": 100,
            "total_results": 2000,
            "results": [
                {
                    "media_type": "movie",
                    "id": 1,
                    "title": "Movie 1"
                },
                {
                    "media_type": "person",
                    "id": 2,
                    "name": "Person Name"
                },
                {
                    "media_type": "tv",
                    "id": 3,
                    "name": "TV Show 1"
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(TMDBTrendingAllResponse.self, from: json)

        // Should have 3 results total
        XCTAssertEqual(response.results.count, 3)

        // But only 2 should be supported (movie + TV)
        XCTAssertEqual(response.supportedCount, 2)
        XCTAssertEqual(response.unsupportedCount, 1)

        // MediaSummaries should only include movie and TV
        let summaries = response.toMediaSummaries()
        XCTAssertEqual(summaries.count, 2)
    }

    func testTrendingAllWithUnknownMediaType() throws {
        let json = """
        {
            "page": 1,
            "total_pages": 1,
            "total_results": 2,
            "results": [
                {
                    "media_type": "movie",
                    "id": 1,
                    "title": "Movie"
                },
                {
                    "media_type": "future_type",
                    "id": 2
                }
            ]
        }
        """.data(using: .utf8)!

        // Should not throw
        let response = try decoder.decode(TMDBTrendingAllResponse.self, from: json)

        XCTAssertEqual(response.results.count, 2)
        XCTAssertEqual(response.supportedCount, 1)
    }

    // MARK: - Paginated Response Tests

    func testPaginatedResponseDecoding() throws {
        let json = """
        {
            "page": 2,
            "total_pages": 50,
            "total_results": 1000,
            "results": [
                {"id": 1, "title": "Movie 1"},
                {"id": 2, "title": "Movie 2"}
            ]
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(TMDBPaginatedDTO<TMDBMovieListDTO>.self, from: json)

        XCTAssertEqual(response.page, 2)
        XCTAssertEqual(response.totalPages, 50)
        XCTAssertEqual(response.totalResults, 1000)
        XCTAssertEqual(response.results.count, 2)
        XCTAssertTrue(response.hasMorePages)
        XCTAssertFalse(response.isFirstPage)
        XCTAssertFalse(response.isLastPage)
        XCTAssertEqual(response.nextPage, 3)
    }

    func testPaginatedResponseLastPage() throws {
        let json = """
        {
            "page": 50,
            "total_pages": 50,
            "total_results": 1000,
            "results": []
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(TMDBPaginatedDTO<TMDBMovieListDTO>.self, from: json)

        XCTAssertFalse(response.hasMorePages)
        XCTAssertTrue(response.isLastPage)
        XCTAssertNil(response.nextPage)
    }

    // MARK: - Video DTO Tests

    func testVideoDTODecoding() throws {
        let json = """
        {
            "id": "abc123",
            "key": "dQw4w9WgXcQ",
            "name": "Official Trailer",
            "site": "YouTube",
            "size": 1080,
            "type": "Trailer",
            "official": true,
            "published_at": "2024-01-15T10:00:00.000Z"
        }
        """.data(using: .utf8)!

        let video = try decoder.decode(TMDBVideoDTO.self, from: json)

        XCTAssertEqual(video.id, "abc123")
        XCTAssertEqual(video.key, "dQw4w9WgXcQ")
        XCTAssertEqual(video.name, "Official Trailer")
        XCTAssertEqual(video.site, "YouTube")
        XCTAssertEqual(video.size, 1080)
        XCTAssertEqual(video.type, "Trailer")
        XCTAssertEqual(video.official, true)
    }

    func testVideoDTOToVideo() throws {
        let json = """
        {
            "id": "vid1",
            "key": "xyz789",
            "name": "Teaser",
            "site": "YouTube",
            "type": "Teaser",
            "official": false
        }
        """.data(using: .utf8)!

        let dto = try decoder.decode(TMDBVideoDTO.self, from: json)
        let video = dto.toVideo()

        XCTAssertEqual(video.id, "vid1")
        XCTAssertEqual(video.key, "xyz789")
        XCTAssertTrue(video.isYouTube)
        XCTAssertFalse(video.official)
    }

    // MARK: - Genre DTO Tests

    func testGenreListDTODecoding() throws {
        let json = """
        {
            "genres": [
                {"id": 28, "name": "Action"},
                {"id": 12, "name": "Adventure"},
                {"id": 16, "name": "Animation"}
            ]
        }
        """.data(using: .utf8)!

        let genreList = try decoder.decode(TMDBGenreListDTO.self, from: json)

        XCTAssertEqual(genreList.genres.count, 3)
        XCTAssertEqual(genreList.genres[0].name, "Action")

        let genres = genreList.toGenres()
        XCTAssertEqual(genres.count, 3)
        XCTAssertEqual(genres[0].id, 28)
    }
}
