import Foundation
@preconcurrency import ImageIO

public struct FileStabilityPolicy: Sendable, Equatable {
    public let initialDelay: Duration
    public let pollInterval: Duration
    public let requiredStableObservations: Int
    public let maximumWait: Duration

    public init(
        initialDelay: Duration = .milliseconds(500),
        pollInterval: Duration = .milliseconds(500),
        requiredStableObservations: Int = 3,
        maximumWait: Duration = .seconds(60)
    ) {
        self.initialDelay = initialDelay
        self.pollInterval = pollInterval
        self.requiredStableObservations = requiredStableObservations
        self.maximumWait = maximumWait
    }
}

public actor FileStabilityChecker: FileStabilityChecking {
    private let policy: FileStabilityPolicy

    public init(policy: FileStabilityPolicy = FileStabilityPolicy()) {
        self.policy = policy
    }

    public func waitUntilStable(_ url: URL) async throws -> SourceIdentitySnapshot {
        try await Task.sleep(for: policy.initialDelay)
        let deadline = ContinuousClock.now.advanced(by: policy.maximumWait)
        var previousSnapshot: SourceIdentitySnapshot?
        var stableObservations = 0

        while ContinuousClock.now < deadline {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ConversionError.sourceNotFound
            }
            let snapshot = try SourceIdentitySnapshot.capture(for: url)
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw ConversionError.unsupportedSourceFormat
            }
            guard snapshot.size > 0 else {
                stableObservations = 0
                try await Task.sleep(for: policy.pollInterval)
                continue
            }

            if let previousSnapshot,
               previousSnapshot.size == snapshot.size,
               previousSnapshot.modificationDate == snapshot.modificationDate {
                stableObservations += 1
            } else {
                stableObservations = 1
            }

            if stableObservations >= policy.requiredStableObservations,
               let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               CGImageSourceGetStatus(source) == .statusComplete,
               CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete,
               CGImageSourceCopyPropertiesAtIndex(source, 0, nil) != nil {
                return snapshot
            }

            previousSnapshot = snapshot
            try await Task.sleep(for: policy.pollInterval)
        }

        throw ConversionError.sourceUnstable
    }
}
