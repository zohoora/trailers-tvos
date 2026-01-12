// MARK: - TrailersApp.swift
// Trailers - tvOS App
// Application entry point and app lifecycle management

import SwiftUI

/// Main application entry point for the Trailers tvOS app.
///
/// ## Overview
/// TrailersApp is the SwiftUI App conforming type that:
/// - Configures the app environment
/// - Sets up the root BrowseView
/// - Handles app lifecycle events
/// - Manages memory warnings
///
/// ## Architecture
/// The app uses a single-screen root (BrowseView) with push navigation
/// to detail screens. There are no tabs.
///
/// ## Memory Management
/// On memory warning:
/// - Clears image memory cache
/// - Clears API response memory cache
/// - Keeps visible content intact
///
/// ## Usage
/// This is the @main entry point, automatically instantiated by SwiftUI.
@main
struct TrailersApp: App {

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            BrowseView()
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    handleMemoryWarning()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhase(newPhase)
        }
    }

    // MARK: - Initialization

    init() {
        // Configure image pipeline
        ImagePipeline.configure()

        // Log app launch
        Log.app.info("Trailers app launched")

        // Validate configuration
        #if DEBUG
        validateConfiguration()
        #endif
    }

    // MARK: - Memory Management

    /// Handles memory warning by clearing non-essential caches.
    private func handleMemoryWarning() {
        Log.app.warning("Memory warning received, clearing caches")

        // Clear image memory cache
        ImagePipeline.clearMemoryCache()

        // Clear response memory cache
        Task {
            let cache = ResponseCache()
            await cache.clearMemoryCache()
        }
    }

    // MARK: - Configuration Validation

    /// Validates that required configuration is present.
    private func validateConfiguration() {
        // This will crash with helpful message if API key not configured
        _ = Config.tmdbAPIKey
        Log.app.info("Configuration validated successfully")
    }
}

// MARK: - Scene Phase Handler

/// Handles scene phase changes.
extension TrailersApp {

    /// Responds to scene phase changes.
    ///
    /// - Parameter phase: The new scene phase
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Log.app.info("App became active")
            // Resume network monitoring
            NetworkMonitor.shared.startMonitoring()

        case .inactive:
            Log.app.info("App became inactive")

        case .background:
            Log.app.info("App entered background")
            // Stop all background activity to allow device to sleep
            suspendBackgroundActivity()

        @unknown default:
            break
        }
    }

    /// Suspends all background activity when app is backgrounded.
    ///
    /// This allows the Apple TV to enter sleep mode properly.
    private func suspendBackgroundActivity() {
        // Stop network monitoring
        NetworkMonitor.shared.stopMonitoring()

        // Clear trailer prefetch cache (stops AVPlayer buffering)
        Task {
            await TrailerPrefetchService.shared.clearCache()
        }

        // Clear detail prefetch pending tasks
        Task {
            await PrefetchService.shared.cancelAll()
        }

        Log.app.info("Background activity suspended")
    }
}
