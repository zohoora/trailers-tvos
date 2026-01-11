// MARK: - WatchlistService.swift
// Trailers - tvOS App
// Service for managing watchlist via local server

import Foundation
import UIKit

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

    /// Device identifier for per-device watchlists.
    private let deviceID: String

    // MARK: - Initialization

    private init() {
        self.deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }

    // MARK: - Public Methods

    /// Checks if a media item is on the watchlist.
    ///
    /// - Parameter mediaID: The media ID to check
    /// - Returns: True if the item is on the watchlist
    func isOnWatchlist(mediaID: MediaID) async -> Bool {
        let serverURL = Config.youtubeServerURL
        let mediaType = mediaID.type == .movie ? "movie" : "tv"

        guard let url = URL(string: "\(serverURL)/watchlist/check/\(mediaType)/\(mediaID.id)?device_id=\(deviceID)") else {
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

        let payload: [String: Any] = [
            "media_id": mediaID.id,
            "media_type": mediaID.type == .movie ? "movie" : "tv",
            "media_title": title,
            "device_id": deviceID
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

        guard let url = URL(string: "\(serverURL)/watchlist/\(mediaType)/\(mediaID.id)?device_id=\(deviceID)") else {
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
}
