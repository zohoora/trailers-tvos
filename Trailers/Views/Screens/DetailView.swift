// MARK: - DetailView.swift
// Trailers - tvOS App
// Detail screen for media items

import SwiftUI

/// Detail screen showing full media information and trailer options.
///
/// ## Overview
/// DetailView displays:
/// - Backdrop image with gradient overlay
/// - Poster image (left side)
/// - Title, tagline, metadata (right side)
/// - Score and certification
/// - Overview (scrollable)
/// - Play trailer button
/// - TMDB attribution
///
/// ## Navigation
/// - Back button dismisses to grid
/// - Play button opens YouTube
///
/// ## Usage
/// ```swift
/// DetailView(mediaID: mediaID, summary: summaryFromGrid)
/// ```
struct DetailView: View {

    // MARK: - Properties

    /// The media ID to display.
    let mediaID: MediaID

    /// Optional summary from grid (for fallback).
    let summary: MediaSummary?

    /// Detail view model.
    @StateObject private var viewModel = DetailViewModel()

    /// Environment dismiss action.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        ZStack {
            // Backdrop
            backdropView

            // Content
            HStack(alignment: .top, spacing: Constants.Layout.detailContentSpacing) {
                // Poster
                posterView

                // Info
                infoView
            }
            .padding(60)

            // Close button
            closeButton

            // TMDB attribution
            tmdbAttribution

            // Loading overlay
            if viewModel.state.isLoading {
                LoadingOverlay()
            }

            // Error overlay
            if case .error(let error) = viewModel.state {
                ErrorOverlayView(error: error) {
                    Task {
                        await viewModel.reload()
                    }
                }
            }
        }
        .ignoresSafeArea()
        .task {
            await viewModel.load(id: mediaID, fallback: summary)
        }
    }

    // MARK: - Backdrop

    /// Full-screen backdrop with gradient.
    private var backdropView: some View {
        ZStack {
            // Background color
            Constants.Colors.background

            // Backdrop image
            if let url = viewModel.backdropURL {
                AsyncBackdropImage(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }

            // Gradient overlay
            LinearGradient(
                colors: [
                    Constants.Colors.background.opacity(0.3),
                    Constants.Colors.background.opacity(0.8),
                    Constants.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Poster

    /// Poster image view.
    private var posterView: some View {
        Group {
            if let url = viewModel.posterURL {
                AsyncPosterImage(url: url)
            } else {
                ImagePlaceholder.poster(title: viewModel.title)
            }
        }
        .frame(
            width: Constants.Layout.detailPosterWidth,
            height: Constants.Layout.detailPosterHeight
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.posterCornerRadius))
        .shadow(radius: 20)
    }

    // MARK: - Info

    /// Right-side info view.
    private var infoView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text(viewModel.detail?.title ?? summary?.title ?? "")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Constants.Colors.textPrimary)

            // Tagline
            if let tagline = viewModel.detail?.tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.title3)
                    .italic()
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            // Metadata row
            metadataRow

            // Score and certification
            scoreRow

            // Genres
            if let genres = viewModel.detail?.genresFormatted, !genres.isEmpty {
                Text(genres)
                    .font(.body)
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            // Overview
            if let overview = viewModel.detail?.overview, !overview.isEmpty {
                ScrollView {
                    Text(overview)
                        .font(.body)
                        .foregroundColor(Constants.Colors.textPrimary)
                        .lineLimit(nil)
                }
                .frame(maxHeight: 200)
                .focusable()
                .accessibilityLabel(Constants.Accessibility.overviewScrollable)
            }

            Spacer()

            // Trailer info
            if let trailerInfo = viewModel.detail?.trailerDisplayInfo {
                Text(trailerInfo)
                    .font(.caption)
                    .foregroundColor(Constants.Colors.textSecondary)
            }

            // Action buttons
            actionButtons
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Metadata Row

    /// Release date and runtime.
    private var metadataRow: some View {
        HStack(spacing: 16) {
            // Release date
            if let date = viewModel.detail?.releaseDateFormatted {
                Label(date, systemImage: "calendar")
            }

            // Runtime
            if let runtime = viewModel.detail?.runtimeFormatted {
                Label(runtime, systemImage: "clock")
            }
        }
        .font(.callout)
        .foregroundColor(Constants.Colors.textSecondary)
    }

    // MARK: - Score Row

    /// Rating and certification.
    private var scoreRow: some View {
        HStack(spacing: 20) {
            // Rating
            if let rating = viewModel.detail?.ratingFormatted {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Constants.Colors.ratingStarColor)
                    Text(rating)
                        .fontWeight(.semibold)
                }
            }

            // Certification
            if let cert = viewModel.detail?.certification {
                Text(cert)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Constants.Colors.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Constants.Colors.textSecondary, lineWidth: 1)
                    )
            }
        }
        .font(.title3)
        .foregroundColor(Constants.Colors.textPrimary)
    }

    // MARK: - Action Buttons

    /// Play and trailer selector buttons.
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Play button
            Button {
                Task {
                    await viewModel.playSelectedTrailer()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(viewModel.hasTrailer ? Constants.UIStrings.playInYouTube : Constants.UIStrings.noTrailerAvailable)
                }
                .font(.callout)
                .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasTrailer)
            .accessibilityLabel(Constants.Accessibility.playButton)

            // Trailer selector (if multiple)
            if viewModel.hasMultipleTrailers {
                NavigationLink(destination: TrailerSelectorView(viewModel: viewModel)) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet")
                        Text(Constants.UIStrings.selectTrailer)
                    }
                    .font(.callout)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(String(format: Constants.Accessibility.trailerSelector, viewModel.trailerCount))
            }
        }
    }

    // MARK: - Close Button

    /// Close button in corner.
    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Constants.Accessibility.closeDetailButton)
            }
            Spacer()
        }
        .padding(40)
    }

    // MARK: - TMDB Attribution

    /// TMDB logo and attribution.
    private var tmdbAttribution: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    // Open TMDB would go here
                } label: {
                    Text(Constants.TMDB.attribution)
                        .font(.caption2)
                        .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(Constants.UIStrings.openTMDB) {
                        // Open TMDB website
                    }
                }
            }
        }
        .padding(30)
    }
}

// MARK: - Loading Overlay

/// Semi-transparent loading overlay.
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)

            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#if DEBUG
struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        DetailView(
            mediaID: MediaID(type: .movie, id: 27205),
            summary: nil
        )
    }
}
#endif
