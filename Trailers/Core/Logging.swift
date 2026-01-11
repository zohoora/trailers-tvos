// MARK: - Logging.swift
// Trailers - tvOS App
// Structured logging system using OSLog

import Foundation
import OSLog

/// Centralized logging system using Apple's unified logging framework (OSLog).
///
/// ## Overview
/// This logging system provides structured, performant logging with different categories
/// and log levels. It uses OSLog for optimal performance on tvOS and integration
/// with Console.app for debugging.
///
/// ## Log Categories
/// - **network**: API requests, responses, and network errors
/// - **cache**: Cache hits, misses, and storage operations
/// - **ui**: View lifecycle, focus changes, and user interactions
/// - **data**: Data transformations and model operations
/// - **app**: App lifecycle and general events
///
/// ## Log Levels
/// - **debug**: Detailed debugging information (only in DEBUG builds)
/// - **info**: General information about app operation
/// - **warning**: Potentially problematic situations
/// - **error**: Errors that don't crash but indicate problems
/// - **fault**: Critical errors that may indicate bugs
///
/// ## Usage
/// ```swift
/// // Network logging
/// Log.network.debug("Starting request to \(endpoint)")
/// Log.network.error("Request failed: \(error.localizedDescription)")
///
/// // Cache logging
/// Log.cache.info("Cache hit for key: \(key)")
///
/// // Signpost for performance profiling
/// Log.beginSignpost("LoadGrid", id: requestID)
/// // ... perform work ...
/// Log.endSignpost("LoadGrid", id: requestID)
/// ```
enum Log {

    // MARK: - Log Categories

    /// Logger for network operations (API requests, responses, errors).
    static let network = Logger(subsystem: subsystem, category: "network")

    /// Logger for cache operations (hits, misses, storage).
    static let cache = Logger(subsystem: subsystem, category: "cache")

    /// Logger for UI events (focus, navigation, interactions).
    static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Logger for data operations (parsing, transformations).
    static let data = Logger(subsystem: subsystem, category: "data")

    /// Logger for app lifecycle events.
    static let app = Logger(subsystem: subsystem, category: "app")

    /// Logger for filter operations.
    static let filter = Logger(subsystem: subsystem, category: "filter")

    /// Logger for pagination operations.
    static let pagination = Logger(subsystem: subsystem, category: "pagination")

    // MARK: - Private Properties

    /// The subsystem identifier for all loggers.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.personal.trailers"

    // MARK: - Signpost Support

    /// Signpost logger for performance profiling.
    private static let signpostLog = OSLog(subsystem: subsystem, category: .pointsOfInterest)

    /// Active signpost IDs for tracking paired begin/end events.
    nonisolated(unsafe) private static var activeSignposts: [String: OSSignpostID] = [:]
    private static let signpostLock = NSLock()

    /// Begins a signpost interval for performance measurement.
    ///
    /// Use with `endSignpost` to measure the duration of operations.
    ///
    /// - Parameters:
    ///   - name: A descriptive name for the operation
    ///   - id: A unique identifier to match begin/end pairs
    ///   - message: Optional additional message
    ///
    /// ## Example
    /// ```swift
    /// Log.beginSignpost("FetchMovies", id: "page-1")
    /// let movies = await fetchMovies()
    /// Log.endSignpost("FetchMovies", id: "page-1")
    /// ```
    static func beginSignpost(_ name: StaticString, id: String, message: String? = nil) {
        #if DEBUG
        let signpostID = OSSignpostID(log: signpostLog)

        signpostLock.lock()
        activeSignposts["\(name):\(id)"] = signpostID
        signpostLock.unlock()

        if let message = message {
            os_signpost(.begin, log: signpostLog, name: name, signpostID: signpostID, "%{public}s", message)
        } else {
            os_signpost(.begin, log: signpostLog, name: name, signpostID: signpostID)
        }
        #endif
    }

