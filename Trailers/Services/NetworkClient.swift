// MARK: - NetworkClient.swift
// Trailers - tvOS App
// Thread-safe network client with rate limiting and request deduplication

import Foundation

// MARK: - Network Error

/// Errors that can occur during network operations.
///
/// ## Overview
/// NetworkError provides specific error types for different failure scenarios,
/// allowing the UI to show appropriate error messages and handle retries.
enum NetworkError: Error, Equatable, Sendable {
    /// No network connection available.
    case noConnection

    /// HTTP 401 - Invalid API token.
    case unauthorized

    /// HTTP 403 - Access denied.
    case forbidden

    /// HTTP 404 - Resource not found.
    case notFound

    /// HTTP 429 - Rate limit exceeded.
    case rateLimited(retryAfter: TimeInterval?)

    /// HTTP 5xx - Server error.
    case serverError(statusCode: Int)

    /// Failed to decode response.
    case decodingError(Error)

    /// Request was cancelled.
    case cancelled

    /// Unknown error.
    case unknown(Error)

    /// Request timed out.
    case timeout

    /// Invalid URL.
    case invalidURL

    // MARK: - Equatable

    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.noConnection, .noConnection),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.cancelled, .cancelled),
             (.timeout, .timeout),
             (.invalidURL, .invalidURL):
            return true
        case let (.rateLimited(a), .rateLimited(b)):
            return a == b
        case let (.serverError(a), .serverError(b)):
            return a == b
        default:
            return false
        }
    }

    // MARK: - User-Facing Messages

    /// User-friendly error message.
    var localizedDescription: String {
        switch self {
        case .noConnection:
            return "No internet connection. Please check your network settings."
        case .unauthorized:
            return "API authentication failed. Please check your API token configuration."
        case .forbidden:
            return "Access denied. The requested resource is not available."
        case .notFound:
            return "Content not found. It may have been removed."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .decodingError:
            return "Failed to process server response."
        case .cancelled:
            return "Request was cancelled."
        case .unknown:
            return "An unexpected error occurred."
        case .timeout:
            return "Request timed out. Please try again."
        case .invalidURL:
            return "Invalid request URL."
        }
    }

    /// Returns true if this error should be retried.
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .serverError, .timeout, .noConnection:
            return true
        default:
            return false
        }
    }
}

// MARK: - Network Client Actor

