// MARK: - TMDBService.swift
// Trailers - tvOS App
// High-level TMDB API service coordinating network and cache

import Foundation

/// High-level service for TMDB API operations.
///
/// ## Overview
/// TMDBService provides the main interface for fetching content:
/// - Trending content
/// - Discover content with filters
/// - Media details
/// - Genre lists
///
/// ## Caching Strategy
/// - Checks cache first
/// - Falls back to network on cache miss
/// - Updates cache on successful fetch
/// - Uses expired cache when offline
///
/// ## Usage
/// ```swift
/// let service = TMDBService()
/// let movies = try await service.fetchTrending(mediaType: .movie, page: 1)
/// let detail = try await service.fetchDetail(for: mediaID)
/// ```
actor TMDBService {

    // MARK: - Properties

    /// Network client for API requests.
    private let networkClient: NetworkClient

    /// Response cache for storing results.
    private let cache: ResponseCache

    // MARK: - Initialization

    /// Creates a new TMDBService.
    ///
    /// - Parameters:
    ///   - networkClient: Network client to use (defaults to new instance)
    ///   - cache: Response cache to use (defaults to new instance)
    init(
        networkClient: NetworkClient = NetworkClient(),
        cache: ResponseCache = ResponseCache()
    ) {
        self.networkClient = networkClient
        self.cache = cache
    }

    // MARK: - Private Helpers

    /// Checks if the device is offline using the network monitor.
    private func isOffline() async -> Bool {
        await MainActor.run { NetworkMonitor.shared.isOffline }
    }

    // MARK: - Trending

    /// Fetches trending content.
    ///
    /// - Parameters:
    ///   - mediaType: Type of content to fetch (movie, tv, or nil for all)
    ///   - page: Page number (1-indexed)
    ///   - bypassCache: If true, skips cache and fetches fresh data
    /// - Returns: Array of media summaries
    /// - Throws: NetworkError on failure
    func fetchTrending(
        mediaType: MediaType?,
        page: Int,
        bypassCache: Bool = false
    ) async throws -> (items: [MediaSummary], hasMore: Bool) {
        let filterState = FilterState() // Default state for trending

        // Check cache first (unless bypassing)
        if !bypassCache {
            if let cached = await cache.getGridContent(
                for: filterState,
                page: page,
                allowExpired: await isOffline()
            ) {
                Log.cache.info("Using cached trending content")
                return (cached, true) // Assume more pages for cached
            }
        }

        // Fetch from network
        let items: [MediaSummary]
        let hasMore: Bool

        if let type = mediaType {
            // Single type trending
            let endpoint = type.trendingPath

            if type == .movie {
                let movieResponse = try await networkClient.fetch(
                    TMDBPaginatedDTO<TMDBMovieListDTO>.self,
                    from: endpoint,
                    parameters: ["page": String(page)]
                )
                items = movieResponse.results.map { $0.toMediaSummary() }
                hasMore = movieResponse.hasMorePages
            } else {
                let tvResponse = try await networkClient.fetch(
                    TMDBPaginatedDTO<TMDBTVListDTO>.self,
                    from: endpoint,
                    parameters: ["page": String(page)]
                )
                items = tvResponse.results.map { $0.toMediaSummary() }
                hasMore = tvResponse.hasMorePages
            }
        } else {
            // All types trending
            let response = try await networkClient.fetch(
                TMDBTrendingAllResponse.self,
                from: "/trending/all/week",
                parameters: ["page": String(page)]
            )
            items = response.toMediaSummaries()
            hasMore = response.hasMorePages
        }

        // Update cache
        await cache.setGridContent(items, for: filterState, page: page)

        return (items, hasMore)
    }

    // MARK: - Discover

    /// Fetches content using discover endpoint with filters.
    ///
    /// - Parameters:
    ///   - filterState: Current filter configuration
    ///   - page: Page number (1-indexed)
    ///   - bypassCache: If true, skips cache
    /// - Returns: Array of media summaries
    /// - Throws: NetworkError on failure
    func fetchDiscover(
        filterState: FilterState,
        page: Int,
        bypassCache: Bool = false
    ) async throws -> (items: [MediaSummary], hasMore: Bool, movieHasMore: Bool, tvHasMore: Bool) {
        // Check cache first
        if !bypassCache {
            if let cached = await cache.getGridContent(
                for: filterState,
                page: page,
                allowExpired: await isOffline()
            ) {
                Log.cache.info("Using cached discover content")
                return (cached, true, true, true)
            }
        }

        let items: [MediaSummary]
        var movieHasMore = true
        var tvHasMore = true

        switch filterState.contentType {
        case .movies:
            let response = try await fetchDiscoverMovies(filterState: filterState, page: page)
            items = response.items
            movieHasMore = response.hasMore
            tvHasMore = false

        case .tvShows:
            let response = try await fetchDiscoverTV(filterState: filterState, page: page)
            items = response.items
            tvHasMore = response.hasMore
            movieHasMore = false

        case .all:
            // Fetch both in parallel
            async let moviesFetch = fetchDiscoverMovies(filterState: filterState, page: page)
            async let tvFetch = fetchDiscoverTV(filterState: filterState, page: page)

            let (movies, tv) = try await (moviesFetch, tvFetch)

            // Merge results
            items = mergeResults(
                movies: movies.items,
                tv: tv.items,
                sort: filterState.sort
            )
            movieHasMore = movies.hasMore
            tvHasMore = tv.hasMore
        }

        let hasMore = movieHasMore || tvHasMore

        // Update cache
        await cache.setGridContent(items, for: filterState, page: page)

        return (items, hasMore, movieHasMore, tvHasMore)
    }

    /// Fetches movies from discover endpoint.
    private func fetchDiscoverMovies(
        filterState: FilterState,
        page: Int
    ) async throws -> (items: [MediaSummary], hasMore: Bool) {
        // Check if genre applies to movies
        if let genre = filterState.genre, genre.movieGenreID == nil {
            return ([], false)
        }

        let params = TMDBRequest.discoverParameters(for: filterState, page: page, mediaType: .movie)

        let response = try await networkClient.fetch(
            TMDBPaginatedDTO<TMDBMovieListDTO>.self,
            from: "/discover/movie",
            parameters: params
        )

        let items = response.results.map { $0.toMediaSummary() }
        return (items, response.hasMorePages)
    }

    /// Fetches TV shows from discover endpoint.
    private func fetchDiscoverTV(
        filterState: FilterState,
        page: Int
    ) async throws -> (items: [MediaSummary], hasMore: Bool) {
        // Check if genre applies to TV
        if let genre = filterState.genre, genre.tvGenreID == nil {
            return ([], false)
        }

        let params = TMDBRequest.discoverParameters(for: filterState, page: page, mediaType: .tv)

        let response = try await networkClient.fetch(
            TMDBPaginatedDTO<TMDBTVListDTO>.self,
            from: "/discover/tv",
            parameters: params
        )

        let items = response.results.map { $0.toMediaSummary() }
        return (items, response.hasMorePages)
    }

    /// Merges movie and TV results according to sort order.
    private func mergeResults(
        movies: [MediaSummary],
        tv: [MediaSummary],
        sort: SortOption
    ) -> [MediaSummary] {
        let combined = movies + tv
        return combined.sorted(by: sort).deduplicated
    }

    // MARK: - Detail

    /// Fetches detailed information for a media item.
    ///
    /// - Parameters:
    ///   - mediaID: The media identifier
    ///   - bypassCache: If true, skips cache
    /// - Returns: Media detail
    /// - Throws: NetworkError on failure
    func fetchDetail(
        for mediaID: MediaID,
        bypassCache: Bool = false
    ) async throws -> MediaDetail {
        // Check cache first
        if !bypassCache {
            if let cached = await cache.getDetail(
                for: mediaID,
                allowExpired: await isOffline()
            ) {
                Log.cache.info("Using cached detail for \(mediaID)")
                return cached
            }
        }

        let params = TMDBRequest.detailParameters(for: mediaID.type)

        let detail: MediaDetail
        switch mediaID.type {
        case .movie:
            let response = try await networkClient.fetch(
                TMDBMovieDetailDTO.self,
                from: mediaID.type.detailPath(id: mediaID.id),
                parameters: params
            )
            detail = response.toMediaDetail()

        case .tv:
            let response = try await networkClient.fetch(
                TMDBTVDetailDTO.self,
                from: mediaID.type.detailPath(id: mediaID.id),
                parameters: params
            )
            detail = response.toMediaDetail()
        }

        // Update cache
        await cache.setDetail(detail, for: mediaID)

        return detail
    }

    // MARK: - Genres

    /// Fetches genre list for a media type.
    ///
    /// - Parameters:
    ///   - mediaType: Movie or TV
    ///   - bypassCache: If true, skips cache
    /// - Returns: Array of genres
    /// - Throws: NetworkError on failure
    func fetchGenres(for mediaType: MediaType, bypassCache: Bool = false) async throws -> [Genre] {
        // Check cache first
        if !bypassCache {
            if let cached = await cache.getGenres(
                for: mediaType,
                allowExpired: await isOffline()
            ) {
                Log.cache.info("Using cached genres for \(mediaType)")
                return cached
            }
        }

        let response = try await networkClient.fetch(
            TMDBGenreListDTO.self,
            from: mediaType.genreListPath
        )

        let genres = response.toGenres()

        // Update cache
        await cache.setGenres(genres, for: mediaType)

        return genres
    }

    /// Fetches both movie and TV genres.
    ///
    /// - Parameter bypassCache: If true, skips cache
    /// - Returns: Tuple of movie and TV genres
    /// - Throws: NetworkError on failure
    func fetchAllGenres(bypassCache: Bool = false) async throws -> (movie: [Genre], tv: [Genre]) {
        async let movieGenres = fetchGenres(for: .movie, bypassCache: bypassCache)
        async let tvGenres = fetchGenres(for: .tv, bypassCache: bypassCache)

        return try await (movieGenres, tvGenres)
    }

    // MARK: - Cache Management

    /// Clears all cached data.
    func clearCache() async {
        await cache.clearAllCaches()
    }

    /// Clears only memory cache (for memory warnings).
    func clearMemoryCache() async {
        await cache.clearMemoryCache()
    }
}

// MARK: - Content Fetcher Protocol

/// Protocol for content fetching (enables testing).
protocol ContentFetching: Actor {
    func fetchTrending(mediaType: MediaType?, page: Int, bypassCache: Bool) async throws -> (items: [MediaSummary], hasMore: Bool)
    func fetchDiscover(filterState: FilterState, page: Int, bypassCache: Bool) async throws -> (items: [MediaSummary], hasMore: Bool, movieHasMore: Bool, tvHasMore: Bool)
    func fetchDetail(for mediaID: MediaID, bypassCache: Bool) async throws -> MediaDetail
    func fetchGenres(for mediaType: MediaType, bypassCache: Bool) async throws -> [Genre]
}

extension TMDBService: ContentFetching {}
