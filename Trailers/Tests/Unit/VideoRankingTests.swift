// MARK: - VideoRankingTests.swift
// Trailers - tvOS App
// Unit tests for video/trailer ranking algorithm

import XCTest
@testable import Trailers

/// Tests for Video trailer ranking algorithm.
///
/// ## Ranking Priority (tested)
/// 1. Official videos first
/// 2. Type: Trailer > Teaser > Clip > Featurette > Behind the Scenes
/// 3. Name containing "Official Trailer"
/// 4. Higher resolution (size)
/// 5. Newer publish date
/// 6. Stable by ID
final class VideoRankingTests: XCTestCase {

    // MARK: - Helper Factory

    func makeVideo(
        id: String = "v1",
        name: String = "Test Video",
        type: String = "Trailer",
        official: Bool = false,
        size: Int? = 1080,
        publishedAt: Date? = nil
    ) -> Video {
        Video(
            id: id,
            key: "key_\(id)",
            name: name,
            site: "YouTube",
            size: size,
            type: type,
            official: official,
            publishedAt: publishedAt
        )
    }

    // MARK: - Official First Tests

    func testOfficialVideosFirst() {
        let unofficial = makeVideo(id: "v1", official: false)
        let official = makeVideo(id: "v2", official: true)

        let ranked = Video.rankTrailers([unofficial, official])

        XCTAssertEqual(ranked[0].id, "v2", "Official video should be first")
        XCTAssertEqual(ranked[1].id, "v1")
    }

    func testOfficialVideosTieBreaker() {
        let official1 = makeVideo(id: "v1", official: true, size: 720)
        let official2 = makeVideo(id: "v2", official: true, size: 1080)

        let ranked = Video.rankTrailers([official1, official2])

        // Both official, should use next criteria (type, then size)
        XCTAssertEqual(ranked[0].id, "v2", "Higher resolution should win when both official")
    }

    // MARK: - Type Priority Tests

    func testTrailerTypeFirst() {
        let teaser = makeVideo(id: "v1", type: "Teaser")
        let trailer = makeVideo(id: "v2", type: "Trailer")
        let clip = makeVideo(id: "v3", type: "Clip")

        let ranked = Video.rankTrailers([teaser, clip, trailer])

        XCTAssertEqual(ranked[0].type, "Trailer")
        XCTAssertEqual(ranked[1].type, "Teaser")
        XCTAssertEqual(ranked[2].type, "Clip")
    }

    func testTypePriorityOrder() {
        let behindTheScenes = makeVideo(id: "v1", type: "Behind the Scenes")
        let featurette = makeVideo(id: "v2", type: "Featurette")
        let clip = makeVideo(id: "v3", type: "Clip")
        let teaser = makeVideo(id: "v4", type: "Teaser")
        let trailer = makeVideo(id: "v5", type: "Trailer")

        let ranked = Video.rankTrailers([behindTheScenes, featurette, clip, teaser, trailer])

        XCTAssertEqual(ranked[0].type, "Trailer")
        XCTAssertEqual(ranked[1].type, "Teaser")
        XCTAssertEqual(ranked[2].type, "Clip")
        XCTAssertEqual(ranked[3].type, "Featurette")
        XCTAssertEqual(ranked[4].type, "Behind the Scenes")
    }

    func testUnknownTypeLast() {
        let unknown = makeVideo(id: "v1", type: "Unknown Type")
        let trailer = makeVideo(id: "v2", type: "Trailer")

        let ranked = Video.rankTrailers([unknown, trailer])

        XCTAssertEqual(ranked[0].type, "Trailer")
        XCTAssertEqual(ranked[1].type, "Unknown Type")
    }

    // MARK: - Official Trailer Name Tests

    func testOfficialTrailerNamePreferred() {
        let regular = makeVideo(id: "v1", name: "Final Trailer")
        let officialNamed = makeVideo(id: "v2", name: "Official Trailer")

        let ranked = Video.rankTrailers([regular, officialNamed])

        XCTAssertEqual(ranked[0].id, "v2", "Video with 'Official Trailer' in name should be preferred")
    }

    func testOfficialTrailerNameCaseInsensitive() {
        let lower = makeVideo(id: "v1", name: "official trailer")
        let upper = makeVideo(id: "v2", name: "OFFICIAL TRAILER")
        let mixed = makeVideo(id: "v3", name: "Official Trailer - 2024")

        // All should be detected as having "Official Trailer" in name
        XCTAssertTrue(lower.hasOfficialTrailerInName)
        XCTAssertTrue(upper.hasOfficialTrailerInName)
        XCTAssertTrue(mixed.hasOfficialTrailerInName)
    }

    // MARK: - Resolution Tests

