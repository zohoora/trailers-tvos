// MARK: - MediaDetail.swift
// Trailers - tvOS App
// Detailed model for media items displayed on the detail screen

import Foundation

/// Detailed information about a media item for the detail screen.
///
/// ## Overview
/// MediaDetail extends MediaSummary with additional information including:
/// - Tagline
/// - Runtime (movie) or episode runtime (TV)
/// - Full genre list (names, not just IDs)
/// - Certification/rating
/// - Available videos/trailers
///
/// ## Data Sources
/// MediaDetail is created from the detail endpoints:
/// - `/movie/{id}?append_to_response=release_dates,videos`
/// - `/tv/{id}?append_to_response=content_ratings,videos`
///
/// ## Usage
/// ```swift
/// let detail = try await tmdbService.fetchDetail(for: mediaID)
/// print(detail.tagline) // "Your mind is the scene of the crime"
/// print(detail.runtimeFormatted) // "2h 28m"
/// print(detail.certification) // "PG-13"
/// ```
struct MediaDetail: Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// The unique identifier combining type and TMDB ID.
    let id: MediaID

    /// The title (movie title or TV show name).
    let title: String

    /// Optional tagline/slogan.
    let tagline: String?

    /// Path to the poster image.
    let posterPath: String?

    /// Path to the backdrop image.
    let backdropPath: String?

    /// Full description/synopsis.
    let overview: String

    /// Release date for movies, first air date for TV shows.
    let releaseDate: Date?

    /// Average vote rating from TMDB (0-10 scale).
    let voteAverage: Double?

    /// Number of votes/ratings.
    let voteCount: Int?

    /// Runtime in minutes (movies only).
    let runtimeMinutes: Int?

    /// Episode runtime in minutes (TV only, uses first episode).
    let episodeRuntimeMinutes: Int?

    /// List of genres with names.
    let genres: [Genre]

    /// US certification/rating (e.g., "PG-13", "TV-MA").
    let certification: String

    /// Available videos (trailers, teasers, etc.).
    let videos: [Video]

    /// Popularity score from TMDB.
    let popularity: Double?

    /// Original language code (e.g., "en", "ko", "ja").
    let originalLanguage: String?

    /// Main cast members.
    let cast: [CastMember]

    // MARK: - Computed Properties

    /// The media type (movie or TV).
    var mediaType: MediaType {
        id.type
    }

    /// Returns true if this is a foreign language (non-English) title.
    var isForeignLanguage: Bool {
        guard let lang = originalLanguage else { return false }
        return lang != "en"
    }

    /// Year text for display ("2025" or "TBA").
    var yearText: String {
        DateUtils.yearString(from: releaseDate)
    }

    /// Formatted release date for display ("March 15, 2025" or "TBA").
    var releaseDateFormatted: String {
        DateUtils.formatForDisplay(releaseDate)
    }

    /// Formatted rating with vote count.
    ///
    /// Format: "8.8/10 (1,234 votes)" or "- /10"
    var ratingFormatted: String {
        let rating: String
        if let avg = voteAverage, avg > 0 {
            rating = String(format: "%.1f", avg)
        } else {
            rating = Constants.UIStrings.ratingNotAvailable
        }

        if let count = voteCount, count > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let countStr = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
            return "\(rating)/10 (\(countStr) votes)"
        }

        return "\(rating)/10"
    }

    /// Formatted runtime for display.
    ///
    /// - Movies: "2h 28m"
    /// - TV: "45 min/episode"
    /// - Returns nil if no runtime available
    var runtimeFormatted: String? {
        switch mediaType {
        case .movie:
            return DateUtils.formatRuntime(runtimeMinutes)
        case .tv:
            return DateUtils.formatEpisodeRuntime(episodeRuntimeMinutes)
        }
    }

    /// Comma-separated genre names.
    ///
    /// Format: "Action, Adventure, Sci-Fi"
    var genresFormatted: String {
        genres.map(\.name).joined(separator: ", ")
    }

    /// Returns true if there's a tagline to display.
    var hasTagline: Bool {
        tagline != nil && !(tagline?.isEmpty ?? true)
    }

    /// Full poster URL using detail size.
    var posterURL: URL? {
        Config.posterURL(path: posterPath, size: .detail)
    }

    /// Full backdrop URL using detail size.
    var backdropURL: URL? {
        Config.backdropURL(path: backdropPath, size: .detail)
    }

    /// YouTube videos only, ranked by quality.
    var rankedTrailers: [Video] {
        videos.youtubeOnly.ranked
    }

    /// The best trailer according to ranking rules.
    var bestTrailer: Video? {
        rankedTrailers.first
    }

    /// Returns true if there's at least one YouTube trailer.
    var hasTrailer: Bool {
        videos.hasYouTubeVideo
    }

    /// Number of available YouTube trailers.
    var trailerCount: Int {
        videos.youtubeOnly.count
    }

    /// Display text for trailer information.
    ///
    /// Format: "YouTube • Official Trailer • 1080p"
    var trailerDisplayInfo: String? {
        bestTrailer?.displayInfo
    }

    // MARK: - Factory Methods

    /// Creates a MediaDetail from a MediaSummary with partial information.
    ///
    /// This is used as a fallback when detail fetch fails but we have grid data.
    ///
    /// - Parameter summary: The summary to convert
    /// - Returns: A MediaDetail with available information
    static func fromSummary(_ summary: MediaSummary) -> MediaDetail {
        MediaDetail(
            id: summary.id,
            title: summary.title,
            tagline: nil,
            posterPath: summary.posterPath,
            backdropPath: summary.backdropPath,
            overview: summary.overview,
            releaseDate: summary.releaseDate,
            voteAverage: summary.voteAverage,
            voteCount: summary.voteCount,
            runtimeMinutes: nil,
            episodeRuntimeMinutes: nil,
            genres: [], // Would need genre lookup
            certification: Constants.FilterLabels.certificationNotRated,
            videos: [],
            popularity: summary.popularity,
            originalLanguage: summary.originalLanguage,
            cast: []
        )
    }

    /// Top cast members formatted for display.
    ///
    /// Format: "Actor 1, Actor 2, Actor 3"
    var castFormatted: String {
        cast.prefix(5).map(\.name).joined(separator: ", ")
    }

    /// Whether there are cast members to display.
    var hasCast: Bool {
        !cast.isEmpty
    }
}

