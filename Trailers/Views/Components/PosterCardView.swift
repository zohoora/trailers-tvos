// MARK: - PosterCardView.swift
// Trailers - tvOS App
// Poster card component for the grid display

import SwiftUI

/// A poster card view for displaying media items in the grid.
///
/// ## Overview
/// PosterCardView displays:
/// - Poster image (with placeholder fallback)
/// - Title (single line, truncated)
/// - Year
/// - Rating with star
/// - Media type badge (MOVIE or TV)
///
/// ## Focus Behavior
/// - Scales up to 1.08x on focus
/// - Adds subtle glow effect
/// - Respects Reduce Motion accessibility setting
///
/// ## Usage
/// ```swift
/// PosterCardView(item: mediaSummary)
///     .onTapGesture {
///         // Navigate to detail
///     }
/// ```
struct PosterCardView: View {

    // MARK: - Properties

    /// The media item to display.
    let item: MediaSummary

    /// Whether this card is currently focused (from button's focus state).
    @Environment(\.isFocused) private var isFocused

    /// Environment value for reduced motion preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Watch history service for checking viewed status.
    @ObservedObject private var watchHistory = WatchHistoryService.shared

    /// Whether this item's trailer has been watched.
    private var isWatched: Bool {
        watchHistory.hasWatched(item.id)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster Image
            posterImage
                .frame(
                    width: Constants.Layout.posterWidth,
                    height: Constants.Layout.posterHeight
                )
                .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.posterCornerRadius))
                .overlay(focusBorder)
                .overlay(watchedBadge, alignment: .topTrailing)
                .shadow(
                    color: isFocused ? Constants.Colors.focusGlow : .clear,
                    radius: isFocused ? Constants.Layout.posterShadowRadius : 0
                )

            // Info Overlay
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Constants.Colors.textPrimary)
                    .lineLimit(1)

                // Metadata row
                HStack(spacing: 8) {
                    // Year
                    Text(item.yearText)
                        .font(.caption2)
                        .foregroundColor(Constants.Colors.textSecondary)

                    // Rating
                    HStack(spacing: 2) {
                        Text("★")
                            .foregroundColor(Constants.Colors.ratingStarColor)
                        Text(item.ratingDisplay)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .font(.caption2)

                    Spacer()

                    // Type badge
                    Text(item.typeBadge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor)
                        .clipShape(Capsule())
                }
            }
            .frame(width: Constants.Layout.posterWidth)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Subviews

    /// The poster image with fallback placeholder.
    @ViewBuilder
    private var posterImage: some View {
        if let posterURL = item.posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .empty:
                    ImagePlaceholder.poster(title: item.title)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    ImagePlaceholder.poster(title: item.title)
                @unknown default:
                    ImagePlaceholder.poster(title: item.title)
                }
            }
        } else {
            ImagePlaceholder.poster(title: item.title)
        }
    }

    /// Border overlay for focus state (used with reduce motion).
    @ViewBuilder
    private var focusBorder: some View {
        if reduceMotion && isFocused {
            RoundedRectangle(cornerRadius: Constants.Layout.posterCornerRadius)
                .strokeBorder(Constants.Colors.accent, lineWidth: 4)
        }
    }

    /// Watched indicator badge overlay.
    @ViewBuilder
    private var watchedBadge: some View {
        if isWatched {
            Image(systemName: "eye.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(6)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                )
                .padding(8)
        }
    }

    // MARK: - Computed Properties

    /// Badge color based on media type.
    private var badgeColor: Color {
        item.mediaType == .movie ?
            Constants.Colors.movieBadgeColor :
            Constants.Colors.tvBadgeColor
    }
}

// MARK: - PosterButtonStyle

/// Button style for poster cards in tvOS.
///
/// This style removes the default button appearance and lets the
/// PosterCardView handle its own focus visual feedback.
struct PosterButtonStyle: ButtonStyle {

    /// Whether the button is currently focused.
    @Environment(\.isFocused) private var isFocused

    /// Environment value for reduced motion preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scaleValue(configuration: configuration))
            .animation(reduceMotion ? nil : Constants.Animation.focusAnimation, value: isFocused)
    }

    private func scaleValue(configuration: Configuration) -> CGFloat {
        if reduceMotion {
            return 1.0
        }
        if configuration.isPressed {
            return 0.95
        }
        return isFocused ? Constants.Layout.posterFocusScale : 1.0
    }
}

// MARK: - Preview

#if DEBUG
struct PosterCardView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 40) {
            PosterCardView(item: .preview)
            PosterCardView(item: .previewTV)
        }
        .padding(100)
        .background(Constants.Colors.background)
    }
}

// Preview helpers
extension MediaSummary {
    static var preview: MediaSummary {
        MediaSummary(
            id: MediaID(type: .movie, id: 1),
            title: "Inception",
            posterPath: nil,
            backdropPath: nil,
            overview: "A thief who steals corporate secrets...",
            releaseDate: DateUtils.parseDate("2010-07-16"),
            voteAverage: 8.8,
            voteCount: 30000,
            genreIDs: [28, 878],
            popularity: 100.0
        )
    }

    static var previewTV: MediaSummary {
        MediaSummary(
            id: MediaID(type: .tv, id: 2),
            title: "Breaking Bad",
            posterPath: nil,
            backdropPath: nil,
            overview: "A high school chemistry teacher...",
            releaseDate: DateUtils.parseDate("2008-01-20"),
            voteAverage: 9.5,
            voteCount: 10000,
            genreIDs: [18, 80],
            popularity: 200.0
        )
    }
}
#endif
