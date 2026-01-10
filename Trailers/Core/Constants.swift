// MARK: - Constants.swift
// Trailers - tvOS App
// App-wide constants and string literals

import SwiftUI

/// App-wide constants organized by category.
///
/// ## Overview
/// This enum provides centralized access to all constant values used throughout the app,
/// including UI strings, accessibility labels, and TMDB attribution requirements.
///
/// ## Design Philosophy
/// - All user-facing strings are defined here for easy localization
/// - Constants are grouped by feature/screen for maintainability
/// - Static typing prevents typos in string literals
enum Constants {

    // MARK: - App Info

    /// Application metadata.
    enum App {
        static let name = "Trailers"
        static let bundleIdentifier = "com.personal.trailers"
    }

    // MARK: - TMDB Attribution

    /// TMDB attribution strings (required by their terms of service).
    enum TMDB {
        /// Attribution text to display in the app.
        static let attribution = "Powered by TMDB"

        /// TMDB website URL for attribution link.
        static let websiteURL = URL(string: "https://www.themoviedb.org")!

        /// Logo asset name in the asset catalog.
        static let logoAssetName = "tmdb-logo"
    }

    // MARK: - YouTube

    /// YouTube-related constants.
    enum YouTube {
        /// Base URL for YouTube video playback via Universal Links.
        static let watchBaseURL = URL(string: "https://www.youtube.com/watch")!

