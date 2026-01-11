// MARK: - ContentGridViewModel.swift
// Trailers - tvOS App
// ViewModel for the main content grid with pagination and state management

import Foundation
import Combine

// MARK: - Grid State

/// State machine for the content grid.
///
/// ## State Transitions
/// ```
/// idle
/// → loadingInitial
/// → loaded(items)
/// → loadingNextPage(items)
/// → loaded(items)
/// → exhausted(items)    (no more pages)
/// ↘ error(lastGoodItems?, errorKind)
/// ↘ empty(filtersApplied)
/// ```
enum GridState: Equatable {
    /// Initial state, no content loaded.
    case idle

    /// Loading first page of content.
    case loadingInitial

    /// Content loaded successfully.
    case loaded

    /// Loading additional page while showing existing content.
    case loadingNextPage

    /// All pages loaded, no more content available.
    case exhausted

    /// No results found for current filters.
    case empty

    /// Error occurred during loading.
    case error(NetworkError)

    /// Returns true if currently loading.
    var isLoading: Bool {
        switch self {
        case .loadingInitial, .loadingNextPage:
            return true
        default:
            return false
        }
    }

    /// Returns true if content is available.
    var hasContent: Bool {
        switch self {
        case .loaded, .loadingNextPage, .exhausted:
            return true
        default:
            return false
        }
    }

    /// Returns true if more content can be loaded.
    var canLoadMore: Bool {
        switch self {
        case .loaded:
            return true
        default:
            return false
        }
    }
}

// MARK: - Content Grid View Model

/// ViewModel for the main content grid.
///
/// ## Overview
/// ContentGridViewModel manages:
/// - Content loading and pagination
/// - Filter state coordination
/// - "All" mode merge algorithm
/// - Focus tracking
/// - Request cancellation
///
/// ## Pagination Strategy
/// - Initial load fetches page 1, then prefetches page 2
/// - Next page triggered when focus is within 3 rows of end
/// - Debounced by 300ms to prevent rapid triggers
/// - Idempotent: repeated triggers are ignored
///
/// ## "All" Mode Merging
/// When content type is "All", movies and TV shows are fetched
/// separately and merged using the selected sort comparator.
///
/// ## Usage
/// ```swift
/// @StateObject var gridVM = ContentGridViewModel()
///
/// // Initial load
/// await gridVM.loadInitial()
///
/// // Pagination
/// gridVM.loadNextPageIfNeeded(focusedIndex: 40)
///
/// // Filter changes
/// gridVM.applyFilters(newFilterState)
/// ```
@MainActor
final class ContentGridViewModel: ObservableObject {

    // MARK: - Published State

    /// Current grid state.
    @Published private(set) var state: GridState = .idle

    /// Loaded media items.
    @Published private(set) var items: [MediaSummary] = []

    /// ID of the last focused item (for focus restoration).
    @Published var lastFocusedID: MediaID?

    /// Whether a refresh is in progress.
    @Published private(set) var isRefreshing = false

    /// Current filter state being applied.
    @Published private(set) var currentFilters = FilterState()

    // MARK: - Private Properties

    /// TMDB service for fetching content.
    private let tmdbService: TMDBService

    /// Network monitor for offline detection.
    private let networkMonitor: NetworkMonitor

    /// Current active load task (for cancellation).
    private var activeTask: Task<Void, Never>?

    /// Current page number for movies.
    private var moviePage = 0

    /// Current page number for TV.
    private var tvPage = 0

    /// Whether movie results are exhausted.
    private var movieExhausted = false

    /// Whether TV results are exhausted.
    private var tvExhausted = false

    /// Debounce task for pagination.
    private var paginationDebounceTask: Task<Void, Never>?

    /// Seen media IDs for deduplication.
    private var seenIDs = Set<MediaID>()

