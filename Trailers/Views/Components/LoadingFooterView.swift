// MARK: - LoadingFooterView.swift
// Trailers - tvOS App
// Loading footer component for pagination

import SwiftUI

/// Footer view shown at the bottom of the grid during pagination.
///
/// ## Overview
/// LoadingFooterView shows:
/// - Loading indicator when fetching more content
/// - "Loading more..." text
/// - Is focusable per spec requirements
///
/// ## Usage
/// ```swift
/// LazyVGrid(...) {
///     ForEach(items) { item in
///         PosterCardView(item: item)
///     }
///
///     if isLoadingMore {
///         LoadingFooterView()
///     }
/// }
/// ```
struct LoadingFooterView: View {

    // MARK: - Properties

    /// Whether this footer is focusable.
    var isFocusable: Bool = true

    /// Focus state.
    @FocusState private var isFocused: Bool

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(0.8)

            Text(Constants.UIStrings.loadingMore)
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.Layout.footerHeight)
        .padding(.horizontal, Constants.Layout.footerPadding)
        .focusable(isFocusable)
        .focused($isFocused)
        .opacity(isFocused ? 1.0 : 0.8)
        .accessibilityLabel(Constants.Accessibility.loadingMoreContent)
    }
}

// MARK: - Empty State View

/// View shown when no content matches the current filters.
///
/// ## Overview
/// EmptyStateView displays:
/// - "No Results" title
/// - Descriptive message
/// - "Clear All Filters" button (receives focus per spec)
///
/// ## Focus Behavior
/// When empty state appears, focus MUST move to "Clear All Filters"
///
/// ## Usage
/// ```swift
/// if gridState == .empty {
///     EmptyStateView(onClearFilters: viewModel.clearAllFilters)
/// }
/// ```
struct EmptyStateView: View {

    // MARK: - Properties

    /// Action to clear filters.
    var onClearFilters: () -> Void

    /// Focus state for clear button.
    @FocusState private var clearButtonFocused: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "film.stack")
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))

            // Title
            Text(Constants.UIStrings.noResults)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)

            // Message
            Text(Constants.UIStrings.noResultsMessage)
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            // Clear filters button
            Button(action: onClearFilters) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                    Text(Constants.FilterLabels.clearAllFilters)
                }
                .font(.callout)
                .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .focused($clearButtonFocused)
            .onAppear {
                // Auto-focus clear button per spec
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    clearButtonFocused = true
                }
            }
            .accessibilityLabel(Constants.Accessibility.clearFiltersButton)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Constants.Accessibility.noResultsAnnouncement)
    }
}

// MARK: - Initial Loading View

/// Full-screen loading view for initial content load.
struct InitialLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)

            Text(Constants.UIStrings.loadingInitial)
                .font(.callout)
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(Constants.Accessibility.loadingContent)
    }
}

// MARK: - Offline Badge

/// Small badge indicating offline status.
struct OfflineBadgeView: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.slash")
                .font(.caption2)

            Text(Constants.UIStrings.offlineBadge)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Constants.Colors.offlineBadgeColor)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#if DEBUG
struct LoadingViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoadingFooterView()
                .previewDisplayName("Loading Footer")

            EmptyStateView(onClearFilters: {})
                .previewDisplayName("Empty State")

            InitialLoadingView()
                .previewDisplayName("Initial Loading")

            OfflineBadgeView()
                .previewDisplayName("Offline Badge")
        }
        .background(Constants.Colors.background)
    }
}
#endif
