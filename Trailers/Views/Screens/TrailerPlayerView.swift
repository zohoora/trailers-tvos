// MARK: - TrailerPlayerView.swift
// Trailers - tvOS App
// In-app YouTube video player using local yt-dlp server + AVPlayer
// NOTE: For personal use only

import SwiftUI
import AVKit

/// Full-screen trailer player that plays YouTube videos via local yt-dlp server + AVPlayer.
///
/// ## Overview
/// TrailerPlayerView fetches the direct video stream URL from a local Python server
/// and plays it using native AVPlayerViewController for full tvOS remote support.
///
/// ## Analytics
/// Tracks playback events (start, end, skip) for future recommendation algorithm.
///
/// ## Note
/// This is for personal use only.
struct TrailerPlayerView: View {

    // MARK: - Properties

    /// The video to play.
    let video: Video

    /// Title of the media (movie/TV show).
    let mediaTitle: String

    /// Media ID for analytics tracking.
    let mediaID: MediaID

    /// Dismiss action.
    let onDismiss: () -> Void

    /// Loading state.
    @State private var isLoading = true

    /// Error message if loading fails.
    @State private var errorMessage: String?

    /// The video URL to play.
    @State private var videoURL: URL?

    /// Playback coordinator for analytics tracking.
    @State private var playbackCoordinator: PlaybackCoordinator?

    /// Flag to prevent duplicate load attempts.
    @State private var hasStartedLoading = false

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Native Video Player Controller (full tvOS remote support)
            if let url = videoURL {
                AVPlayerViewControllerRepresentable(
                    url: url,
                    playbackCoordinator: playbackCoordinator,
                    onDismiss: {
                        // Log analytics before dismissing
                        playbackCoordinator?.logDismiss()
                        onDismiss()
                    }
                )
                .ignoresSafeArea()
            }

            // Loading overlay
            if isLoading && errorMessage == nil {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .tint(.white)
            }

            // Error overlay
            if let error = errorMessage {
                errorView(message: error)
            }
        }
        .task {
            await loadVideoStream()
        }
    }

    // MARK: - Load Video Stream

    /// Fetches the direct video URL from the local yt-dlp server and creates the player.
    private func loadVideoStream() async {
        // Prevent duplicate load attempts from SwiftUI view lifecycle
        guard !hasStartedLoading else {
            print("[TrailerPlayer] Ignoring duplicate load attempt")
            return
        }
        hasStartedLoading = true

        guard video.isYouTube else {
            errorMessage = "This video cannot be played in the app."
            isLoading = false
            return
        }

        let serverURL = Config.youtubeServerURL
        let quality = Config.youtubePreferredQuality

        print("[TrailerPlayer] Fetching stream from: \(serverURL)")

        if let streamURL = await fetchStreamURL(from: serverURL, videoKey: video.key, quality: quality) {
            await MainActor.run {
                // Create playback coordinator for analytics
                self.playbackCoordinator = PlaybackCoordinator(
                    video: video,
                    mediaTitle: mediaTitle,
                    mediaID: mediaID
                )
                self.videoURL = streamURL
                self.isLoading = false
            }
        } else {
            await MainActor.run {
                self.errorMessage = "Could not connect to video server.\n\nMake sure yt_server.py is running on your Mac and the IP address is configured correctly in Config.swift."
                self.isLoading = false
            }
        }
    }

    /// Fetches stream URL from the local yt-dlp server.
    private func fetchStreamURL(from serverURL: String, videoKey: String, quality: String) async -> URL? {
        guard let apiURL = URL(string: "\(serverURL)/stream/\(videoKey)?quality=\(quality)") else {
            print("[TrailerPlayer] Invalid server URL: \(serverURL)")
            return nil
        }

        print("[TrailerPlayer] Requesting: \(apiURL.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: apiURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[TrailerPlayer] No HTTP response from server")
                return nil
            }

            print("[TrailerPlayer] Server response status: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? String {
                    print("[TrailerPlayer] Server error: \(error)")
                }
                return nil
            }

            // Parse JSON response
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[TrailerPlayer] Failed to parse JSON response")
                return nil
            }

            // Check for error
            if let error = json["error"] as? String {
                print("[TrailerPlayer] Server returned error: \(error)")
                return nil
            }

            // Get the video URL
            guard let urlString = json["url"] as? String, let url = URL(string: urlString) else {
                print("[TrailerPlayer] No URL in server response")
                return nil
            }

            let title = json["title"] as? String ?? "Unknown"
            let videoQuality = json["quality"] as? Int ?? 0

            print("[TrailerPlayer] Got stream: \(title) @ \(videoQuality)p")
            return url

        } catch {
            print("[TrailerPlayer] Network error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Subviews

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Unable to Play Video")
                .font(.title2)
                .foregroundColor(.white)

            Text(message)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Close") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 20)
        }
    }

}