    /// Cancellables for Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates a new ContentGridViewModel.
    ///
    /// - Parameters:
    ///   - tmdbService: Service for API calls
    ///   - filterViewModel: Filter view model to observe
    init(
        tmdbService: TMDBService = TMDBService(),
        filterViewModel: FilterViewModel? = nil
    ) {
        self.tmdbService = tmdbService
        self.networkMonitor = NetworkMonitor.shared

        // Observe filter changes
        if let filterVM = filterViewModel {
            filterVM.filterChanged
                .receive(on: DispatchQueue.main)
                .sink { [weak self] change in
                    self?.applyFilters(change.newState)
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Loading

    /// Loads initial content for the current filter state.
    ///
    /// Cancels any existing load task and resets pagination.
    func loadInitial() async {
        // Cancel any existing task
        activeTask?.cancel()
        activeTask = nil

        // Reset pagination state
        resetPagination()
        state = .loadingInitial

        // Capture current filters to detect if they change during load
        let filtersAtStart = currentFilters

        Log.pagination.info("Loading initial content")
        Log.beginSignpost("LoadInitial", id: "initial")

        activeTask = Task {
            do {
                // Load first page
                let result = try await loadPage(1)

                guard !Task.isCancelled else { return }

                // Check if filters changed during load (race condition protection)
                guard currentFilters == filtersAtStart else { return }

                if result.isEmpty {
                    state = .empty
                } else {
                    items = result
                    updatePaginationState(movieHasMore: !movieExhausted, tvHasMore: !tvExhausted)

                    // Prefetch page 2
                    if state == .loaded {
                        await prefetchNextPage()
                    }
                }

                Log.endSignpost("LoadInitial", id: "initial", message: "\(items.count) items")
            } catch {
                guard !Task.isCancelled else { return }

                if let networkError = error as? NetworkError {
                    state = .error(networkError)
                } else {
                    state = .error(.unknown(error))
                }

                Log.pagination.logError("Initial load failed", error: error)
            }
        }

        await activeTask?.value
    }

    /// Loads the next page if conditions are met.
    ///
    /// Conditions:
    /// - Not already loading
    /// - Not exhausted
    /// - Focus is within threshold rows of end
    ///
    /// - Parameter focusedIndex: Index of the currently focused item
    func loadNextPageIfNeeded(focusedIndex: Int) {
        // Check if we should load
        guard state.canLoadMore else { return }

        // Calculate rows remaining
        let rowSize = Config.gridColumns
        let currentRow = focusedIndex / rowSize
        let totalRows = (items.count + rowSize - 1) / rowSize
        let rowsRemaining = totalRows - currentRow - 1

        guard rowsRemaining <= Config.prefetchRowThreshold else { return }

        // Debounce
        paginationDebounceTask?.cancel()
        paginationDebounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(Config.paginationDebounce * 1_000_000_000))

            guard !Task.isCancelled else { return }
            await loadNextPage()
        }
    }

    /// Loads the next page of content.
    private func loadNextPage() async {
        guard state.canLoadMore else { return }

        state = .loadingNextPage
        Log.pagination.logPagination(page: max(moviePage, tvPage) + 1, totalItems: items.count)

        do {
            let nextPage = max(moviePage, tvPage) + 1
            let newItems = try await loadPage(nextPage)

            guard !Task.isCancelled else { return }

            if !newItems.isEmpty {
                items.append(contentsOf: newItems)
            }

            updatePaginationState(movieHasMore: !movieExhausted, tvHasMore: !tvExhausted)
        } catch {
            // Don't show error for pagination failures, just stop loading
            state = items.isEmpty ? .error(error as? NetworkError ?? .unknown(error)) : .loaded
            Log.pagination.logError("Next page load failed", error: error)
        }
    }

    /// Prefetches the next page without changing state.
    private func prefetchNextPage() async {
        guard state == .loaded else { return }

        do {
            let nextPage = max(moviePage, tvPage) + 1
            let newItems = try await loadPage(nextPage)

            guard !Task.isCancelled else { return }

            if !newItems.isEmpty {
                items.append(contentsOf: newItems)
            }

            updatePaginationState(movieHasMore: !movieExhausted, tvHasMore: !tvExhausted)
        } catch {
            // Silently fail prefetch
            Log.pagination.debug("Prefetch failed: \(error.localizedDescription)")
        }
    }

    /// Loads a specific page of content.
    ///
    /// - Parameter page: Page number to load
    /// - Returns: Array of new items (deduplicated)
    private func loadPage(_ page: Int) async throws -> [MediaSummary] {
        let result: (items: [MediaSummary], hasMore: Bool, movieHasMore: Bool, tvHasMore: Bool)

        if currentFilters.canUseTrendingEndpoint {
            // Use trending endpoint
            let trending = try await tmdbService.fetchTrending(
                mediaType: currentFilters.contentType.singleType,
                page: page
            )
            result = (trending.items, trending.hasMore, trending.hasMore, trending.hasMore)
        } else {
            // Use discover endpoint
            result = try await tmdbService.fetchDiscover(
                filterState: currentFilters,
                page: page
            )
        }

        // Update pagination tracking
        if currentFilters.contentType == .all || currentFilters.contentType == .movies {
            moviePage = page
            movieExhausted = !result.movieHasMore
        }
        if currentFilters.contentType == .all || currentFilters.contentType == .tvShows {
            tvPage = page
            tvExhausted = !result.tvHasMore
        }

        // Check for cancellation before deduplication to avoid race conditions
        guard !Task.isCancelled else { return [] }

        // Deduplicate
        let newItems = result.items.filter { item in
            if seenIDs.contains(item.id) {
                return false
            }
            seenIDs.insert(item.id)
            return true
        }

        return newItems
    }

    /// Updates state based on pagination progress.
    private func updatePaginationState(movieHasMore: Bool, tvHasMore: Bool) {
        let hasMore: Bool
        switch currentFilters.contentType {
        case .all:
            hasMore = movieHasMore || tvHasMore
        case .movies:
            hasMore = movieHasMore
        case .tvShows:
            hasMore = tvHasMore
        }

        state = hasMore ? .loaded : .exhausted
    }

    // MARK: - Refresh

    /// Forces a refresh, bypassing cache.
    func refresh() async {
        isRefreshing = true

        // Cancel any existing task
        activeTask?.cancel()
        activeTask = nil

        // Reset and reload
        resetPagination()
        state = .loadingInitial

        activeTask = Task {
            do {
                let result = try await loadPage(1)

                guard !Task.isCancelled else { return }

                if result.isEmpty {
                    state = .empty
                } else {
                    items = result
                    updatePaginationState(movieHasMore: !movieExhausted, tvHasMore: !tvExhausted)
                }
            } catch {
                guard !Task.isCancelled else { return }

                if let networkError = error as? NetworkError {
                    state = .error(networkError)
                } else {
                    state = .error(.unknown(error))
                }
            }

            isRefreshing = false
        }

        await activeTask?.value
    }

    // MARK: - Filter Changes

    /// Applies new filter state.
    ///
    /// Cancels existing requests, resets pagination, and reloads.
    ///
    /// - Parameter filterState: New filter state to apply
    func applyFilters(_ filterState: FilterState) {
        guard filterState != currentFilters else { return }

        currentFilters = filterState

        // Cancel and reload
        Task {
            await loadInitial()
        }
    }

    // MARK: - Private Helpers

    /// Resets pagination state for new query.
    private func resetPagination() {
        items = []
        moviePage = 0
        tvPage = 0
        movieExhausted = false
        tvExhausted = false
        seenIDs.removeAll()
    }

    // MARK: - Computed Properties

    /// Whether the grid is in an empty state.
    var isEmpty: Bool {
        state == .empty
    }

    /// Whether there was an error.
    var hasError: Bool {
        if case .error = state { return true }
        return false
    }

    /// The current error, if any.
    var error: NetworkError? {
        if case .error(let error) = state { return error }
        return nil
    }

    /// Whether initial loading is in progress.
    var isLoadingInitial: Bool {
        state == .loadingInitial
    }

    /// Whether pagination loading is in progress.
    var isLoadingMore: Bool {
        state == .loadingNextPage
    }

    /// Whether all content has been loaded.
    var isExhausted: Bool {
        state == .exhausted
    }

    /// Total number of items loaded.
    var itemCount: Int {
        items.count
    }
}

// MARK: - Focus Management

extension ContentGridViewModel {

    /// Updates the last focused ID.
    ///
    /// - Parameter id: The ID of the focused item
    func setFocused(_ id: MediaID?) {
        lastFocusedID = id
    }

    /// Finds the index of an item by ID.
    ///
    /// - Parameter id: The ID to find
    /// - Returns: Index, or nil if not found
    func index(of id: MediaID) -> Int? {
        items.firstIndex { $0.id == id }
    }
}
