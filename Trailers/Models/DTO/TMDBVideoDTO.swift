// MARK: - TMDBVideoDTO.swift
// Trailers - tvOS App
// DTO for video/trailer objects in TMDB responses

import Foundation

/// DTO for video objects in TMDB detail responses.
///
/// ## Overview
/// This DTO matches video objects in the `videos.results` array
/// from movie and TV detail endpoints.
///
/// ## Key Fields
/// - `site`: Should be "YouTube" for playable videos
/// - `key`: The YouTube video ID
/// - `type`: "Trailer", "Teaser", "Clip", etc.
/// - `official`: Whether this is an official studio release
///
/// ## JSON Example
/// ```json
/// {
///   "id": "abc123",
///   "key": "dQw4w9WgXcQ",
///   "name": "Official Trailer",
///   "site": "YouTube",
///   "size": 1080,
///   "type": "Trailer",
///   "official": true,
///   "published_at": "2024-01-15T10:00:00.000Z"
/// }
/// ```
struct TMDBVideoDTO: Decodable, Sendable, Identifiable {

    // MARK: - Properties

    /// Unique video identifier.
    let id: String

    /// Video key (YouTube video ID for YouTube videos).
    let key: String

    /// Video title/name.
    let name: String

    /// Hosting site (e.g., "YouTube", "Vimeo").
    let site: String

    /// Video resolution (e.g., 1080, 720, 480).
    let size: Int?

    /// Video type (e.g., "Trailer", "Teaser", "Clip").
    let type: String

    /// Whether this is an official studio release.
    let official: Bool?

    /// ISO-639-1 language code.
    let iso6391: String?

    /// ISO-3166-1 country code.
    let iso31661: String?

    /// When the video was published (ISO 8601 timestamp).
    let publishedAt: String?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case key
        case name
        case site
        case size
        case type
        case official
        case iso6391 = "iso_639_1"
        case iso31661 = "iso_3166_1"
        case publishedAt = "published_at"
    }

    // MARK: - Domain Mapping

    /// Converts to domain Video model.
    func toVideo() -> Video {
        Video(
            id: id,
            key: key,
            name: name,
            site: site,
            size: size,
            type: type,
            official: official ?? false,
            publishedAt: DateUtils.parseISO8601(publishedAt)
        )
    }
}

// MARK: - Array Extension

extension Array where Element == TMDBVideoDTO {

    /// Converts all DTOs to domain Video models.
    var asDomainModels: [Video] {
        map { $0.toVideo() }
    }

    /// Filters to only YouTube videos and converts to domain models.
    var youtubeVideos: [Video] {
        filter { $0.site.lowercased() == "youtube" }
            .map { $0.toVideo() }
    }
}
