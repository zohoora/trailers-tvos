// MARK: - AnalyticsService.swift
// Trailers - tvOS App
// Analytics logging service for viewing behavior tracking

import Foundation
import UIKit

/// Helper to get device ID on main actor.
@MainActor
private enum AnalyticsDeviceIDProvider {
    static var deviceID: String {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }
}

/// Service for logging viewing analytics to the local server.
///
/// ## Overview
/// AnalyticsService sends playback events to the local yt-dlp server for future
/// recommendation algorithm development. All data stays local.
///
/// ## Events Tracked
/// - `play_start`: When a trailer begins playing
/// - `play_end`: When playback ends (with duration)
/// - `skip`: When user skips to next trailer
///
/// ## Usage
/// ```swift
/// let analytics = AnalyticsService.shared
/// analytics.logPlayStart(video: trailer, mediaTitle: "Inception", mediaID: mediaID)
/// // ... playback occurs ...
/// analytics.logPlayEnd(video: trailer, watchDuration: 45.0, totalDuration: 120.0)
/// ```
actor AnalyticsService {

    // MARK: - Singleton

    /// Shared instance for app-wide analytics.
    static let shared = AnalyticsService()

    // MARK: - Properties

    /// Current session ID (generated once per app launch).
    private let sessionID: String

    /// Device identifier for analytics (lazily initialized).
    private var _deviceID: String?

    /// Gets the device ID, initializing it on first access.
    private var deviceID: String {
        get async {
            if let id = _deviceID {
                return id
            }
            let id = await AnalyticsDeviceIDProvider.deviceID
            _deviceID = id
            return id
        }
    }

    /// Timestamp when session started.
    private let sessionStartTime: Date

    // MARK: - Initialization

    private init() {
        self.sessionID = UUID().uuidString
        self.sessionStartTime = Date()

        // Register session with server
        Task {
            await registerSession()
        }
    }

    // MARK: - Session Management

    /// Registers a new analytics session with the server.
    private func registerSession() async {
        let serverURL = Config.youtubeServerURL
        guard let url = URL(string: "\(serverURL)/analytics/session") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let id = await deviceID
        let payload: [String: Any] = [
            "session_id": sessionID,
            "device_id": id,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "platform": "tvOS",
            "timestamp": ISO8601DateFormatter().string(from: sessionStartTime)
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("[Analytics] Session registered: \(sessionID.prefix(8))...")
            }
        } catch {
            print("[Analytics] Failed to register session: \(error.localizedDescription)")
        }
    }

    // MARK: - Event Logging

    /// Logs when a trailer starts playing.
    ///
    /// - Parameters:
    ///   - video: The video being played
    ///   - mediaTitle: Title of the movie/TV show
    ///   - mediaID: The MediaID of the content
    ///   - quality: Video quality being streamed
    func logPlayStart(
        video: Video,
        mediaTitle: String,
        mediaID: MediaID,
        quality: String = Config.youtubePreferredQuality
    ) async {
        await sendEvent(
            eventType: "play_start",
            video: video,
            mediaTitle: mediaTitle,
            mediaID: mediaID,
            quality: quality,
            watchDuration: nil,
            totalDuration: nil
        )
    }

    /// Logs when trailer playback ends.
    ///
    /// - Parameters:
    ///   - video: The video that was playing
    ///   - mediaTitle: Title of the movie/TV show
    ///   - mediaID: The MediaID of the content
    ///   - watchDuration: How long the user watched (seconds)
    ///   - totalDuration: Total video duration (seconds)
    ///   - completed: Whether the video completed naturally
    func logPlayEnd(
        video: Video,
        mediaTitle: String,
        mediaID: MediaID,
        watchDuration: TimeInterval,
        totalDuration: TimeInterval,
        completed: Bool
    ) async {
        let eventType = completed ? "play_complete" : "play_end"
        await sendEvent(
            eventType: eventType,
            video: video,
            mediaTitle: mediaTitle,
            mediaID: mediaID,
            quality: nil,
            watchDuration: watchDuration,
            totalDuration: totalDuration
        )
    }

    /// Logs when user skips a trailer.
    ///
    /// - Parameters:
    ///   - video: The video being skipped
    ///   - mediaTitle: Title of the movie/TV show
    ///   - mediaID: The MediaID of the content
    ///   - watchDuration: How long they watched before skipping
    func logSkip(
        video: Video,
        mediaTitle: String,
        mediaID: MediaID,
        watchDuration: TimeInterval
    ) async {
        await sendEvent(
            eventType: "skip",
            video: video,
            mediaTitle: mediaTitle,
            mediaID: mediaID,
            quality: nil,
            watchDuration: watchDuration,
            totalDuration: nil
        )
    }

    // MARK: - Private Methods

    /// Sends an analytics event to the server.
    private func sendEvent(
        eventType: String,
        video: Video,
        mediaTitle: String,
        mediaID: MediaID,
        quality: String?,
        watchDuration: TimeInterval?,
        totalDuration: TimeInterval?
    ) async {
        let serverURL = Config.youtubeServerURL
        guard let url = URL(string: "\(serverURL)/analytics/event") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let id = await deviceID
        var payload: [String: Any] = [
            "session_id": sessionID,
            "device_id": id,
            "event_type": eventType,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "video": [
                "id": video.id,
                "key": video.key,
                "name": video.name,
                "type": video.type,
                "site": video.site,
                "size": video.size as Any,
                "official": video.official
            ],
            "media": [
                "id": mediaID.id,
                "type": mediaID.type.rawValue,
                "title": mediaTitle
            ]
        ]

        if let quality = quality {
            payload["quality"] = quality
        }

        if let watchDuration = watchDuration {
            payload["watch_duration"] = watchDuration
        }

        if let totalDuration = totalDuration {
            payload["total_duration"] = totalDuration

            // Calculate engagement level
            if watchDuration != nil {
                let ratio = watchDuration! / totalDuration
                let engagement: String
                if ratio >= 0.9 {
                    engagement = "completed"
                } else if ratio >= 0.5 {
                    engagement = "high"
                } else if ratio >= 0.25 {
                    engagement = "medium"
                } else if ratio >= 0.1 {
                    engagement = "low"
                } else {
                    engagement = "skipped"
                }
                payload["engagement_level"] = engagement
            }
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("[Analytics] Event logged: \(eventType) for '\(video.name)'")
            }
        } catch {
            // Silently fail - analytics should not interrupt playback
            print("[Analytics] Failed to log event: \(error.localizedDescription)")
        }
    }
}

