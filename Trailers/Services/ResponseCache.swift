// MARK: - ResponseCache.swift
// Trailers - tvOS App
// Two-tier caching system with memory and disk layers

import Foundation
import CryptoKit

// MARK: - Cache Entry

/// A cached response with metadata.
struct CacheEntry: Codable {
    /// When this entry was stored.
    let storedAt: Date

    /// The cached data payload.
    let payload: Data

    /// The cache key for this entry.
    let key: String

    /// Returns true if this entry has expired based on the given TTL.
    func isExpired(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(storedAt) > ttl
    }

    /// Age of this entry in seconds.
    var age: TimeInterval {
        Date().timeIntervalSince(storedAt)
    }
}

// MARK: - Cache Key Builder

/// Builds consistent cache keys for TMDB API requests.
enum CacheKeyBuilder {

    /// Creates a cache key for a grid/list request.
    ///
    /// Format: `grid|contentType|sort|genreMovie|genreTV|cert|dateRange|page`
    ///
    /// - Parameters:
    ///   - filterState: Current filter state
    ///   - page: Page number
    /// - Returns: Cache key string
    static func gridKey(for filterState: FilterState, page: Int) -> String {
        let parts = [
            "grid",
            filterState.contentType.rawValue,
            filterState.sort.rawValue,
            filterState.genre?.movieGenreID.map(String.init) ?? "nil",
            filterState.genre?.tvGenreID.map(String.init) ?? "nil",
            filterState.certification ?? "nil",
            filterState.dateRange.rawValue,
            String(page)
        ]
        return parts.joined(separator: "|")
    }

    /// Creates a cache key for a detail request.
    ///
    /// Format: `detail|type|id`
    ///
    /// - Parameter mediaID: The media identifier
    /// - Returns: Cache key string
    static func detailKey(for mediaID: MediaID) -> String {
        "detail|\(mediaID.type.rawValue)|\(mediaID.id)"
    }

    /// Creates a cache key for genre lists.
    ///
    /// Format: `genres|type`
    ///
    /// - Parameter mediaType: Movie or TV
    /// - Returns: Cache key string
    static func genresKey(for mediaType: MediaType) -> String {
        "genres|\(mediaType.rawValue)"
    }

