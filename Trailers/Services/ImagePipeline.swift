// MARK: - ImagePipeline.swift
// Trailers - tvOS App
// Image loading and caching using Nuke (to be added as package dependency)

import SwiftUI

// Note: This file provides a placeholder implementation.
// In production, this would use Nuke for efficient image loading.
// The actual Nuke integration will be handled via Swift Package Manager.

/// Configuration for the image loading pipeline.
///
/// ## Overview
/// ImagePipeline provides centralized image loading configuration for:
/// - Memory and disk caching
/// - Progressive loading
/// - Placeholder images
///
/// ## Integration
/// Uses Nuke library (add via SPM):
/// - Package: https://github.com/kean/Nuke
/// - Version: 12.0.0 or later
///
/// ## Usage
/// ```swift
/// // In views, use AsyncImage or Nuke's LazyImage:
/// LazyImage(url: posterURL) { state in
///     if let image = state.image {
///         image.resizable()
///     } else {
///         PlaceholderView()
///     }
/// }
/// ```
enum ImagePipeline {

    // MARK: - Configuration

    /// Configures the image loading pipeline.
    ///
    /// Call this at app launch to set up caching and loading options.
    static func configure() {
        // Nuke configuration would go here
        // Example:
        // ImagePipeline.shared = ImagePipeline(configuration: .init(
        //     dataCache: try? DataCache(name: "com.trailers.images"),
        //     dataCachePolicy: .automatic
        // ))

        Log.app.info("Image pipeline configured")
    }

    // MARK: - Cache Management

    /// Clears the image memory cache.
    ///
    /// Call on memory warning.
    static func clearMemoryCache() {
        // ImageCache.shared.removeAll()
        Log.cache.info("Image memory cache cleared")
    }

    /// Clears all image caches (memory and disk).
    static func clearAllCaches() {
        // ImageCache.shared.removeAll()
        // DataLoader.sharedUrlCache.removeAllCachedResponses()
        Log.cache.info("All image caches cleared")
    }

    // MARK: - URL Helpers

    /// Creates a poster URL for grid display.
    ///
    /// - Parameter path: The poster path from TMDB
    /// - Returns: Full URL or nil
    static func posterURL(path: String?) -> URL? {
        Config.posterURL(path: path, size: .grid)
    }

    /// Creates a poster URL for detail display.
    ///
    /// - Parameter path: The poster path from TMDB
    /// - Returns: Full URL or nil
    static func detailPosterURL(path: String?) -> URL? {
        Config.posterURL(path: path, size: .detail)
    }

    /// Creates a backdrop URL for detail display.
    ///
    /// - Parameter path: The backdrop path from TMDB
    /// - Returns: Full URL or nil
    static func backdropURL(path: String?) -> URL? {
        Config.backdropURL(path: path, size: .detail)
    }
}

// MARK: - Placeholder View

/// Placeholder view shown while images are loading.
struct ImagePlaceholder: View {
    /// The title to display on the placeholder.
    let title: String?

    /// Whether this is for a poster (2:3) or backdrop (16:9).
    let isPoster: Bool

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Constants.Colors.cardBackground,
                    Constants.Colors.cardBackground.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Film icon
            Image(systemName: isPoster ? "film" : "tv")
                .font(.system(size: isPoster ? 40 : 60))
                .foregroundColor(Constants.Colors.textSecondary.opacity(0.5))

            // Title if provided
            if let title = title, !title.isEmpty {
                VStack {
                    Spacer()
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Constants.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 12)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isPoster ? Constants.Layout.posterCornerRadius : 8))
    }

    /// Creates a poster placeholder.
    static func poster(title: String? = nil) -> ImagePlaceholder {
        ImagePlaceholder(title: title, isPoster: true)
    }

    /// Creates a backdrop placeholder.
    static func backdrop() -> ImagePlaceholder {
        ImagePlaceholder(title: nil, isPoster: false)
    }
}

// MARK: - Async Poster Image

/// Async image view optimized for poster display.
///
/// Uses SwiftUI's built-in AsyncImage with TMDB-specific configuration.
struct AsyncPosterImage: View {
    let url: URL?
    let title: String?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ImagePlaceholder.poster(title: title)

            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)

            case .failure:
                ImagePlaceholder.poster(title: title)

            @unknown default:
                ImagePlaceholder.poster(title: title)
            }
        }
    }

    init(path: String?, title: String? = nil) {
        self.url = ImagePipeline.posterURL(path: path)
        self.title = title
    }

    init(url: URL?, title: String? = nil) {
        self.url = url
        self.title = title
    }
}

// MARK: - Async Backdrop Image

/// Async image view optimized for backdrop display.
struct AsyncBackdropImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ImagePlaceholder.backdrop()

            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)

            case .failure:
                ImagePlaceholder.backdrop()

            @unknown default:
                ImagePlaceholder.backdrop()
            }
        }
    }

    init(path: String?) {
        self.url = ImagePipeline.backdropURL(path: path)
    }

    init(url: URL?) {
        self.url = url
    }
}

// MARK: - Preview

#if DEBUG
struct ImagePlaceholder_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            ImagePlaceholder.poster(title: "Movie Title")
                .frame(width: 150, height: 225)

            ImagePlaceholder.backdrop()
                .frame(width: 300, height: 169)
        }
        .padding()
        .background(Color.black)
    }
}
#endif
