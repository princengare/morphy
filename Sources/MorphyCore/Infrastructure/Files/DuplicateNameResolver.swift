import Foundation

public struct DuplicateNameResolver: Sendable {
    public init() {}

    public func resolvedURL(for proposedURL: URL, policy: DuplicatePolicy) throws -> URL {
        guard FileManager.default.fileExists(atPath: proposedURL.path) else {
            return proposedURL
        }

        switch policy {
        case .addNumber:
            return try numberedURL(for: proposedURL)
        case .appendTimestamp:
            return timestampedURL(for: proposedURL)
        case .replaceExisting:
            return proposedURL
        case .skip, .ask:
            throw ConversionError.duplicateConflict
        }
    }

    private func numberedURL(for proposedURL: URL) throws -> URL {
        let folder = proposedURL.deletingLastPathComponent()
        let baseName = proposedURL.deletingPathExtension().lastPathComponent
        let pathExtension = proposedURL.pathExtension

        for number in 2...10_000 {
            let candidate = folder
                .appendingPathComponent("\(baseName) \(number)")
                .appendingPathExtension(pathExtension)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        throw ConversionError.duplicateConflict
    }

    private func timestampedURL(for proposedURL: URL) -> URL {
        let folder = proposedURL.deletingLastPathComponent()
        let baseName = proposedURL.deletingPathExtension().lastPathComponent
        let pathExtension = proposedURL.pathExtension
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate]
        let stamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "T", with: "-")
            .replacingOccurrences(of: "Z", with: "")
        return folder
            .appendingPathComponent("\(baseName)-\(stamp)")
            .appendingPathExtension(pathExtension)
    }
}
