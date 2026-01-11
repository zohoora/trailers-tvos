// MARK: - TMDBTVDetailDTO.swift
// Trailers - tvOS App
// DTO for TV show detail endpoint response

import Foundation

/// DTO for TV show detail response from `/tv/{id}` endpoint.
///
/// ## Overview
/// This DTO matches the response from:
/// - `/tv/{id}?append_to_response=content_ratings,videos`
///
/// ## Key Fields
/// - Basic info: name, overview, episode_run_time, etc.
/// - Genres: full objects with id and name
/// - Content ratings: for extracting US rating
/// - Videos: trailers, teasers, etc.
///
/// ## Key Differences from Movies
/// - Uses `name` instead of `title`
/// - Uses `first_air_date` instead of `release_date`
/// - Uses `episode_run_time` array instead of single runtime
/// - Uses `content_ratings` instead of `release_dates` for certification
struct TMDBTVDetailDTO: Decodable, Sendable {

    // MARK: - Properties

    /// TMDB TV show ID.
    let id: Int

    /// TV show name.
    let name: String

    /// Original name.
    let originalName: String?

    /// TV show tagline/slogan.
    let tagline: String?

    /// Path to poster image.
    let posterPath: String?

    /// Path to backdrop image.
    let backdropPath: String?

    /// TV show synopsis/description.
    let overview: String?

    /// Episode runtimes in minutes (may vary by episode).
    let episodeRunTime: [Int]?

    /// First air date (YYYY-MM-DD).
    let firstAirDate: String?

    /// Last air date (YYYY-MM-DD).
    let lastAirDate: String?

    /// Average vote score (0-10).
    let voteAverage: Double?

    /// Number of votes.
    let voteCount: Int?

    /// Full genre objects.
    let genres: [TMDBGenreDTO]?

    /// Popularity score.
    let popularity: Double?

    /// Number of seasons.
    let numberOfSeasons: Int?

    /// Number of episodes.
    let numberOfEpisodes: Int?

    /// Status (Returning Series, Ended, etc.).
    let status: String?

    /// Type (Scripted, Documentary, etc.).
    let type: String?

    /// Original language code.
    let originalLanguage: String?

    /// Content ratings container (for certification extraction).
    let contentRatings: TMDBContentRatingsContainer?

    /// Videos container.
    let videos: TMDBVideosContainer?

    /// Credits container (cast and crew).
    let credits: TMDBCreditsContainer?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case originalName = "original_name"
        case tagline
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case overview
        case episodeRunTime = "episode_run_time"
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genres
        case popularity
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case status
        case type
        case originalLanguage = "original_language"
        case contentRatings = "content_ratings"
        case videos
        case credits
    }

    // MARK: - Domain Mapping

    /// Converts this DTO to a MediaDetail domain model.
    ///
    /// - Returns: MediaDetail with TV type
    func toMediaDetail() -> MediaDetail {
        // Extract US certification
        let certification = CertificationExtractor.extractTVCertification(
            from: contentRatings?.results
        )

        // Convert genres
        let domainGenres = (genres ?? []).map { Genre(id: $0.id, name: $0.name) }

        // Convert videos
        let domainVideos = (videos?.results ?? []).map { $0.toVideo() }

        // Convert cast (top 10)
        let domainCast = (credits?.cast ?? [])
            .sorted { $0.order ?? 999 < $1.order ?? 999 }
            .prefix(10)
            .map { $0.toCastMember() }

        // Use first episode runtime
        let episodeRuntime = episodeRunTime?.first

        return MediaDetail(
            id: MediaID(type: .tv, id: id),
            title: name,
            tagline: tagline,
            posterPath: posterPath,
            backdropPath: backdropPath,
            overview: overview ?? "",
            releaseDate: DateUtils.parseDate(firstAirDate),
            voteAverage: voteAverage,
            voteCount: voteCount,
            runtimeMinutes: nil,
            episodeRuntimeMinutes: episodeRuntime,
            genres: domainGenres,
            certification: certification,
            videos: domainVideos,
            popularity: popularity,
            originalLanguage: originalLanguage,
            cast: Array(domainCast)
        )
    }
}

// MARK: - Content Ratings Container

/// Container for content ratings in TV detail response.
struct TMDBContentRatingsContainer: Decodable, Sendable {
    let results: [TMDBContentRating]?
}

// MARK: - Identifiable

extension TMDBTVDetailDTO: Identifiable {}
