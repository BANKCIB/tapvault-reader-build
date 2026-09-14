import Foundation

/// Bounds rediscovery and pins a scan to its first observed chip, not a stale Core NFC object.
public struct TagScanRecovery: Sendable {
    public private(set) var retryCount = 0
    private var identity: String?
    private var hasIdentifier = false
    private var versionFailures = 0
    public init() {}
    public var shouldReadVersion: Bool { versionFailures < 2 }
    public mutating func accepts(technology: String, identifier: String) -> Bool {
        let candidate = technology + "|" + identifier
        if let identity { return identity == candidate }
        identity = candidate; hasIdentifier = !identifier.isEmpty
        return true
    }
    public mutating func retryVersionFailure(connectionLost: Bool) -> Bool {
        versionFailures = connectionLost ? versionFailures + 1 : 2
        return retryConnectionLoss()
    }
    public mutating func retryConnectionLoss() -> Bool {
        guard hasIdentifier, retryCount < 2 else { return false }
        retryCount += 1; return true
    }
}
