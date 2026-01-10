// MARK: - FilterBarView.swift
// Trailers - tvOS App
// Filter bar component with all filter controls

import SwiftUI

/// Filter bar view displaying all filter controls.
///
/// ## Overview
/// FilterBarView provides:
/// - Content type picker (All, Movies, TV Shows)
/// - Sort picker
/// - Genre picker
/// - Date range picker
/// - Certification picker (movies only)
/// - Refresh button
///
/// ## Focus Behavior
/// - D-pad Up from first grid row moves focus here
/// - D-pad Down returns to last focused grid item
/// - When empty state, focus moves to "Clear All Filters"
///
/// ## Usage
/// ```swift
/// FilterBarView(viewModel: filterViewModel)
/// ```
struct FilterBarView: View {

    // MARK: - Properties

    /// Filter view model.
    @ObservedObject var viewModel: FilterViewModel

    /// Action to perform on refresh.
    var onRefresh: () -> Void

    /// Namespace for matched geometry.
    @Namespace private var filterNamespace

    // MARK: - Body

    var body: some View {
        HStack(spacing: Constants.Layout.filterPillSpacing) {
            // Content Type
            FilterPicker(
                title: "Type",
                selection: Binding(
                    get: { viewModel.filterState.contentType },
                    set: { viewModel.setContentType($0) }
                ),
                options: ContentType.allCases
            ) { option in
                Text(option.displayName)
            }

            // Sort
            FilterPicker(
                title: "Sort",
                selection: Binding(
                    get: { viewModel.filterState.sort },
                    set: { viewModel.setSort($0) }
                ),
                options: SortOption.allCases
            ) { option in
                Text(option.displayName)
            }

            // Genre
            FilterPicker(
                title: "Genre",
                selection: Binding(
                    get: { viewModel.filterState.genre },
                    set: { viewModel.setGenre($0) }
                ),
                options: [nil] + viewModel.displayGenres.map { Optional($0) }
            ) { option in
                Text(option?.name ?? Constants.FilterLabels.genreAll)
            }

            // Date Range
            FilterPicker(
                title: "Date",
                selection: Binding(
                    get: { viewModel.filterState.dateRange },
                    set: { viewModel.setDateRange($0) }
                ),
                options: DateRange.allCases
            ) { option in
                Text(option.displayName)
            }

            // Certification (movies only)
            if viewModel.showCertification {
                FilterPicker(
                    title: "Rating",
                    selection: Binding(
                        get: { viewModel.filterState.certification },
                        set: { viewModel.setCertification($0) }
                    ),
                    options: [nil] + viewModel.certificationOptions.map { Optional($0) }
                ) { option in
                    Text(option ?? Constants.FilterLabels.certificationAll)
                }
            }

            Spacer()

            // Active filter count badge
            if viewModel.hasActiveFilters {
                filterCountBadge
            }

            // Clear filters button
            if viewModel.hasActiveFilters {
                Button(action: viewModel.clearAllFilters) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                        Text(Constants.FilterLabels.clearAllFilters)
                    }
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Constants.Accessibility.clearFiltersButton)
            }

            // Refresh button
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Constants.Accessibility.refreshButton)
        }
        .padding(.horizontal, Constants.Layout.filterBarPadding)
        .frame(height: Constants.Layout.filterBarHeight)
        .background(Constants.Colors.background.opacity(0.95))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Constants.Accessibility.filterBar)
    }

    // MARK: - Subviews

    /// Badge showing number of active filters.
    private var filterCountBadge: some View {
        Text("\(viewModel.activeFilterCount)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(Constants.Colors.accent)
            .clipShape(Circle())
    }
}

// MARK: - Filter Picker

/// Generic picker for filter options.
struct FilterPicker<T: Hashable, Label: View>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let label: (T) -> Label

    @FocusState private var isFocused: Bool

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    label(option)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(Constants.Colors.textSecondary)

                label(selection)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Constants.Colors.textPrimary)

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Constants.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isFocused ? Constants.Colors.accent : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
        .focusable()
        .focused($isFocused)
    }
}

// MARK: - Filter Summary View

/// Compact view showing current filter summary.
struct FilterSummaryView: View {
    @ObservedObject var viewModel: FilterViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundColor(Constants.Colors.textSecondary)

            Text(viewModel.filterSummary)
                .font(.caption)
                .foregroundColor(Constants.Colors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Constants.Colors.cardBackground)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#if DEBUG
struct FilterBarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            FilterBarView(viewModel: FilterViewModel()) {
                print("Refresh")
            }

            Spacer()
        }
        .background(Constants.Colors.background)
    }
}
#endif