        /// Constructs a YouTube watch URL for a given video key.
        ///
        /// - Parameter videoKey: The YouTube video ID
        /// - Returns: Full YouTube watch URL
        static func watchURL(videoKey: String) -> URL {
            var components = URLComponents(url: watchBaseURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "v", value: videoKey)]
            return components.url!
        }
    }

    // MARK: - Filter Labels

    /// Labels for filter controls.
    enum FilterLabels {
        // Content Type
        static let contentTypeAll = "All"
        static let contentTypeMovies = "Movies"
        static let contentTypeTVShows = "TV Shows"

        // Sort Options
        static let sortTrending = "Trending"
        static let sortPopularity = "Popularity"
        static let sortReleaseDateNewest = "Release Date (Newest)"
        static let sortReleaseDateOldest = "Release Date (Oldest)"
        static let sortRatingHighest = "Rating (Highest)"
        static let sortRatingLowest = "Rating (Lowest)"

        // Date Ranges
        static let dateRangeUpcoming = "Upcoming"
        static let dateRangeThisMonth = "This Month"
        static let dateRangeLast30Days = "Last 30 Days"
        static let dateRangeLast90Days = "Last 90 Days"
        static let dateRangeThisYear = "This Year"
        static let dateRangeAllTime = "All Time"

        // Genre
        static let genreAll = "All Genres"

        // Certification
        static let certificationAll = "All Certifications"
        static let certificationNotRated = "NR"

        // Buttons
        static let refreshButton = "Refresh"
        static let clearAllFilters = "Clear All Filters"
    }

    // MARK: - UI Strings

    /// User-facing strings for various UI elements.
    enum UIStrings {
        // Grid
        static let loadingInitial = "Loading..."
        static let loadingMore = "Loading more..."
        static let noResults = "No Results"
        static let noResultsMessage = "Try adjusting your filters to find more content."

        // Detail Screen
        static let playInYouTube = "Play in YouTube"
        static let noTrailerAvailable = "No Trailer Available"
        static let selectTrailer = "Select Trailer"
        static let closeButton = "Close"
        static let openTMDB = "Open TMDB"

        // Metadata
        static let yearTBA = "TBA"
        static let ratingNotAvailable = "-"
        static let runtimeFormat = "%dh %dm"
        static let episodeRuntimeFormat = "%d min/episode"
        static let votesFormat = "(%@ votes)"

        // Media Type
        static let movieBadge = "MOVIE"
        static let tvBadge = "TV"

        // Error States
        static let errorTitle = "Something went wrong"
        static let errorRetry = "Retry"
        static let offlineBadge = "Offline"
        static let offlineMessage = "Showing cached results"
        static let configurationError = "Configuration Error"
        static let configurationErrorMessage = "Please check your API token configuration."

        // Rate Limiting
        static let rateLimitTitle = "Too Many Requests"
        static let rateLimitMessage = "Retrying in %d seconds..."
    }

    // MARK: - Accessibility

    /// Accessibility labels and hints.
    enum Accessibility {
        // Poster Card
        static let posterCardFormat = "%@, %@, rated %@ out of 10, %@"
        static let movieType = "Movie"
        static let tvShowType = "TV Show"

        // Filter Bar
        static let filterBar = "Filter options"
        static let contentTypeFilter = "Content type filter"
        static let sortFilter = "Sort by"
        static let genreFilter = "Genre filter"
        static let dateRangeFilter = "Date range filter"
        static let certificationFilter = "Certification filter"
        static let refreshButton = "Refresh content"
        static let clearFiltersButton = "Clear all filters"

        // Announcements
        static let filterChangedFormat = "Filter changed to %@"
        static let sortChangedFormat = "Sort changed to %@"
        static let sortAutoSwitchedFormat = "Sort automatically changed to %@ due to filter selection"
        static let resultsLoadedFormat = "%d items loaded"
        static let noResultsAnnouncement = "No results found, focus moved to clear filters button"

        // Detail Screen
        static let detailScreen = "Detail view"
        static let overviewScrollable = "Overview, scrollable"
        static let trailerSelector = "Trailer selector, %d trailers available"
        static let playButton = "Play trailer in YouTube app"
        static let closeDetailButton = "Close detail view"

        // Loading States
        static let loadingContent = "Loading content"
        static let loadingMoreContent = "Loading more content"
    }

    // MARK: - Video Types

    /// Video type strings from TMDB.
    enum VideoTypes {
        static let trailer = "Trailer"
        static let teaser = "Teaser"
        static let clip = "Clip"
        static let featurette = "Featurette"
        static let behindTheScenes = "Behind the Scenes"

        /// Priority order for trailer ranking (lower index = higher priority).
        static let priorityOrder = [trailer, teaser, clip, featurette, behindTheScenes]
    }

    // MARK: - Layout Constants

    /// Layout dimensions and spacing.
    enum Layout {
        // Grid
        static let gridSpacing: CGFloat = 40
        static let gridHorizontalPadding: CGFloat = 80
        static let gridVerticalPadding: CGFloat = 60

        // Poster Card
        static let posterWidth: CGFloat = 220
        static let posterHeight: CGFloat = 330
        static let posterCornerRadius: CGFloat = 12
        static let posterFocusScale: CGFloat = 1.08
        static let posterShadowRadius: CGFloat = 20
        static let posterShadowOpacity: Float = 0.3

        // Filter Bar
        static let filterBarHeight: CGFloat = 80
        static let filterBarPadding: CGFloat = 40
        static let filterPillSpacing: CGFloat = 20

        // Detail Screen
        static let detailPosterWidth: CGFloat = 300
        static let detailPosterHeight: CGFloat = 450
        static let detailContentSpacing: CGFloat = 40
        static let detailGradientHeight: CGFloat = 400

        // Footer
        static let footerHeight: CGFloat = 100
        static let footerPadding: CGFloat = 20
    }

    // MARK: - Colors

    /// App color constants.
    enum Colors {
        static let background = Color(hex: 0x1A1A1A)
        static let cardBackground = Color(hex: 0x2A2A2A)
        static let accent = Color.blue
        static let focusGlow = Color.white.opacity(0.3)
        static let textPrimary = Color.white
        static let textSecondary = Color.gray
        static let ratingStarColor = Color.yellow
        static let movieBadgeColor = Color.blue
        static let tvBadgeColor = Color.purple
        static let offlineBadgeColor = Color.orange
        static let errorColor = Color.red
    }

    // MARK: - Animation

    /// Animation timing constants.
    enum Animation {
        static let focusAnimation: SwiftUI.Animation = .easeInOut(duration: 0.2)
        static let loadingAnimation: SwiftUI.Animation = .easeInOut(duration: 0.3)
        static let filterChangeAnimation: SwiftUI.Animation = .easeInOut(duration: 0.25)
    }
}

// MARK: - Color Extension

extension Color {
    /// Initialize a Color from a hex value.
    ///
    /// - Parameter hex: Hex color value (e.g., 0x1A1A1A)
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