    func testHigherResolutionPreferred() {
        let low = makeVideo(id: "v1", size: 480)
        let medium = makeVideo(id: "v2", size: 720)
        let high = makeVideo(id: "v3", size: 1080)

        let ranked = Video.rankTrailers([low, high, medium])

        XCTAssertEqual(ranked[0].size, 1080)
        XCTAssertEqual(ranked[1].size, 720)
        XCTAssertEqual(ranked[2].size, 480)
    }

    func testNilSizeHandled() {
        let withSize = makeVideo(id: "v1", size: 1080)
        let withoutSize = makeVideo(id: "v2", size: nil)

        let ranked = Video.rankTrailers([withoutSize, withSize])

        XCTAssertEqual(ranked[0].id, "v1", "Video with size should be preferred over nil size")
    }

    // MARK: - Publish Date Tests

    func testNewerPublishDatePreferred() {
        let older = makeVideo(id: "v1", publishedAt: DateUtils.parseDate("2024-01-01"))
        let newer = makeVideo(id: "v2", publishedAt: DateUtils.parseDate("2024-06-01"))

        let ranked = Video.rankTrailers([older, newer])

        XCTAssertEqual(ranked[0].id, "v2", "Newer video should be first")
    }

    func testNilPublishDateHandled() {
        let withDate = makeVideo(id: "v1", publishedAt: DateUtils.parseDate("2024-01-01"))
        let withoutDate = makeVideo(id: "v2", publishedAt: nil)

        let ranked = Video.rankTrailers([withoutDate, withDate])

        XCTAssertEqual(ranked[0].id, "v1", "Video with date should be preferred")
    }

    // MARK: - Stable ID Ordering Tests

    func testStableIDOrdering() {
        // All same properties, should sort by ID
        let v1 = makeVideo(id: "aaa")
        let v2 = makeVideo(id: "bbb")
        let v3 = makeVideo(id: "ccc")

        let ranked = Video.rankTrailers([v3, v1, v2])

        XCTAssertEqual(ranked[0].id, "aaa")
        XCTAssertEqual(ranked[1].id, "bbb")
        XCTAssertEqual(ranked[2].id, "ccc")
    }

    // MARK: - Combined Priority Tests

    func testCombinedRanking() {
        // This tests the full priority chain
        let videos = [
            makeVideo(id: "v1", name: "Trailer", type: "Trailer", official: false, size: 1080),
            makeVideo(id: "v2", name: "Official Trailer", type: "Trailer", official: true, size: 720),
            makeVideo(id: "v3", name: "Teaser", type: "Teaser", official: true, size: 1080),
            makeVideo(id: "v4", name: "Official Trailer HD", type: "Trailer", official: true, size: 1080),
        ]

        let ranked = Video.rankTrailers(videos)

        // v4 should be first: official=true, type=Trailer, hasOfficialTrailerInName=true, size=1080
        XCTAssertEqual(ranked[0].id, "v4")

        // v2 should be second: official=true, type=Trailer, hasOfficialTrailerInName=true, size=720
        XCTAssertEqual(ranked[1].id, "v2")

        // v3 should be third: official=true, type=Teaser
        XCTAssertEqual(ranked[2].id, "v3")

        // v1 should be last: official=false
        XCTAssertEqual(ranked[3].id, "v1")
    }

    // MARK: - Empty and Single Item Tests

    func testEmptyArray() {
        let ranked = Video.rankTrailers([])
        XCTAssertTrue(ranked.isEmpty)
    }

    func testSingleItem() {
        let video = makeVideo(id: "v1")
        let ranked = Video.rankTrailers([video])

        XCTAssertEqual(ranked.count, 1)
        XCTAssertEqual(ranked[0].id, "v1")
    }

    // MARK: - Best Trailer Tests

    func testBestTrailer() {
        let videos = [
            makeVideo(id: "v1", type: "Teaser", official: false),
            makeVideo(id: "v2", type: "Trailer", official: true),
        ]

        let best = videos.bestTrailer

        XCTAssertNotNil(best)
        XCTAssertEqual(best?.id, "v2")
    }

    func testBestTrailerEmpty() {
        let videos: [Video] = []
        XCTAssertNil(videos.bestTrailer)
    }

    // MARK: - YouTube Filtering Tests

    func testYouTubeOnlyFilter() {
        let youtube = Video(id: "v1", key: "key1", name: "YouTube", site: "YouTube", size: nil, type: "Trailer", official: true, publishedAt: nil)
        let vimeo = Video(id: "v2", key: "key2", name: "Vimeo", site: "Vimeo", size: nil, type: "Trailer", official: true, publishedAt: nil)

        let videos = [youtube, vimeo]

        XCTAssertEqual(videos.youtubeOnly.count, 1)
        XCTAssertEqual(videos.youtubeOnly[0].id, "v1")
    }
}