    /// Ends a signpost interval for performance measurement.
    ///
    /// - Parameters:
    ///   - name: Must match the name used in `beginSignpost`
    ///   - id: Must match the id used in `beginSignpost`
    ///   - message: Optional additional message
    static func endSignpost(_ name: StaticString, id: String, message: String? = nil) {
        #if DEBUG
        let key = "\(name):\(id)"

        signpostLock.lock()
        guard let signpostID = activeSignposts.removeValue(forKey: key) else {
            signpostLock.unlock()
            return
        }
        signpostLock.unlock()

        if let message = message {
            os_signpost(.end, log: signpostLog, name: name, signpostID: signpostID, "%{public}s", message)
        } else {
            os_signpost(.end, log: signpostLog, name: name, signpostID: signpostID)
        }
        #endif
    }

    /// Emits a single signpost event (not an interval).
    ///
    /// Useful for marking specific points in time, like user interactions.
    ///
    /// - Parameters:
    ///   - name: A descriptive name for the event
    ///   - message: Optional additional message
    static func event(_ name: StaticString, message: String? = nil) {
        #if DEBUG
        let signpostID = OSSignpostID(log: signpostLog)
        if let message = message {
            os_signpost(.event, log: signpostLog, name: name, signpostID: signpostID, "%{public}s", message)
        } else {
            os_signpost(.event, log: signpostLog, name: name, signpostID: signpostID)
        }
        #endif
    }
}

// MARK: - Logger Extensions

extension Logger {

    /// Logs a debug message (only in DEBUG builds).
    ///
    /// Debug messages are stripped from release builds for performance.
    ///
    /// - Parameter message: The message to log
    func debugMessage(_ message: String) {
        #if DEBUG
        self.debug("\(message, privacy: .public)")
        #endif
    }

    /// Logs an error with optional underlying error details.
    ///
    /// - Parameters:
    ///   - message: A description of what was being attempted
    ///   - error: The underlying error, if any
    func logError(_ message: String, error: Error? = nil) {
        if let error = error {
            self.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            self.error("\(message, privacy: .public)")
        }
    }

    /// Logs a network request.
    ///
    /// - Parameters:
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - url: The request URL
    func logRequest(_ method: String, url: URL) {
        self.info("[\(method, privacy: .public)] \(url.absoluteString, privacy: .public)")
    }

    /// Logs a network response.
    ///
    /// - Parameters:
    ///   - statusCode: HTTP status code
    ///   - url: The request URL
    ///   - duration: Request duration in seconds
    func logResponse(_ statusCode: Int, url: URL, duration: TimeInterval) {
        let durationMs = Int(duration * 1000)
        self.info("[\(statusCode, privacy: .public)] \(url.absoluteString, privacy: .public) (\(durationMs, privacy: .public)ms)")
    }

    /// Logs a cache operation.
    ///
    /// - Parameters:
    ///   - operation: The type of operation (hit, miss, store, expire)
    ///   - key: The cache key
    func logCache(_ operation: String, key: String) {
        self.debug("Cache \(operation, privacy: .public): \(key, privacy: .public)")
    }

    /// Logs a filter state change.
    ///
    /// - Parameters:
    ///   - filter: Name of the filter that changed
    ///   - value: New value of the filter
    func logFilterChange(_ filter: String, value: String) {
        self.info("Filter changed: \(filter, privacy: .public) = \(value, privacy: .public)")
    }

    /// Logs a pagination event.
    ///
    /// - Parameters:
    ///   - page: Current page number
    ///   - totalItems: Total items loaded so far
    func logPagination(page: Int, totalItems: Int) {
        self.debug("Loaded page \(page, privacy: .public), total items: \(totalItems, privacy: .public)")
    }
}

// MARK: - Debug Print Helper

/// Debug print helper that only prints in DEBUG builds.
///
/// - Parameter items: Items to print
func debugPrint(_ items: Any...) {
    #if DEBUG
    for item in items {
        print(item)
    }
    #endif
}
