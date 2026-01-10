// MARK: - ErrorOverlayView.swift
// Trailers - tvOS App
// Error overlay component for displaying errors

import SwiftUI

/// Overlay view for displaying errors with retry option.
///
/// ## Overview
/// ErrorOverlayView shows:
/// - Error icon
/// - Error title
/// - Error message
/// - Retry button (if error is retryable)
///
/// ## Usage
/// ```swift
/// ZStack {
///     ContentView()
///
///     if let error = viewModel.error {
///         ErrorOverlayView(
///             error: error,
///             onRetry: { Task { await viewModel.reload() } }
///         )
///     }
/// }
/// ```
struct ErrorOverlayView: View {

    // MARK: - Properties

    /// The error to display.
    let error: NetworkError

    /// Action to perform on retry.
    var onRetry: (() -> Void)?

    /// Focus state for retry button.
    @FocusState private var retryFocused: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Error icon
            errorIcon

            // Title
            Text(Constants.UIStrings.errorTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)

            // Message
            Text(error.localizedDescription)
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            // Retry button (if retryable)
            if error.isRetryable, let onRetry = onRetry {
                Button(action: onRetry) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text(Constants.UIStrings.errorRetry)
                    }
                    .font(.callout)
                    .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .focused($retryFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        retryFocused = true
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Constants.Colors.background.opacity(0.95))
    }

    // MARK: - Subviews

    /// Icon name for the error type.
    private var errorIconName: String {
        switch error {
        case .noConnection:
            return "wifi.slash"
        case .rateLimited:
            return "clock.badge.exclamationmark"
        case .serverError:
            return "exclamationmark.icloud"
        default:
            return "exclamationmark.triangle"
        }
    }

    /// Icon color for the error type.
    private var errorIconColor: Color {
        switch error {
        case .noConnection:
            return Constants.Colors.offlineBadgeColor
        case .rateLimited:
            return .orange
        case .serverError, .timeout, .decodingError, .unknown, .notFound, .forbidden, .unauthorized, .cancelled, .invalidURL:
            return Constants.Colors.errorColor
        }
    }

    /// Icon for the error type.
    private var errorIcon: some View {
        Image(systemName: errorIconName)
            .font(.system(size: 60))
            .foregroundColor(errorIconColor.opacity(0.8))
    }
}

// MARK: - Rate Limit Countdown View

/// View showing rate limit countdown.
struct RateLimitCountdownView: View {
    /// Remaining seconds until retry.
    let remainingSeconds: Int

    /// Action when countdown completes.
    var onComplete: () -> Void

    /// Timer for countdown.
    @State private var timeRemaining: Int = 0

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.8))

            Text(Constants.UIStrings.rateLimitTitle)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)

            Text(String(format: Constants.UIStrings.rateLimitMessage, timeRemaining))
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)

            // Countdown circle
            ZStack {
                Circle()
                    .stroke(Constants.Colors.cardBackground, lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: CGFloat(timeRemaining) / CGFloat(remainingSeconds))
                    .stroke(Constants.Colors.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                Text("\(timeRemaining)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Constants.Colors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Constants.Colors.background.opacity(0.95))
        .onAppear {
            timeRemaining = remainingSeconds
            startCountdown()
        }
    }

    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
                onComplete()
            }
        }
    }
}

// MARK: - Configuration Error View

/// View for API configuration errors.
struct ConfigurationErrorView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "gear.badge.xmark")
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.errorColor.opacity(0.8))

            Text(Constants.UIStrings.configurationError)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Colors.textPrimary)

            Text(Constants.UIStrings.configurationErrorMessage)
                .font(.body)
                .foregroundColor(Constants.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: 1, text: "Create Config.xcconfig file")
                instructionRow(number: 2, text: "Add TMDB_READ_ACCESS_TOKEN = your_token")
                instructionRow(number: 3, text: "Rebuild and run the app")
            }
            .padding()
            .background(Constants.Colors.cardBackground)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Constants.Colors.background)
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Constants.Colors.accent)
                .clipShape(Circle())

            Text(text)
                .font(.body)
                .foregroundColor(Constants.Colors.textPrimary)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ErrorViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ErrorOverlayView(
                error: .noConnection,
                onRetry: {}
            )
            .previewDisplayName("No Connection")

            ErrorOverlayView(
                error: .serverError(statusCode: 500),
                onRetry: {}
            )
            .previewDisplayName("Server Error")

            RateLimitCountdownView(remainingSeconds: 10, onComplete: {})
                .previewDisplayName("Rate Limit")

            ConfigurationErrorView()
                .previewDisplayName("Config Error")
        }
    }
}
#endif
