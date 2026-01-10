// MARK: - MediaID.swift
// Trailers - tvOS App
// Unique identifier for media items combining type and TMDB ID

import Foundation

/// A unique identifier for media content combining type and TMDB ID.
///
/// ## Overview
/// MediaID ensures proper deduplication and routing by combining:
/// - The media type (movie or TV)
/// - The TMDB numeric ID
///
/// This is necessary because TMDB uses separate ID spaces for movies and TV shows,
/// meaning a movie and TV show could share the same numeric ID.
///
/// ## Usage
/// ```swift
/// let movieID = MediaID(type: .movie, id: 12345)
/// let tvID = MediaID(type: .tv, id: 12345)
/// print(movieID == tvID) // false - different types
///
/// // Use in NavigationStack
/// NavigationStack {
///     ContentGridView()
///         .navigationDestination(for: MediaID.self) { id in
///             DetailView(mediaID: id)
///         }
/// }
/// ```
///
/// ## Hashable Implementation
/// MediaID is hashable based on both type and id, making it suitable for:
/// - Set membership (deduplication)
/// - Dictionary keys (caching)
/// - NavigationStack paths
struct MediaID: Hashable, Sendable {

    // MARK: - Properties

    /// The type of media (movie or TV show).
    let type: MediaType

    /// The TMDB numeric identifier.
    ///
    /// - Note: This ID is only unique within a media type.
    let id: Int

    // MARK: - Initialization

    /// Creates a new MediaID.
    ///
    /// - Parameters:
    ///   - type: The media type
    ///   - id: The TMDB numeric ID
    init(type: MediaType, id: Int) {
        self.type = type
        self.id = id
    }

    // MARK: - Computed Properties

    /// A string representation suitable for cache keys or logging.
    ///
    /// Format: "movie-12345" or "tv-12345"
    var cacheKey: String {
        "\(type.rawValue)-\(id)"
    }

    /// The TMDB web URL for this media item.
    var tmdbURL: URL {
        URL(string: "https://www.themoviedb.org/\(type.rawValue)/\(id)")!
    }
}

// MARK: - Identifiable

extension MediaID: Identifiable {
    /// The stable identity for SwiftUI views.
    ///
    /// Uses the cache key format for uniqueness.
    var stableID: String { cacheKey }
}

// MARK: - Codable

extension MediaID: Codable {
    /// Coding keys for JSON encoding/decoding.
    enum CodingKeys: String, CodingKey {
        case type
        case id
    }

    /// Creates a MediaID by decoding from a decoder.
    ///
    /// - Parameter decoder: The decoder to read from
    /// - Throws: DecodingError if the data is invalid
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(MediaType.self, forKey: .type)
        self.id = try container.decode(Int.self, forKey: .id)
    }

    /// Encodes this MediaID to an encoder.
    ///
    /// - Parameter encoder: The encoder to write to
    /// - Throws: EncodingError if encoding fails
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(id, forKey: .id)
    }
}

// MARK: - CustomStringConvertible

extension MediaID: CustomStringConvertible {
    var description: String {
        "\(type.displayName) #\(id)"
    }
}

// MARK: - CustomDebugStringConvertible

extension MediaID: CustomDebugStringConvertible {
    var debugDescription: String {
        "MediaID(\(type.rawValue), \(id))"
    }
}

// MARK: - Comparable

extension MediaID: Comparable {
    /// Comparison for stable ordering.
    ///
    /// Orders by type first (movies before TV), then by ID ascending.
    static func < (lhs: MediaID, rhs: MediaID) -> Bool {
        if lhs.type != rhs.type {
            // Movies before TV shows
            return lhs.type == .movie
        }
        return lhs.id < rhs.id
    }
}
