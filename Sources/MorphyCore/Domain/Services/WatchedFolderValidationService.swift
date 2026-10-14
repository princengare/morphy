import Foundation

public struct WatchedFolderValidationService: Sendable {
    public init() {}

    public func conflict(between existing: WatchedFolder, candidate: WatchedFolder) -> WatchedFolderConflict? {
        let existingURL = existing.displayURL.standardizedFileURL.resolvingSymlinksInPath()
        let candidateURL = candidate.displayURL.standardizedFileURL.resolvingSymlinksInPath()

        if existingURL.path == candidateURL.path {
            return .sameCanonicalPath
        }

        if existing.includeSubfolders, candidateURL.path.hasPrefix(existingURL.path + "/") {
            return .existingRecursiveParent
        }

        if candidate.includeSubfolders, existingURL.path.hasPrefix(candidateURL.path + "/") {
            return .newRecursiveParent
        }

        return nil
    }
}
