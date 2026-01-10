// MARK: - TrailerSelectorView.swift
// Trailers - tvOS App
// Trailer selection screen for media with multiple trailers

import SwiftUI

/// Screen for selecting from multiple available trailers.
///
/// ## Overview
/// TrailerSelectorView shows:
/// - List of available trailers
/// - Trailer name, type, and quality
/// - Currently selected trailer highlighted
/// - Play button for each trailer
///
/// ## Usage
/// ```swift
/// NavigationLink(destination: TrailerSelectorView(viewModel: detailVM)) {
///     Text("Select Trailer")
/// }
/// ```
struct TrailerSelectorView: View {

    // MARK: - Properties

    /// Detail view model with trailers.
    @ObservedObject var viewModel: DetailViewModel

    /// Environment dismiss action.
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header

            // Trailer list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.trailers, id: \.id) { trailer in
                        TrailerRow(
                            trailer: trailer,
                            isSelected: viewModel.selectedTrailer?.id == trailer.id,
                            onSelect: {
                                viewModel.selectTrailer(trailer)
                            },
                            onPlay: {
                                Task {
                                    await viewModel.playTrailer(trailer)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 40)
            }
        }
        .background(Constants.Colors.background)
        .navigationTitle(Constants.UIStrings.selectTrailer)
    }

    // MARK: - Header

    /// Header with title and count.
    private var header: some View {
        HStack {
            Text("\(viewModel.trailerCount) Trailers Available")
                .font(.headline)
                .foregroundColor(Constants.Colors.textSecondary)

            Spacer()

            // Play selected button
            Button {
                Task {
                    await viewModel.playSelectedTrailer()
                    dismiss()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Play Selected")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedTrailer == nil)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(Constants.Colors.cardBackground.opacity(0.5))
    }
}

// MARK: - Trailer Row

/// A single row in the trailer list.
struct TrailerRow: View {

    // MARK: - Properties

    /// The trailer to display.
    let trailer: Video

    /// Whether this trailer is selected.
    let isSelected: Bool

    /// Action when row is selected.
    var onSelect: () -> Void

    /// Action when play button is tapped.
    var onPlay: () -> Void

    /// Focus state.
    @FocusState private var isFocused: Bool

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // Selection indicator
            Circle()
                .fill(isSelected ? Constants.Colors.accent : Color.clear)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Constants.Colors.textSecondary, lineWidth: 2)
                )

            // Trailer info
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(trailer.name)
                    .font(.headline)
                    .foregroundColor(Constants.Colors.textPrimary)
                    .lineLimit(1)

                // Metadata
                HStack(spacing: 12) {
                    // Type
                    Text(trailer.type)
                        .font(.caption)
                        .foregroundColor(Constants.Colors.textSecondary)

                    // Official badge
                    if trailer.official {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Official")
                        }
                        .font(.caption2)
                        .foregroundColor(Constants.Colors.accent)
                    }

                    // Quality
                    if let size = trailer.size {
                        Text("\(size)p")
                            .font(.caption)
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                }
            }

            Spacer()

            // Play button
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(Constants.Colors.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected || isFocused ? Constants.Colors.cardBackground : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Constants.Colors.accent : Color.clear, lineWidth: 3)
        )
        .focusable()
        .focused($isFocused)
        .onTapGesture {
            onSelect()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trailer.name), \(trailer.type), \(trailer.size ?? 0)p\(trailer.official ? ", Official" : "")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview

#if DEBUG
struct TrailerSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TrailerSelectorView(viewModel: DetailViewModel())
        }
    }
}
#endif
