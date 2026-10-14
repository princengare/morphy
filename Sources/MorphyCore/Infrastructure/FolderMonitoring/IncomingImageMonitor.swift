import Darwin
import Dispatch
import Foundation

public actor IncomingImageMonitor {
    public typealias ReadyHandler = @Sendable (URL, SourceIdentitySnapshot) async -> Void
    public typealias FailureHandler = @Sendable (URL, ConversionError) async -> Void

    private let stabilityChecker: any FileStabilityChecking
    private var events: DirectoryEventSource?
    private var folder: URL?
    private var generation = UUID()
    private var knownFiles: Set<FileKey> = []
    private var pending: [FileKey: Task<Void, Never>] = [:]
    private var rescanTask: Task<Void, Never>?
    private var onReady: ReadyHandler?
    private var onFailure: FailureHandler?

    public init(stabilityChecker: any FileStabilityChecking = FileStabilityChecker()) {
        self.stabilityChecker = stabilityChecker
    }

    public func start(folder: URL, onReady: @escaping ReadyHandler, onFailure: @escaping FailureHandler) throws {
        stop()
        let canonicalFolder = folder.standardizedFileURL.resolvingSymlinksInPath()
        knownFiles = Set(try candidates(in: canonicalFolder).keys)
        self.folder = canonicalFolder
        self.onReady = onReady
        self.onFailure = onFailure
        let currentGeneration = generation
        events = try DirectoryEventSource(folder: canonicalFolder) { [weak self] flags in
            Task { await self?.folderChanged(flags: flags, generation: currentGeneration) }
        }
        // Rescan after installing the source so arrivals during startup are included.
        Task { [weak self] in await self?.scan(generation: currentGeneration) }
    }

    public func stop() {
        generation = UUID()
        events?.cancel()
        events = nil
        rescanTask?.cancel()
        rescanTask = nil
        pending.values.forEach { $0.cancel() }
        pending.removeAll()
        knownFiles.removeAll()
        folder = nil
        onReady = nil
        onFailure = nil
    }

    private func folderChanged(flags: UInt, generation: UUID) async {
        guard generation == self.generation, let folder else { return }
        let event = DispatchSource.FileSystemEvent(rawValue: flags)
        if !event.intersection([.delete, .rename, .revoke]).isEmpty {
            let failure = onFailure
            stop()
            await failure?(folder, .permissionDenied)
            return
        }
        guard rescanTask == nil else { return }
        rescanTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(100))
                await self?.scan(generation: generation)
            } catch {}
        }
    }

    private func scan(generation: UUID) async {
        guard generation == self.generation, let folder else { return }
        rescanTask = nil
        do {
            let files = try candidates(in: folder)
            let arrivals = files.filter { !knownFiles.contains($0.key) }
            knownFiles = Set(files.keys)
            for (key, url) in arrivals.sorted(by: { $0.value.path < $1.value.path }) {
                let checker = stabilityChecker
                pending[key] = Task { [weak self] in
                    do {
                        let snapshot = try await checker.waitUntilStable(url)
                        try Task.checkCancellation()
                        await self?.ready(url: url, key: key, snapshot: snapshot, generation: generation)
                    } catch is CancellationError {
                    } catch {
                        await self?.failed(url: url, key: key, error: error, generation: generation)
                    }
                }
            }
        } catch {
            let failure = onFailure
            stop()
            await failure?(folder, .permissionDenied)
        }
    }

    private func ready(url: URL, key: FileKey, snapshot: SourceIdentitySnapshot, generation: UUID) async {
        guard generation == self.generation, pending.removeValue(forKey: key) != nil,
              snapshot.fileResourceIdentifier == key.resourceIdentifier else { return }
        await onReady?(url, snapshot)
    }

    private func failed(url: URL, key: FileKey, error: Error, generation: UUID) async {
        guard generation == self.generation else { return }
        pending.removeValue(forKey: key)
        let failure = (error as? ConversionError) ?? .unknown(error.localizedDescription)
        if failure != .sourceNotFound {
            await onFailure?(url, failure)
        }
    }

    private func candidates(in folder: URL) throws -> [FileKey: URL] {
        let urls = try FileManager.default.contentsOfDirectory(at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileResourceIdentifierKey],
            options: [.skipsHiddenFiles])
        var result: [FileKey: URL] = [:]
        for url in urls where ["heic", "heif"].contains(url.pathExtension.lowercased()) {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileResourceIdentifierKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            let key = FileKey(path: url.standardizedFileURL.path,
                resourceIdentifier: values.fileResourceIdentifier.map { String(describing: $0) })
            result[key] = url
        }
        return result
    }
}

private struct FileKey: Hashable, Sendable {
    let path: String
    let resourceIdentifier: String?
}

private final class DirectoryEventSource: @unchecked Sendable {
    private let source: any DispatchSourceFileSystemObject

    init(folder: URL, onChange: @escaping @Sendable (UInt) -> Void) throws {
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { throw ConversionError.permissionDenied }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .revoke], queue: .global(qos: .utility))
        self.source = source
        source.setEventHandler { [weak source] in
            guard let source else { return }
            onChange(source.data.rawValue)
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
    }

    func cancel() { source.cancel() }

    deinit { source.cancel() }
}
