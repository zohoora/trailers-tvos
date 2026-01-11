// MARK: - TMDBMovieDetailDTO.swift
// Trailers - tvOS App
// DTO for movie detail endpoint response

import Foundation

/// DTO for movie detail response from `/movie/{id}` endpoint.
///
/// ## Overview
/// This DTO matches the response from:
/// - `/movie/{id}?append_to_response=release_dates,videos`
///
/// ## Key Fields
/// - Basic info: title, overview, runtime, etc.
/// - Genres: full objects with id and name
/// - Release dates: for extracting US certification
/// - Videos: trailers, teasers, etc.
///
/// ## JSON Example (partial)
/// ```json
/// {
///   "id": 12345,
///   "title": "Inception",
///   "tagline": "Your mind is the scene of the crime",
///   "runtime": 148,
///   "genres": [{"id": 28, "name": "Action"}],
///   "release_dates": {
///     "results": [{"iso_3166_1": "US", "release_dates": [...]}]
///   },
///   "videos": {
///     "results": [...]
///   }
/// }
/// ```
struct TMDBMovieDetailDTO: Decodable, Sendable {

    // MARK: - Properties

    /// TMDB movie ID.
    let id: Int

    /// Movie title.
    let title: String

    /// Original title.
    let originalTitle: String?

    /// Movie tagline/slogan.
    let tagline: String?

    /// Path to poster image.
    let posterPath: String?

    /// Path to backdrop image.
    let backdropPath: String?

    /// Movie synopsis/description.
    let overview: String?

    /// Runtime in minutes.
    let runtime: Int?

    /// Theatrical release date (YYYY-MM-DD).
    let releaseDate: String?

    /// Average vote score (0-10).
    let voteAverage: Double?

    /// Number of votes.
    let voteCount: Int?

    /// Full genre objects.
    let genres: [TMDBGenreDTO]?

    /// Popularity score.
    let popularity: Double?

    /// Budget in USD.
    let budget: Int?

    /// Revenue in USD.
    let revenue: Int?

    /// Status (Released, In Production, etc.).
    let status: String?

    /// IMDB ID.
    let imdbId: String?

    /// Original language code.
    let originalLanguage: String?

    /// Release dates container (for certification extraction).
    let releaseDates: TMDBReleaseDatesContainer?

    /// Videos container.
    let videos: TMDBVideosContainer?

    /// Credits container (cast and crew).
    let credits: TMDBCreditsContainer?

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case originalTitle = "original_title"
        case tagline
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case overview
        case runtime
        case releaseDate = "release_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genres
        case popularity
        case budget
        case revenue
        case status
        case imdbId = "imdb_id"
        case originalLanguage = "original_language"
        case releaseDates = "release_dates"
        case videos
        case credits
    }

    // MARK: - Domain Mapping

    /// Converts this DTO to a MediaDetail domain model.
    ///
    /// - Returns: MediaDetail with movie type
    func toMediaDetail() -> MediaDetail {
        // Extract US certification
        let certification = CertificationExtractor.extractMovieCertification(
            from: releaseDates?.results
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

        return MediaDetail(
            id: MediaID(type: .movie, id: id),
            title: title,
            tagline: tagline,
            posterPath: posterPath,
            backdropPath: backdropPath,
            overview: overview ?? "",
            releaseDate: DateUtils.parseDate(releaseDate),
            voteAverage: voteAverage,
            voteCount: voteCount,
            runtimeMinutes: runtime,
            episodeRuntimeMinutes: nil,
            genres: domainGenres,
            certification: certification,
            videos: domainVideos,
            popularity: popularity,
            originalLanguage: originalLanguage,
            cast: Array(domainCast)
        )
    }
}

// MARK: - Release Dates Container

/// Container for release dates in movie detail response.
struct TMDBReleaseDatesContainer: Decodable, Sendable {
    let results: [TMDBReleaseDateResult]?
}

// MARK: - Videos Container

/// Container for videos in detail response.
struct TMDBVideosContainer: Decodable, Sendable {
    let results: [TMDBVideoDTO]?
}

// MARK: - Credits Container

/// Container for credits in detail response.
struct TMDBCreditsContainer: Decodable, Sendable {
    let cast: [TMDBCastMemberDTO]?
}

/// DTO for a cast member.
struct TMDBCastMemberDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case character
        case profilePath = "profile_path"
        case order
    }

    /// Converts to domain model.
    func toCastMember() -> CastMember {
        CastMember(
            id: id,
            name: name,
            character: character,
            profilePath: profilePath,
            order: order ?? 999
        )
    }
}

// MARK: - Identifiable

extension TMDBMovieDetailDTO: Identifiable {}