    /// Hashes a cache key for filesystem-safe storage.
    ///
    /// - Parameter key: The cache key to hash
    /// - Returns: SHA256 hash as hex string
    static func hash(_ key: String) -> String {
        let data = Data(key.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Response Cache Actor

/// Two-tier cache with memory and disk layers.
///
/// ## Overview
/// ResponseCache provides fast access to API responses through:
/// - **Memory Cache**: NSCache for recently accessed items
/// - **Disk Cache**: Filesystem storage for persistence
///
/// ## TTL Strategy
/// Different content types have different TTLs:
/// - Genres: 7 days (rarely change)
/// - Grid content: 5 minutes (fresh but cacheable)
/// - Detail content: 30 minutes (moderate freshness)
///
/// ## Offline Support
/// When offline, expired cache entries can still be returned
/// to provide stale-but-useful data.
///
/// ## Thread Safety
/// Implemented as an actor for thread-safe access.
actor ResponseCache {

    // MARK: - Types

    /// Cache type determines TTL and storage strategy.
    enum CacheType {
        case genres
        case grid
        case detail

        var ttl: TimeInterval {
            switch self {
            case .genres:
                return Config.CacheTTL.genres
            case .grid:
                return Config.CacheTTL.grid
            case .detail:
                return Config.CacheTTL.detail
            }
        }
    }

    // MARK: - Properties

    /// Memory cache using NSCache.
    private let memoryCache = NSCache<NSString, NSData>()

    /// Disk cache directory URL.
    private let diskCacheURL: URL

    /// File manager for disk operations.
    private let fileManager = FileManager.default

    /// JSON encoder for cache entries.
    private let encoder = JSONEncoder()

    /// JSON decoder for cache entries.
    private let decoder = JSONDecoder()

    // MARK: - Initialization

    /// Creates a new ResponseCache.
    ///
    /// - Parameter subdirectory: Subdirectory name within Caches folder
    init(subdirectory: String = "APIResponseCache") {
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.diskCacheURL = cacheDir.appendingPathComponent(subdirectory, isDirectory: true)

        // Ensure cache directory exists
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Configure memory cache limits
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    // MARK: - Public API

    /// Retrieves a cached value if available and not expired.
    ///
    /// - Parameters:
    ///   - type: The type to decode
    ///   - key: The cache key
    ///   - cacheType: The cache type (determines TTL)
    ///   - allowExpired: If true, returns expired entries (for offline use)
    /// - Returns: Cached value, or nil if not found or expired
    func get<T: Decodable>(
        _ type: T.Type,
        forKey key: String,
        cacheType: CacheType,
        allowExpired: Bool = false
    ) -> T? {
        let hashedKey = CacheKeyBuilder.hash(key)

        // Try memory cache first
        if let data = memoryCache.object(forKey: hashedKey as NSString) as Data?,
           let entry = try? decoder.decode(CacheEntry.self, from: data) {

            if !entry.isExpired(ttl: cacheType.ttl) || allowExpired {
                Log.cache.logCache("memory hit", key: key)
                return try? JSONDecoder().decode(type, from: entry.payload)
            } else {
                Log.cache.logCache("memory expired", key: key)
                memoryCache.removeObject(forKey: hashedKey as NSString)
            }
        }

        // Try disk cache
        let fileURL = diskCacheURL.appendingPathComponent(hashedKey)
        guard let data = try? Data(contentsOf: fileURL),
              let entry = try? decoder.decode(CacheEntry.self, from: data) else {
            Log.cache.logCache("miss", key: key)
            return nil
        }

        if entry.isExpired(ttl: cacheType.ttl) && !allowExpired {
            Log.cache.logCache("disk expired", key: key)
            try? fileManager.removeItem(at: fileURL)
            return nil
        }

        // Promote to memory cache
        memoryCache.setObject(data as NSData, forKey: hashedKey as NSString)

        Log.cache.logCache("disk hit", key: key)
        return try? JSONDecoder().decode(type, from: entry.payload)
    }

    /// Stores a value in the cache.
    ///
    /// - Parameters:
    ///   - value: The value to cache
    ///   - key: The cache key
    func set<T: Encodable>(_ value: T, forKey key: String) {
        let hashedKey = CacheKeyBuilder.hash(key)

        guard let payload = try? JSONEncoder().encode(value) else {
            Log.cache.logError("Failed to encode value for key: \(key)")
            return
        }

        let entry = CacheEntry(storedAt: Date(), payload: payload, key: key)

        guard let entryData = try? encoder.encode(entry) else {
            Log.cache.logError("Failed to encode cache entry for key: \(key)")
            return
        }

        // Store in memory cache
        memoryCache.setObject(entryData as NSData, forKey: hashedKey as NSString)

        // Store on disk
        let fileURL = diskCacheURL.appendingPathComponent(hashedKey)
        do {
            try entryData.write(to: fileURL, options: .atomic)
            Log.cache.logCache("stored", key: key)
        } catch {
            Log.cache.logError("Failed to write cache to disk", error: error)
        }
    }

    /// Removes a specific entry from the cache.
    ///
    /// - Parameter key: The cache key to remove
    func remove(forKey key: String) {
        let hashedKey = CacheKeyBuilder.hash(key)

        memoryCache.removeObject(forKey: hashedKey as NSString)

        let fileURL = diskCacheURL.appendingPathComponent(hashedKey)
        try? fileManager.removeItem(at: fileURL)

        Log.cache.logCache("removed", key: key)
    }

    /// Clears all entries from the memory cache.
    ///
    /// Used to free memory on memory warning.
    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        Log.cache.info("Memory cache cleared")
    }

    /// Clears all entries from both memory and disk caches.
    func clearAllCaches() {
        memoryCache.removeAllObjects()

        if let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil) {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }

        Log.cache.info("All caches cleared")
    }

    /// Removes expired entries from disk cache.
    ///
    /// - Parameter olderThan: Maximum age in seconds (defaults to 7 days)
    func pruneExpiredEntries(olderThan maxAge: TimeInterval = 7 * 24 * 60 * 60) {
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }

        let now = Date()
        var prunedCount = 0

        for fileURL in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let modDate = attributes[.modificationDate] as? Date else {
                continue
            }

            if now.timeIntervalSince(modDate) > maxAge {
                try? fileManager.removeItem(at: fileURL)
                prunedCount += 1
            }
        }

        if prunedCount > 0 {
            Log.cache.info("Pruned \(prunedCount) expired cache entries")
        }
    }

    /// Returns the total size of the disk cache in bytes.
    func diskCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        return files.reduce(0) { total, fileURL in
            let size = (try? fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
            return total + size
        }
    }
}

// MARK: - Convenience Extensions

extension ResponseCache {

    /// Gets grid content from cache.
    func getGridContent(for filterState: FilterState, page: Int, allowExpired: Bool = false) -> [MediaSummary]? {
        let key = CacheKeyBuilder.gridKey(for: filterState, page: page)
        return get([MediaSummary].self, forKey: key, cacheType: .grid, allowExpired: allowExpired)
    }

    /// Stores grid content in cache.
    func setGridContent(_ items: [MediaSummary], for filterState: FilterState, page: Int) {
        let key = CacheKeyBuilder.gridKey(for: filterState, page: page)
        set(items, forKey: key)
    }

    /// Gets detail content from cache.
    func getDetail(for mediaID: MediaID, allowExpired: Bool = false) -> MediaDetail? {
        let key = CacheKeyBuilder.detailKey(for: mediaID)
        return get(MediaDetail.self, forKey: key, cacheType: .detail, allowExpired: allowExpired)
    }

    /// Stores detail content in cache.
    func setDetail(_ detail: MediaDetail, for mediaID: MediaID) {
        let key = CacheKeyBuilder.detailKey(for: mediaID)
        set(detail, forKey: key)
    }

    /// Gets genre list from cache.
    func getGenres(for mediaType: MediaType, allowExpired: Bool = false) -> [Genre]? {
        let key = CacheKeyBuilder.genresKey(for: mediaType)
        return get([Genre].self, forKey: key, cacheType: .genres, allowExpired: allowExpired)
    }

    /// Stores genre list in cache.
    func setGenres(_ genres: [Genre], for mediaType: MediaType) {
        let key = CacheKeyBuilder.genresKey(for: mediaType)
        set(genres, forKey: key)
    }
}
