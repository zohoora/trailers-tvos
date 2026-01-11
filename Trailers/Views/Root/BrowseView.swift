// MARK: - BrowseView.swift
// Trailers - tvOS App
// Main browse screen with filter bar and poster grid

import SwiftUI

/// The main browse view displaying the poster grid with filters.
///
/// ## Overview
/// BrowseView is the root screen showing:
/// - Filter bar at the top
/// - Poster grid below
/// - Loading states
/// - Empty state
/// - Error overlays
///
/// ## Navigation
/// - Single screen root (no tabs)
/// - Push navigation to detail screen
/// - Uses NavigationStack
///
/// ## Focus Behavior
/// - D-pad Up from first grid row → filter bar
/// - D-pad Down from filter bar → last focused grid item
/// - Empty state → focus moves to "Clear All Filters"
///
/// ## Usage
/// ```swift
/// BrowseView()
/// ```
struct BrowseView: View {

    // MARK: - State

    /// Filter view model.
    @StateObject private var filterViewModel = FilterViewModel()

    /// Grid view model.
    @StateObject private var gridViewModel: ContentGridViewModel

    /// Network monitor for offline badge.
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    /// Navigation path for detail screen.
    @State private var navigationPath = NavigationPath()

    /// Currently focused item ID.
    @FocusState private var focusedItemID: MediaID?

    /// Stored ID for focus restoration after navigation.
    @State private var savedFocusID: MediaID?

    /// Flag to trigger focus restoration.
    @State private var shouldRestoreFocus = false

    /// Focus namespace for controlling default focus.
    @Namespace private var gridNamespace

    // MARK: - Initialization

    init() {
        let filterVM = FilterViewModel()
        _filterViewModel = StateObject(wrappedValue: filterVM)
        _gridViewModel = StateObject(wrappedValue: ContentGridViewModel(filterViewModel: filterVM))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // Background
                Constants.Colors.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter bar
                    FilterBarView(viewModel: filterViewModel) {
                        Task {
                            await gridViewModel.refresh()
                        }
                    }

                    // Content area
                    contentView
                }
                .focusScope(gridNamespace)

                // Offline badge
                if networkMonitor.isOffline {
                    VStack {
                        HStack {
                            Spacer()
                            OfflineBadgeView()
                                .padding()
                        }
                        Spacer()
                    }
                }
            }
            .navigationDestination(for: MediaID.self) { mediaID in
                DetailView(
                    mediaID: mediaID,
                    summary: gridViewModel.items.first { $0.id == mediaID }
                )
            }
            .task {
                // Load genres
                await filterViewModel.loadGenres()

                // Load initial content
                await gridViewModel.loadInitial()
            }
            .onChange(of: focusedItemID) { _, newValue in
                if let id = newValue, let index = gridViewModel.index(of: id) {
                    gridViewModel.loadNextPageIfNeeded(focusedIndex: index)
                }
            }
            .onChange(of: navigationPath.count) { oldCount, newCount in
                if newCount > oldCount {
                    // Navigating to detail - save current focus
                    savedFocusID = focusedItemID
                } else if newCount == 0 && oldCount > 0 {
                    // Returning from detail - trigger focus restoration
                    shouldRestoreFocus = true
                }
            }
        }
    }

    // MARK: - Content Views

    /// Main content view based on grid state.
    @ViewBuilder
    private var contentView: some View {
        switch gridViewModel.state {
        case .idle, .loadingInitial:
            InitialLoadingView()

        case .loaded, .loadingNextPage, .exhausted:
            gridView

        case .empty:
            EmptyStateView(onClearFilters: filterViewModel.clearAllFilters)

        case .error(let error):
            if error == .unauthorized {
                ConfigurationErrorView()
            } else {
                ErrorOverlayView(error: error) {
                    Task {
                        await gridViewModel.loadInitial()
                    }
                }
            }
        }
    }

    /// The poster grid view.
    private var gridView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: gridColumns,
                    spacing: Constants.Layout.gridSpacing
                ) {
                    ForEach(gridViewModel.items) { item in
                        Button {
                            navigationPath.append(item.id)
                        } label: {
                            PosterCardView(item: item)
                        }
                        .buttonStyle(PosterButtonStyle())
                        .id(item.id)
                        .focused($focusedItemID, equals: item.id)
                        .prefersDefaultFocus(
                            // Prefer focus if: restoring to this item, OR this is first item and no saved focus
                            (item.id == savedFocusID && shouldRestoreFocus) ||
                            (savedFocusID == nil && item.id == gridViewModel.items.first?.id),
                            in: gridNamespace
                        )
                    }

                    // Loading footer
                    if gridViewModel.isLoadingMore {
                        LoadingFooterView()
                            .gridCellColumns(Config.gridColumns)
                    }

                    // End of content indicator
                    if gridViewModel.isExhausted && gridViewModel.itemCount > 0 {
                        endOfContentView
                            .gridCellColumns(Config.gridColumns)
                    }
                }
                .padding(.horizontal, Constants.Layout.gridHorizontalPadding)
                .padding(.vertical, Constants.Layout.gridVerticalPadding)
            }
            .onChange(of: shouldRestoreFocus) { _, shouldRestore in
                // Scroll to saved item when returning from detail
                if shouldRestore, let id = savedFocusID {
                    proxy.scrollTo(id, anchor: .center)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        focusedItemID = id
                        shouldRestoreFocus = false
                    }
                }
            }
        }
    }

    /// Grid column configuration.
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(Constants.Layout.posterWidth), spacing: Constants.Layout.gridSpacing), count: Config.gridColumns)
    }

    /// View shown at the end of content.
    private var endOfContentView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.title)
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))

            Text("You've seen it all!")
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.Layout.footerHeight)
        .focusable()
    }
}

// MARK: - Accessibility

extension BrowseView {
    /// Makes accessibility announcements for filter changes.
    private func announceFilterChange(_ change: FilterChange) {
        if let announcement = filterViewModel.accessibilityAnnouncement(for: change) {
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct BrowseView_Previews: PreviewProvider {
    static var previews: some View {
        BrowseView()
    }
}
#endif
