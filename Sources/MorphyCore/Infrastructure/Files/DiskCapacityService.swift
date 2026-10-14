import Foundation

public struct DiskCapacityService: Sendable {
    public init() {}

    public func hasRoomForSingleOutput(near folderURL: URL, sourceSize: Int64, pixelCount: Int?) -> Bool {
        guard let available = importantAvailableCapacity(for: folderURL) else {
            return true
        }
        let pixelEstimate = Int64(pixelCount ?? 0) * 4
        let conservativeNeed = max(sourceSize * 3, pixelEstimate + 8 * 1_024 * 1_024)
        let safetyFloor: Int64 = 64 * 1_024 * 1_024
        return available > conservativeNeed + safetyFloor
    }

    public func importantAvailableCapacity(for folderURL: URL) -> Int64? {
        let values = try? folderURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }
}
