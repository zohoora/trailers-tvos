// MARK: - WatchlistService.swift
// Trailers - tvOS App
// Service for managing watchlist via local server

import Foundation
import UIKit

/// Helper to get device ID on main actor.
@MainActor
private enum DeviceIDProvider {
    static var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
}

/// Service for managing the user's watchlist via the local server.
///
/// ## Overview
/// WatchlistService communicates with the local yt-dlp server to add, remove,
/// and check items on the user's watchlist. Data is stored server-side.
///
/// ## Usage
/// ```swift
/// let isOnList = await WatchlistService.shared.isOnWatchlist(mediaID: id)
/// let success = await WatchlistService.shared.addToWatchlist(mediaID: id, title: "Movie")
/// ```
actor WatchlistService {

    // MARK: - Singleton

    /// Shared instance for app-wide watchlist access.
    static let shared = WatchlistService()

    // MARK: - Properties

    /// Device identifier for per-device watchlists (lazily initialized).
    private var _deviceID: String?

    /// Gets the device ID, initializing it on first access.
    private var deviceID: String {
        get async {
            if let id = _deviceID {
                return id
            }
            let id = await DeviceIDProvider.deviceID
            _deviceID = id
            return id
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Checks if a media item is on the watchlist.
    ///
    /// - Parameter mediaID: The media ID to check
    /// - Returns: True if the item is on the watchlist
    func isOnWatchlist(mediaID: MediaID) async -> Bool {
        let serverURL = Config.youtubeServerURL
        let mediaType = mediaID.type == .movie ? "movie" : "tv"
        let id = await deviceID

        guard let url = URL(string: "\(serverURL)/watchlist/check/\(mediaType)/\(mediaID.id)?device_id=\(id)") else {
            return false
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let isOnWatchlist = json["is_on_watchlist"] as? Bool else {
                return false
            }

            return isOnWatchlist
        } catch {
            print("[Watchlist] Failed to check status: \(error.localizedDescription)")
            return false
        }
    }

    /// Adds a media item to the watchlist.
    ///
    /// - Parameters:
    ///   - mediaID: The media ID to add
    ///   - title: The title of the media
    /// - Returns: True if successfully added
    func addToWatchlist(mediaID: MediaID, title: String) async -> Bool {
        let serverURL = Config.youtubeServerURL
        guard let url = URL(string: "\(serverURL)/watchlist/add") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let id = await deviceID
        let payload: [String: Any] = [
            "media_id": mediaID.id,
            "media_type": mediaID.type == .movie ? "movie" : "tv",
            "media_title": title,
            "device_id": id
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String,
                  status == "added" else {
                return false
            }

            print("[Watchlist] Added: \(title)")
            return true
        } catch {
            print("[Watchlist] Failed to add: \(error.localizedDescription)")
            return false
        }
    }

    /// Removes a media item from the watchlist.
    ///
    /// - Parameter mediaID: The media ID to remove
    /// - Returns: True if successfully removed
    func removeFromWatchlist(mediaID: MediaID) async -> Bool {
        let serverURL = Config.youtubeServerURL
        let mediaType = mediaID.type == .movie ? "movie" : "tv"
        let id = await deviceID

        guard let url = URL(string: "\(serverURL)/watchlist/\(mediaType)/\(mediaID.id)?device_id=\(id)") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String,
                  status == "removed" else {
                return false
            }

            print("[Watchlist] Removed: \(mediaID)")
            return true
        } catch {
            print("[Watchlist] Failed to remove: \(error.localizedDescription)")
            return false
        }
    }

    /// Fetches all items on the watchlist.
    ///
    /// - Returns: Array of watchlist items, empty if none or on error
    func fetchWatchlist() async -> [WatchlistItem] {
        let serverURL = Config.youtubeServerURL
        let id = await deviceID
        guard let url = URL(string: "\(serverURL)/watchlist/list?device_id=\(id)") else {
            return []
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }

            let result = try JSONDecoder().decode(WatchlistResponse.self, from: data)
            print("[Watchlist] Fetched \(result.items.count) items")
            return result.items
        } catch {
            print("[Watchlist] Failed to fetch list: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Watchlist Models

/// Response from the watchlist list endpoint.
struct WatchlistResponse: Decodable {
    let totalItems: Int
    let deviceId: String
    let items: [WatchlistItem]

    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items"
        case deviceId = "device_id"
        case items
    }
}

/// A single item on the watchlist.
struct WatchlistItem: Identifiable, Decodable, Sendable, Hashable {
    let mediaId: Int
    let mediaType: String
    let mediaTitle: String
    let addedAt: String?

    enum CodingKeys: String, CodingKey {
        case mediaId = "media_id"
        case mediaType = "media_type"
        case mediaTitle = "media_title"
        case addedAt = "added_at"
    }

    /// Unique identifier for the item.
    var id: String {
        "\(mediaType)_\(mediaId)"
    }

    /// Converts to MediaID for navigation.
    var mediaID: MediaID {
        MediaID(type: mediaType == "movie" ? .movie : .tv, id: mediaId)
    }
}