// MARK: - Playback Coordinator

/// Coordinates playback tracking for analytics.
///
/// Tracks playback start time, duration, and reports events to AnalyticsService.
@MainActor
final class PlaybackCoordinator: ObservableObject, @unchecked Sendable {

    // MARK: - Properties

    /// The video being played.
    let video: Video

    /// Media title for analytics.
    let mediaTitle: String

    /// Media ID for analytics.
    let mediaID: MediaID

    /// When playback started.
    private var playbackStartTime: Date?

    /// Total duration of the video (set when available).
    private var totalDuration: TimeInterval?

    /// Whether play_start has been logged.
    private var hasLoggedStart = false

    /// Time observer token.
    private var timeObserver: Any?

    /// Player reference for duration tracking.
    private weak var player: AVPlayer?

    // MARK: - Initialization

    init(video: Video, mediaTitle: String, mediaID: MediaID) {
        self.video = video
        self.mediaTitle = mediaTitle
        self.mediaID = mediaID
    }

    // MARK: - Playback Tracking

    /// Called when playback starts.
    func onPlaybackStart(player: AVPlayer) {
        self.player = player
        self.playbackStartTime = Date()

        // Log start event
        if !hasLoggedStart {
            hasLoggedStart = true

            // Mark as watched for grid indicator
            WatchHistoryService.shared.markAsWatched(mediaID)

            Task {
                await AnalyticsService.shared.logPlayStart(
                    video: video,
                    mediaTitle: mediaTitle,
                    mediaID: mediaID
                )
            }
        }

        // Set up time observer to get duration
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let duration = self.player?.currentItem?.duration, duration.isNumeric {
                    self.totalDuration = CMTimeGetSeconds(duration)
                }
            }
        }
    }

    /// Called when user dismisses the player.
    func logDismiss() {
        guard let startTime = playbackStartTime else { return }

        let watchDuration = Date().timeIntervalSince(startTime)
        let total = totalDuration ?? watchDuration

        // Determine if completed (watched 90%+)
        let completed = total > 0 && (watchDuration / total) >= 0.9

        Task {
            await AnalyticsService.shared.logPlayEnd(
                video: video,
                mediaTitle: mediaTitle,
                mediaID: mediaID,
                watchDuration: watchDuration,
                totalDuration: total,
                completed: completed
            )
        }

        // Clean up observer
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
}

// MARK: - AVPlayerViewController Wrapper

/// UIViewControllerRepresentable wrapper for AVPlayerViewController.
/// This provides full tvOS remote control support (play/pause, scrubbing, etc.)
struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let url: URL
    let playbackCoordinator: PlaybackCoordinator?
    nonisolated(unsafe) let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        let controller = AVPlayerViewController()
        controller.player = player

        // Create observer to wait for player to be ready before playing
        context.coordinator.observePlayer(player, playbackCoordinator: playbackCoordinator)

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.cleanup()
        uiViewController.player?.pause()
        uiViewController.player = nil
    }

    // MARK: - Coordinator for KVO

    class Coordinator: NSObject, @unchecked Sendable {
        private var statusObservation: NSKeyValueObservation?
        private weak var player: AVPlayer?
        private var playbackCoordinator: PlaybackCoordinator?
        private var hasStartedPlayback = false

        func observePlayer(_ player: AVPlayer, playbackCoordinator: PlaybackCoordinator?) {
            self.player = player
            self.playbackCoordinator = playbackCoordinator

            // Observe player item status
            statusObservation = player.currentItem?.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    switch item.status {
                    case .readyToPlay:
                        if !self.hasStartedPlayback {
                            self.hasStartedPlayback = true
                            // Now safe to play
                            player.play()
                            // Notify analytics
                            self.playbackCoordinator?.onPlaybackStart(player: player)
                            print("[TrailerPlayer] Player ready, starting playback")
                        }
                    case .failed:
                        if let error = item.error {
                            print("[TrailerPlayer] Player failed: \(error.localizedDescription)")
                        }
                    case .unknown:
                        print("[TrailerPlayer] Player status unknown, waiting...")
                    @unknown default:
                        break
                    }
                }
            }

            // Also start buffering immediately
            player.automaticallyWaitsToMinimizeStalling = true
        }

        func cleanup() {
            statusObservation?.invalidate()
            statusObservation = nil
        }
    }
}

// MARK: - Preview

#if DEBUG
struct TrailerPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        TrailerPlayerView(
            video: Video(
                id: "test",
                key: "dQw4w9WgXcQ",
                name: "Test Trailer",
                site: "YouTube",
                size: 1080,
                type: "Trailer",
                official: true,
                publishedAt: nil
            ),
            mediaTitle: "Test Movie",
            mediaID: MediaID(type: .movie, id: 12345),
            onDismiss: {}
        )
    }
}
#endif