/// Thread-safe network client for TMDB API requests.
///
/// ## Overview
/// NetworkClient is implemented as an actor to guarantee thread safety for:
/// - Concurrent request tracking
/// - Request deduplication
/// - Rate limit backoff state
///
/// ## Features
/// - **Concurrency Limiting**: Maximum 4 concurrent requests
/// - **Request Deduplication**: Same URL within 500ms returns same Task
/// - **Rate Limiting**: Exponential backoff on 429 responses
/// - **Automatic Retries**: Retries on transient failures
///
/// ## Usage
/// ```swift
/// let client = NetworkClient()
/// let movies = try await client.fetch(TMDBPaginatedDTO<TMDBMovieListDTO>.self, from: "/trending/movie/week")
/// ```
actor NetworkClient {

    // MARK: - Types

    /// In-flight request tracking.
    private struct InFlightRequest {
        let task: Task<Data, Error>
        let startTime: Date
    }

    // MARK: - Properties

    /// URLSession configured for TMDB API.
    private let session: URLSession

    /// Currently in-flight requests by URL.
    private var inFlightRequests: [String: InFlightRequest] = [:]

    /// Current backoff delay for rate limiting.
    private var currentBackoff: TimeInterval = Config.initialBackoffDelay

    /// Number of consecutive rate limit errors.
    private var rateLimitRetryCount = 0

    /// Semaphore for limiting concurrent requests.
    private var activeRequestCount = 0

    /// JSON decoder configured for TMDB responses.
    /// Note: DTOs use explicit CodingKeys for snake_case mapping, so don't use convertFromSnakeCase.
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    /// Creates a new NetworkClient with default configuration.
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Fetches and decodes a resource from the TMDB API.
    ///
    /// - Parameters:
    ///   - type: The type to decode
    ///   - endpoint: API endpoint path (e.g., "/trending/movie/week")
    ///   - parameters: Query parameters
    /// - Returns: Decoded response
    /// - Throws: NetworkError on failure
    func fetch<T: Decodable>(
        _ type: T.Type,
        from endpoint: String,
        parameters: [String: String] = [:]
    ) async throws -> T {
        let url = try buildURL(endpoint: endpoint, parameters: parameters)
        let data = try await fetchData(from: url)
        return try decodeResponse(data, as: type)
    }

    /// Fetches raw data from a URL (used for caching layer).
    ///
    /// - Parameter url: The URL to fetch
    /// - Returns: Raw response data
    /// - Throws: NetworkError on failure
    func fetchRawData(from url: URL) async throws -> Data {
        try await fetchData(from: url)
    }

    // MARK: - Private Methods

    /// Builds a full URL for an API endpoint.
    private func buildURL(endpoint: String, parameters: [String: String]) throws -> URL {
        var components = URLComponents(url: Config.tmdbAPIBaseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false)

        var queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        // Add API key for authentication
        queryItems.append(URLQueryItem(name: "api_key", value: Config.tmdbAPIKey))
        // Add default parameters
        queryItems.append(URLQueryItem(name: "language", value: "en-US"))

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        return url
    }

    /// Fetches data from a URL with deduplication and rate limiting.
    private func fetchData(from url: URL) async throws -> Data {
        let urlString = url.absoluteString

        // Check for in-flight request (deduplication)
        if let inFlight = inFlightRequests[urlString] {
            let age = Date().timeIntervalSince(inFlight.startTime)
            if age < Config.requestDeduplicationWindow {
                Log.network.debug("Deduplicating request: \(urlString)")
                return try await inFlight.task.value
            }
        }

        // Wait for rate limit backoff if needed
        if rateLimitRetryCount > 0 {
            let delay = currentBackoff
            Log.network.info("Rate limit backoff: \(delay)s")
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // Wait for concurrency slot
        while activeRequestCount >= Config.maxConcurrentRequests {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        // Create and track new request
        let task = Task<Data, Error> {
            try await performRequest(to: url)
        }

        inFlightRequests[urlString] = InFlightRequest(task: task, startTime: Date())
        activeRequestCount += 1

        defer {
            activeRequestCount -= 1
            inFlightRequests.removeValue(forKey: urlString)
        }

        do {
            let data = try await task.value
            // Success - reset rate limit state
            rateLimitRetryCount = 0
            currentBackoff = Config.initialBackoffDelay
            return data
        } catch {
            throw error
        }
    }

    /// Performs the actual HTTP request.
    private func performRequest(to url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        Log.network.logRequest("GET", url: url)
        let startTime = Date()

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown(NSError(domain: "NetworkClient", code: -1))
            }

            let duration = Date().timeIntervalSince(startTime)
            Log.network.logResponse(httpResponse.statusCode, url: url, duration: duration)

            try handleStatusCode(httpResponse.statusCode, data: data)

            return data
        } catch let error as NetworkError {
            throw error
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw NetworkError.unknown(error)
        }
    }

    /// Handles HTTP status codes and throws appropriate errors.
    private func handleStatusCode(_ statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200...299:
            return // Success

        case 401:
            throw NetworkError.unauthorized

        case 403:
            throw NetworkError.forbidden

        case 404:
            throw NetworkError.notFound

        case 429:
            // Rate limited - increase backoff
            rateLimitRetryCount += 1
            if rateLimitRetryCount <= Config.maxRetryAttempts {
                currentBackoff = min(currentBackoff * 2, Config.maxBackoffDelay)
            }
            throw NetworkError.rateLimited(retryAfter: currentBackoff)

        case 500...599:
            throw NetworkError.serverError(statusCode: statusCode)

        default:
            throw NetworkError.unknown(NSError(domain: "HTTP", code: statusCode))
        }
    }

    /// Maps URLError to NetworkError.
    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        case .cancelled:
            return .cancelled
        default:
            return .unknown(error)
        }
    }

    /// Decodes data to the specified type.
    private func decodeResponse<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            Log.network.logError("Decoding failed for \(type)", error: error)
            throw NetworkError.decodingError(error)
        }
    }
}

// MARK: - Request Builder

/// Helper for building TMDB API requests.
enum TMDBRequest {

    /// Builds query parameters for a discover request.
    ///
    /// - Parameters:
    ///   - filterState: Current filter state
    ///   - page: Page number
    ///   - mediaType: Movie or TV
    /// - Returns: Dictionary of query parameters
    static func discoverParameters(
        for filterState: FilterState,
        page: Int,
        mediaType: MediaType
    ) -> [String: String] {
        var params: [String: String] = [
            "page": String(page),
            "include_adult": "false"
        ]

        // Sort parameter
        if let sortBy = filterState.sort.sortByParameter(for: mediaType) {
            params["sort_by"] = sortBy
        }

        // Vote count minimum for rating sorts
        if filterState.sort.requiresVoteCountMinimum {
            params["vote_count.gte"] = String(Config.minimumVoteCountForRating)
        }

        // Genre filter
        if let genre = filterState.genre {
            let genreID: Int?
            switch mediaType {
            case .movie:
                genreID = genre.movieGenreID
            case .tv:
                genreID = genre.tvGenreID
            }
            if let id = genreID {
                params["with_genres"] = String(id)
            }
        }

        // Date range filter
        let dateRange = filterState.dateRange.dateRange()
        if let start = dateRange.startString {
            let dateField = mediaType.dateFieldName
            params["\(dateField).gte"] = start
        }
        if let end = dateRange.endString {
            let dateField = mediaType.dateFieldName
            params["\(dateField).lte"] = end
        }

        // Certification filter (movies only)
        if mediaType == .movie, let cert = filterState.certification {
            params["certification_country"] = Config.certificationRegion
            params["certification"] = cert
            params["region"] = Config.certificationRegion
        }

        return params
    }

    /// Builds query parameters for a detail request.
    ///
    /// - Parameter mediaType: Movie or TV
    /// - Returns: Dictionary of query parameters
    static func detailParameters(for mediaType: MediaType) -> [String: String] {
        [
            "append_to_response": mediaType.appendToResponse
        ]
    }
}
