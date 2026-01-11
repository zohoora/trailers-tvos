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

    /// Whether the trailer player is showing.
    @State private var showingTrailerPlayer = false

    /// Focus namespace for default focus on play button.
    @Namespace private var detailNamespace

    /// Focus state for explicit button focus control.
    @FocusState private var isPlayButtonFocused: Bool

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
        .focusScope(detailNamespace)
        .ignoresSafeArea()
        .task {
            await viewModel.load(id: mediaID, fallback: summary)
            await viewModel.checkWatchlistStatus()
            await viewModel.fetchWatchProviders()
            isPlayButtonFocused = true
        }
        .fullScreenCover(isPresented: $showingTrailerPlayer) {
            if let trailer = viewModel.selectedTrailer {
                TrailerPlayerView(
                    video: trailer,
                    mediaTitle: viewModel.detail?.title ?? summary?.title ?? "Unknown",
                    mediaID: mediaID
                ) {
                    showingTrailerPlayer = false
                }
            }
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
            // Title with watchlist badge
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(viewModel.detail?.title ?? summary?.title ?? "")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.textPrimary)

                // Watchlist badge
                if viewModel.isOnWatchlist {
                    Label("Watchlist", systemImage: "bookmark.fill")
                        .font(.caption)
                        .foregroundColor(Constants.Colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Constants.Colors.accent.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

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

            // Where to Watch
            whereToWatchSection

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

            // Action buttons
            actionButtons

            // Inline trailer list (if multiple trailers)
            trailersSection
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

    /// Play trailer and watchlist buttons.
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Play in-app button (primary)
            Button {
                showingTrailerPlayer = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(viewModel.hasTrailer ? Constants.UIStrings.playTrailer : Constants.UIStrings.noTrailerAvailable)
                }
                .font(.callout)
                .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasTrailer)
            .focused($isPlayButtonFocused)
            .accessibilityLabel(Constants.Accessibility.playButton)

            // Watchlist button
            Button {
                Task {
                    await viewModel.toggleWatchlist()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isOnWatchlist ? "bookmark.fill" : "bookmark")
                    Text(viewModel.isOnWatchlist ? "On Watchlist" : "Add to Watchlist")
                }
                .font(.callout)
                .fontWeight(.semibold)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isUpdatingWatchlist)
            .accessibilityLabel(viewModel.isOnWatchlist ? "Remove from watchlist" : "Add to watchlist")
        }
    }

    // MARK: - Trailers Section

    /// Inline trailer list showing all available trailers.
    @ViewBuilder
    private var trailersSection: some View {
        if viewModel.trailers.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text("All Trailers (\(viewModel.trailers.count))")
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)
                    .padding(.leading, 4)

                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(viewModel.trailers, id: \.id) { trailer in
                            InlineTrailerRow(
                                trailer: trailer,
                                onPlay: {
                                    viewModel.selectTrailer(trailer)
                                    showingTrailerPlayer = true
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Where to Watch

    /// Streaming service icons showing where the content is available.
    @ViewBuilder
    private var whereToWatchSection: some View {
        if viewModel.watchProviders.hasStreaming {
            VStack(alignment: .leading, spacing: 8) {
                Text("Where to Watch")
                    .font(.subheadline)
                    .foregroundColor(Constants.Colors.textSecondary)

                // Provider icons
                HStack(spacing: 12) {
                    ForEach(viewModel.watchProviders.streaming.prefix(6)) { provider in
                        WatchProviderButton(
                            provider: provider,
                            title: viewModel.title
                        )
                    }
                }
            }
        }
    }

}

// MARK: - Watch Provider Button

/// Tappable streaming service icon.
struct WatchProviderButton: View {

    /// The provider to display.
    let provider: WatchProvider

    /// The media title for search.
    let title: String

    /// Focus state for tvOS.
    @FocusState private var isFocused: Bool

    var body: some View {
        Button {
            Task {
                await StreamingLauncher.open(provider: provider, title: title)
            }
        } label: {
            if let logoURL = provider.logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        providerPlaceholder
                    case .empty:
                        ProgressView()
                    @unknown default:
                        providerPlaceholder
                    }
                }
            } else {
                providerPlaceholder
            }
        }
        .buttonStyle(.plain)
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Constants.Colors.accent : Color.clear, lineWidth: 3)
        )
        .scaleEffect(isFocused ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .focused($isFocused)
        .accessibilityLabel("Watch on \(provider.name)")
    }

    /// Placeholder when logo fails to load.
    private var providerPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Constants.Colors.textSecondary.opacity(0.3))
            .overlay(
                Text(String(provider.name.prefix(2)))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.textPrimary)
            )
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

// MARK: - Inline Trailer Row

/// A compact trailer row for the inline trailer list on the detail page.
struct InlineTrailerRow: View {

    /// The trailer to display.
    let trailer: Video

    /// Action when the row is tapped to play.
    var onPlay: () -> Void

    /// Focus state for tvOS.
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 10) {
                // Focus indicator - small accent bar on left when focused
                RoundedRectangle(cornerRadius: 2)
                    .fill(isFocused ? Constants.Colors.accent : Color.clear)
                    .frame(width: 3, height: 30)

                // Play icon
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundColor(isFocused ? Constants.Colors.accent : Constants.Colors.textSecondary)

                // Trailer info
                VStack(alignment: .leading, spacing: 2) {
                    Text(trailer.name)
                        .font(.callout)
                        .fontWeight(isFocused ? .semibold : .medium)
                        .foregroundColor(isFocused ? Constants.Colors.textPrimary : Constants.Colors.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(trailer.type)
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)

                        if trailer.official {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Official")
                            }
                            .font(.caption2)
                            .foregroundColor(Constants.Colors.accent)
                        }

                        if let size = trailer.size {
                            Text("\(size)p")
                                .font(.caption)
                                .foregroundColor(Constants.Colors.textSecondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .accessibilityLabel("\(trailer.name), \(trailer.type)\(trailer.official ? ", Official" : "")\(trailer.size != nil ? ", \(trailer.size!)p" : "")")
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
