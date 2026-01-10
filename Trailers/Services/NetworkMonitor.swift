// MARK: - NetworkMonitor.swift
// Trailers - tvOS App
// Network reachability monitoring using NWPathMonitor

import Foundation
import Network
import Combine

/// Monitors network connectivity status using NWPathMonitor.
///
/// ## Overview
/// NetworkMonitor provides real-time network status updates for:
/// - Showing "Offline" badge when disconnected
/// - Enabling offline mode with cached content
/// - Advisory only - doesn't prevent requests
///
/// ## Usage
/// ```swift
/// let monitor = NetworkMonitor.shared
///
/// // Check current status
/// if monitor.isConnected {
///     // Online
/// }
///
/// // Observe changes
/// monitor.$isConnected
///     .sink { isConnected in
///         // Update UI
///     }
///     .store(in: &cancellables)
/// ```
///
/// ## Important Notes
/// - Network reachability is advisory only
/// - Don't use to block requests (they may still succeed)
/// - Use to adjust UI messaging only
@MainActor
final class NetworkMonitor: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide network monitoring.
    static let shared = NetworkMonitor()

    // MARK: - Published Properties

    /// Whether the device currently has network connectivity.
    @Published private(set) var isConnected: Bool = true

    /// The current network path status.
    @Published private(set) var status: NWPath.Status = .satisfied

    /// Whether the connection is expensive (cellular, hotspot).
    @Published private(set) var isExpensive: Bool = false

    /// Whether the connection is constrained (Low Data Mode).
    @Published private(set) var isConstrained: Bool = false

    /// The type of network interface being used.
    @Published private(set) var interfaceType: NWInterface.InterfaceType?

    // MARK: - Private Properties

    /// The underlying path monitor.
    private let monitor: NWPathMonitor

    /// Queue for monitor callbacks.
    private let queue = DispatchQueue(label: "com.trailers.networkmonitor", qos: .utility)

    /// Whether monitoring has started.
    private var isMonitoring = false

    // MARK: - Initialization

    /// Creates a new network monitor.
    ///
    /// - Note: Use `NetworkMonitor.shared` for app-wide monitoring.
    private init() {
        self.monitor = NWPathMonitor()
        startMonitoring()
    }

    deinit {
        // Cancel monitor directly since deinit is nonisolated
        monitor.cancel()
    }

    // MARK: - Public Methods

    /// Starts network monitoring if not already running.
    func startMonitoring() {
        guard !isMonitoring else { return }

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.updateStatus(from: path)
            }
        }

        monitor.start(queue: queue)
        isMonitoring = true

        Log.network.info("Network monitoring started")
    }

    /// Stops network monitoring.
    func stopMonitoring() {
        guard isMonitoring else { return }

        monitor.cancel()
        isMonitoring = false

        Log.network.info("Network monitoring stopped")
    }

    // MARK: - Private Methods

    /// Updates published properties from network path.
    @MainActor
    private func updateStatus(from path: NWPath) {
        let wasConnected = isConnected

        isConnected = path.status == .satisfied
        status = path.status
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        // Determine interface type
        if path.usesInterfaceType(.wifi) {
            interfaceType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            interfaceType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            interfaceType = .wiredEthernet
        } else {
            interfaceType = nil
        }

        // Log status changes
        if wasConnected != isConnected {
            if isConnected {
                Log.network.info("Network connected via \(self.interfaceType?.description ?? "unknown")")
            } else {
                Log.network.warning("Network disconnected")
            }
        }
    }
}

// MARK: - Interface Type Description

extension NWInterface.InterfaceType {
    /// Human-readable description of the interface type.
    var description: String {
        switch self {
        case .wifi:
            return "WiFi"
        case .cellular:
            return "Cellular"
        case .wiredEthernet:
            return "Ethernet"
        case .loopback:
            return "Loopback"
        case .other:
            return "Other"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Convenience Properties

extension NetworkMonitor {

    /// Whether the device is offline.
    var isOffline: Bool {
        !isConnected
    }

    /// User-friendly status message.
    var statusMessage: String {
        if isConnected {
            if isConstrained {
                return "Connected (Low Data Mode)"
            } else if isExpensive {
                return "Connected (Metered)"
            } else {
                return "Connected"
            }
        } else {
            return "Offline"
        }
    }
}
