#if os(iOS)
import Foundation
import Network

/// Edge Case D: Network offline fallback.
/// Monitors network connectivity and provides fallback responses
/// when network is unavailable. Safety layer must work offline.
@MainActor
final class NetworkMonitorService: ObservableObject {
    static let shared = NetworkMonitorService()

    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi, cellular, wired, unknown
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.komal.networkmonitor")

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isConnected = (path.status == .satisfied)

                if path.usesInterfaceType(.wifi) {
                    self?.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self?.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self?.connectionType = .wired
                } else {
                    self?.connectionType = .unknown
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Offline Fallback Responses

    /// On-device fallback responses when network is unavailable.
    /// Per spec: No gating delay allowed. Safety layer must work offline.
    static let offlineFallbackResponses: [String] = [
        "Hey, it looks like we're offline right now! But I'm still here. Want to tell me about your day?",
        "I can't reach my brain in the cloud right now, but that's okay! Let's just hang out.",
        "Hmm, no internet at the moment. But hey, I'm still me! What's on your mind?",
        "We're offline, but I'm still listening! Tell me something cool.",
    ]

    /// Fallback grounding responses for when child seems distressed offline
    static let offlineGroundingResponses: [String] = [
        "I'm here with you. Let's take a deep breath together... in... and out.",
        "It's okay. Let's do something calming. Can you wiggle your toes and take a big breath?",
        "I might be offline, but I still care. Let's breathe together for a moment.",
    ]

    /// Get an appropriate offline response
    func getOfflineResponse(isDistressed: Bool = false) -> String {
        if isDistressed {
            return Self.offlineGroundingResponses.randomElement() ?? Self.offlineGroundingResponses[0]
        }
        return Self.offlineFallbackResponses.randomElement() ?? Self.offlineFallbackResponses[0]
    }
}
#endif
