// MARK: - Video.swift
// Trailers - tvOS App
// Video model for trailers and other media clips

import Foundation

/// Represents a video clip (trailer, teaser, etc.) from TMDB.
///
/// ## Overview
/// Videos are fetched as part of media detail requests and include trailers,
/// teasers, clips, featurettes, and behind-the-scenes content.
/// Only YouTube videos are playable in this app.
///
/// ## Trailer Ranking
/// When multiple trailers are available, they are ranked by:
/// 1. Official status (official first)
/// 2. Type priority (Trailer > Teaser > Clip > Featurette > Behind the Scenes)
/// 3. Name containing "Official Trailer" (case-insensitive)
/// 4. Resolution (higher is better)
/// 5. Publish date (newer is better)
/// 6. ID (for stable ordering)
///
/// ## Usage
/// ```swift
/// let videos = detail.videos.filter { $0.isYouTube }
/// let rankedVideos = Video.rankTrailers(videos)
/// if let bestTrailer = rankedVideos.first {
///     YouTubeLauncher.open(bestTrailer)
/// }
/// ```
struct Video: Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// The unique identifier for this video.
    let id: String

    /// The YouTube video key (used to construct watch URL).
    let key: String

    /// The video title/name.
    let name: String

    /// The hosting site (e.g., "YouTube", "Vimeo").
    let site: String

    /// Video resolution (e.g., 1080, 720, 480).
    let size: Int?

    /// The video type (e.g., "Trailer", "Teaser", "Clip").
    let type: String

    /// Whether this is an official video from the studio.
    let official: Bool

    /// When the video was published.
    let publishedAt: Date?

    // MARK: - Computed Properties

    /// Returns true if this video is hosted on YouTube.
    var isYouTube: Bool {
        site.lowercased() == "youtube"
    }

    /// The full YouTube watch URL for this video.
    ///
    /// - Returns: YouTube URL, or nil if not a YouTube video
    var youtubeURL: URL? {
        guard isYouTube else { return nil }
        return Constants.YouTube.watchURL(videoKey: key)
    }

    /// Display string showing video details.
    ///
    /// Format: "YouTube • Official Trailer • 1080p"
    var displayInfo: String {
        var parts: [String] = []

        if isYouTube {
            parts.append("YouTube")
        }

        parts.append(name)

        if let size = size {
            parts.append("\(size)p")
        }

        return parts.joined(separator: " • ")
    }

    /// Returns true if the name contains "Official Trailer" (case-insensitive).
    var hasOfficialTrailerInName: Bool {
        name.lowercased().contains("official trailer")
    }

    /// The priority score for video type (lower is better).
    var typePriority: Int {
        switch type {
        case Constants.VideoTypes.trailer:
            return 0
        case Constants.VideoTypes.teaser:
            return 1
        case Constants.VideoTypes.clip:
            return 2
        case Constants.VideoTypes.featurette:
            return 3
        case Constants.VideoTypes.behindTheScenes:
            return 4
        default:
            return 5
        }
    }

    // MARK: - Ranking

    /// Ranks a list of videos according to trailer ranking rules.
    ///
    /// ## Ranking Priority (highest to lowest)
    /// 1. Official videos first
    /// 2. Type: Trailer > Teaser > Clip > Featurette > Behind the Scenes
    /// 3. Name containing "Official Trailer"
    /// 4. Higher resolution (size)
    /// 5. Newer publish date
    /// 6. Stable by ID (alphabetical)
    ///
    /// - Parameter videos: Array of videos to rank (should be YouTube-only)
    /// - Returns: Sorted array with best trailer first
    static func rankTrailers(_ videos: [Video]) -> [Video] {
        videos.sorted { v1, v2 in
            // 1. Official first
            if v1.official != v2.official {
                return v1.official
            }

            // 2. Type priority
            if v1.typePriority != v2.typePriority {
                return v1.typePriority < v2.typePriority
            }

            // 3. "Official Trailer" in name
            if v1.hasOfficialTrailerInName != v2.hasOfficialTrailerInName {
                return v1.hasOfficialTrailerInName
            }

            // 4. Higher resolution
            let size1 = v1.size ?? 0
            let size2 = v2.size ?? 0
            if size1 != size2 {
                return size1 > size2
            }

            // 5. Newer publish date
            if let date1 = v1.publishedAt, let date2 = v2.publishedAt {
                if date1 != date2 {
                    return date1 > date2
                }
            } else if v1.publishedAt != nil {
                return true
            } else if v2.publishedAt != nil {
                return false
            }

            // 6. Stable by ID
            return v1.id < v2.id
        }
    }
}

// MARK: - Codable

extension Video: Codable {}

// MARK: - Custom String Convertible

extension Video: CustomStringConvertible {
    var description: String {
        "\(name) (\(type), \(site))"
    }
}

// MARK: - Array Extension for Videos

extension Array where Element == Video {

    /// Filters to only YouTube videos.
    var youtubeOnly: [Video] {
        filter { $0.isYouTube }
    }

    /// Returns videos ranked by trailer priority.
    var ranked: [Video] {
        Video.rankTrailers(self)
    }

    /// The best trailer according to ranking rules, or nil if empty.
    var bestTrailer: Video? {
        youtubeOnly.ranked.first
    }

    /// Returns true if there's at least one YouTube video.
    var hasYouTubeVideo: Bool {
        contains { $0.isYouTube }
    }
}
