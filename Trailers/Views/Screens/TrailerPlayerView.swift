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
/// ## Note
/// This is for personal use only.
struct TrailerPlayerView: View {

    // MARK: - Properties

    /// The video to play.
    let video: Video

    /// Dismiss action.
    let onDismiss: () -> Void

    /// Loading state.
    @State private var isLoading = true

    /// Error message if loading fails.
    @State private var errorMessage: String?

    /// The video URL to play.
    @State private var videoURL: URL?

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Native Video Player Controller (full tvOS remote support)
            if let url = videoURL {
                AVPlayerViewControllerRepresentable(url: url, onDismiss: onDismiss)
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

// MARK: - AVPlayerViewController Wrapper

/// UIViewControllerRepresentable wrapper for AVPlayerViewController.
/// This provides full tvOS remote control support (play/pause, scrubbing, etc.)
struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let url: URL
    nonisolated(unsafe) let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player

        // Start playing automatically
        player.play()

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }

    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator: ()) {
        uiViewController.player?.pause()
        uiViewController.player = nil
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
            onDismiss: {}
        )
    }
}
#endif
