import Foundation

public struct CloudMaterializationChecker: CloudMaterializationChecking {
    public init() {}

    public func availabilityState(for url: URL) async throws -> FileAvailabilityState {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .unavailableUnknown
        }
        return .notCloudManaged
    }

    public func requestMaterialization(of url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ConversionError.sourceNotFound
        }
    }

    public func waitUntilMaterialized(_ url: URL, timeout: Duration) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            let state = try await availabilityState(for: url)
            switch state {
            case .localAndCurrent, .notCloudManaged:
                return
            case .downloadFailed(let message):
                throw ConversionError.cloudMaterializationFailed(underlyingDescription: message)
            case .unavailableUnknown:
                throw ConversionError.providerUnavailable
            case .localButNotCurrent, .notDownloaded, .downloading:
                try await Task.sleep(for: .seconds(2))
            }
        }
        throw ConversionError.cloudMaterializationTimeout
    }
}