// MARK: - Cast Member

/// A cast member (actor) in a movie or TV show.
struct CastMember: Identifiable, Hashable, Codable, Sendable {

    /// TMDB person ID.
    let id: Int

    /// Actor's name.
    let name: String

    /// Character name played.
    let character: String?

    /// Path to profile image.
    let profilePath: String?

    /// Billing order (lower = more prominent).
    let order: Int
}

// MARK: - Codable

extension MediaDetail: Codable {}

// MARK: - Custom String Convertible

extension MediaDetail: CustomStringConvertible {
    var description: String {
        "\(title) (\(yearText)) - \(mediaType.displayName) [\(certification)]"
    }
}

// MARK: - Certification Extraction

/// Utility for extracting US certification from TMDB detail responses.
enum CertificationExtractor {

    // MARK: - Movie Certification

    /// Priority order for movie release types (lower index = higher priority).
    ///
    /// Based on TMDB release type values:
    /// - 1: Premiere
    /// - 2: Theatrical (limited)
    /// - 3: Theatrical
    /// - 4: Digital
    /// - 5: Physical
    /// - 6: TV
    static let movieReleaseTypePriority = [3, 2, 4, 5, 6, 1]

    /// Extracts US certification from movie release dates.
    ///
    /// - Parameter releaseDates: Array of release date results from TMDB
    /// - Returns: US certification string, or "NR" if not found
    static func extractMovieCertification(from releaseDates: [TMDBReleaseDateResult]?) -> String {
        guard let usRelease = releaseDates?.first(where: { $0.iso31661 == "US" }) else {
            return Constants.FilterLabels.certificationNotRated
        }

        // Sort by release type priority
        let sortedReleases = usRelease.releaseDates.sorted { r1, r2 in
            let p1 = movieReleaseTypePriority.firstIndex(of: r1.type) ?? Int.max
            let p2 = movieReleaseTypePriority.firstIndex(of: r2.type) ?? Int.max
            return p1 < p2
        }

        // Find first non-empty certification
        for release in sortedReleases {
            if let cert = release.certification, !cert.isEmpty {
                return cert
            }
        }

        return Constants.FilterLabels.certificationNotRated
    }

    // MARK: - TV Certification

    /// Extracts US rating from TV content ratings.
    ///
    /// - Parameter contentRatings: Array of content rating results from TMDB
    /// - Returns: US rating string, or "NR" if not found
    static func extractTVCertification(from contentRatings: [TMDBContentRating]?) -> String {
        guard let usRating = contentRatings?.first(where: { $0.iso31661 == "US" }) else {
            return Constants.FilterLabels.certificationNotRated
        }

        if usRating.rating.isEmpty {
            return Constants.FilterLabels.certificationNotRated
        }

        return usRating.rating
    }
}

// MARK: - Supporting Types for Certification Extraction

/// TMDB release date result container.
struct TMDBReleaseDateResult: Codable {
    let iso31661: String
    let releaseDates: [TMDBReleaseDate]

    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case releaseDates = "release_dates"
    }
}

/// TMDB individual release date entry.
struct TMDBReleaseDate: Codable {
    let certification: String?
    let type: Int
}

/// TMDB content rating entry.
struct TMDBContentRating: Codable {
    let iso31661: String
    let rating: String

    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case rating
    }
}
