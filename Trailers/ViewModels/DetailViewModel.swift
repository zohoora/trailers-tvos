// MARK: - DetailViewModel.swift
// Trailers - tvOS App
// ViewModel for media detail screen

import Foundation
import Combine

// MARK: - Detail State

/// State machine for the detail screen.
///
/// ## State Transitions
/// ```
/// idle
/// → loading
/// → loaded(detail, trailers)
/// ↘ error(partialDetail?, errorKind)
/// ```
enum DetailState: Equatable {
    /// Initial state, no detail loaded.
    case idle

    /// Loading detail from API.
    case loading

    /// Detail loaded successfully.
    case loaded

    /// Error occurred during loading.
    case error(NetworkError)

    /// Returns true if currently loading.
    var isLoading: Bool {
        self == .loading
    }

    /// Returns true if detail is available.
    var hasDetail: Bool {
        self == .loaded
    }

    /// Returns true if there's an error.
    var hasError: Bool {
        if case .error = self { return true }
        return false
    }
}

// MARK: - Detail View Model

/// ViewModel for the media detail screen.
///
/// ## Overview
/// DetailViewModel manages:
/// - Fetching detailed media information
/// - Extracting certification from release dates/content ratings
/// - Managing trailer selection
/// - Launching YouTube playback
///
/// ## Usage
/// ```swift
/// @StateObject var detailVM = DetailViewModel()
///
/// // Load detail
/// await detailVM.load(mediaID)
///
/// // Play trailer
/// await detailVM.playSelectedTrailer()
///
/// // Select different trailer
/// detailVM.selectTrailer(trailer)
/// ```
@MainActor
final class DetailViewModel: ObservableObject {

    // MARK: - Published State

    /// Current detail state.
    @Published private(set) var state: DetailState = .idle

    /// Loaded media detail.
    @Published private(set) var detail: MediaDetail?

    /// Currently selected trailer.
    @Published private(set) var selectedTrailer: Video?

    /// All available trailers (ranked).
    @Published private(set) var trailers: [Video] = []

    // MARK: - Private Properties

    /// TMDB service for fetching detail.
    private let tmdbService: TMDBService

    /// Current load task (for cancellation).
    private var loadTask: Task<Void, Never>?

    /// The media ID being displayed.
    private(set) var mediaID: MediaID?

    /// Fallback summary if detail fails to load.
    private var fallbackSummary: MediaSummary?

    // MARK: - Initialization

    /// Creates a new DetailViewModel.
    ///
    /// - Parameter tmdbService: Service for API calls
    init(tmdbService: TMDBService = TMDBService()) {
        self.tmdbService = tmdbService
    }

    // MARK: - Loading

    /// Loads detail for a media item.
    ///
    /// - Parameters:
    ///   - id: The media ID to load
    ///   - fallback: Optional summary to use if detail fails
    func load(id: MediaID, fallback: MediaSummary? = nil) async {
        // Cancel any existing load
        loadTask?.cancel()

        self.mediaID = id
        self.fallbackSummary = fallback
        self.state = .loading
        self.detail = nil
        self.selectedTrailer = nil
        self.trailers = []

        Log.ui.info("Loading detail for \(id)")
        Log.beginSignpost("LoadDetail", id: id.cacheKey)

        loadTask = Task {
            do {
                let loadedDetail = try await tmdbService.fetchDetail(for: id)

                guard !Task.isCancelled else { return }

                self.detail = loadedDetail
                self.trailers = loadedDetail.rankedTrailers
                self.selectedTrailer = loadedDetail.bestTrailer
                self.state = .loaded

                Log.endSignpost("LoadDetail", id: id.cacheKey, message: "\(trailers.count) trailers")
            } catch {
                guard !Task.isCancelled else { return }

                // Try to use fallback
                if let fallback = fallbackSummary {
                    self.detail = MediaDetail.fromSummary(fallback)
                }

                if let networkError = error as? NetworkError {
                    self.state = .error(networkError)
                } else {
                    self.state = .error(.unknown(error))
                }

                Log.ui.logError("Detail load failed for \(id)", error: error)
            }
        }

        await loadTask?.value
    }

    /// Reloads the current detail.
    func reload() async {
        guard let id = mediaID else { return }
        await load(id: id, fallback: fallbackSummary)
    }

    // MARK: - Trailer Selection

    /// Selects a trailer.
    ///
    /// - Parameter video: The trailer to select
    func selectTrailer(_ video: Video) {
        guard trailers.contains(where: { $0.id == video.id }) else {
            Log.ui.warning("Attempted to select invalid trailer: \(video.id)")
            return
        }

        selectedTrailer = video
        Log.ui.info("Selected trailer: \(video.name)")
    }

    /// Plays the currently selected trailer in YouTube.
    ///
    /// - Returns: True if playback was initiated
    @discardableResult
    func playSelectedTrailer() async -> Bool {
        guard let trailer = selectedTrailer else {
            Log.ui.warning("No trailer selected for playback")
            return false
        }

        return await YouTubeLauncher.open(video: trailer)
    }

    /// Plays the currently selected trailer on TMDB's embedded player.
    ///
    /// - Returns: True if playback was initiated
    @discardableResult
    func playSelectedTrailerOnTMDB() async -> Bool {
        guard let trailer = selectedTrailer else {
            Log.ui.warning("No trailer selected for TMDB playback")
            return false
        }

        return await YouTubeLauncher.openOnTMDB(video: trailer)
    }

    /// Plays a specific trailer in YouTube.
    ///
    /// - Parameter video: The trailer to play
    /// - Returns: True if playback was initiated
    @discardableResult
    func playTrailer(_ video: Video) async -> Bool {
        selectTrailer(video)
        return await playSelectedTrailer()
    }

    // MARK: - Computed Properties

    /// Whether a trailer is available.
    var hasTrailer: Bool {
        selectedTrailer != nil
    }

    /// Number of available trailers.
    var trailerCount: Int {
        trailers.count
    }

    /// Whether there are multiple trailers to choose from.
    var hasMultipleTrailers: Bool {
        trailers.count > 1
    }

    /// The title to display.
    var title: String {
        detail?.title ?? fallbackSummary?.title ?? ""
    }

    /// The poster URL.
    var posterURL: URL? {
        detail?.posterURL ?? fallbackSummary?.posterURL
    }

    /// The backdrop URL.
    var backdropURL: URL? {
        detail?.backdropURL ?? fallbackSummary?.backdropURL
    }

    /// Error message if in error state.
    var errorMessage: String? {
        if case .error(let error) = state {
            return error.localizedDescription
        }
        return nil
    }

    /// Whether the error is retryable.
    var canRetry: Bool {
        if case .error(let error) = state {
            return error.isRetryable
        }
        return false
    }
}

// MARK: - Cleanup

extension DetailViewModel {

    /// Clears the loaded detail.
    func clear() {
        loadTask?.cancel()
        loadTask = nil
        state = .idle
        detail = nil
        selectedTrailer = nil
        trailers = []
        mediaID = nil
        fallbackSummary = nil
    }
}
