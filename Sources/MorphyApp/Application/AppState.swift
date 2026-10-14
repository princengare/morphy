import AppKit
import Combine
import Foundation
import MorphyCore
import UniformTypeIdentifiers

enum AppRoute: Equatable {
    case home
    case export
    case conversion
    case history
    case settings
}

enum ConversionPhase: Equatable {
    case idle
    case running(filename: String)
    case succeeded(record: ConversionRecord)
    case failed(message: String)
}

enum ConversionPresentation {
    static let minimumAnimationDuration: Duration = .seconds(3)

    static func phase(for actualPhase: ConversionPhase, sessionID: UUID,
        completedIntroSessionID: UUID?) -> ConversionPhase {
        if case .succeeded(let record) = actualPhase, completedIntroSessionID != sessionID {
            return .running(filename: record.sourceFilename)
        }
        return actualPhase
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute = .home
    @Published var monitoringEnabled = true {
        didSet {
            guard preferencesLoaded, oldValue != monitoringEnabled else { return }
            savePreferences()
            if environment.automaticallyMonitorFolder {
                Task { await restartAutomaticMonitoring() }
            }
        }
    }
    @Published var animateLeaves = true { didSet { savePreferences() } }
    @Published var notificationsEnabled = true { didSet { savePreferences() } }
    @Published var removeLocationInformation = false { didSet { savePreferences() } }
    @Published var selectedFormat: OutputFormat = .jpeg { didSet { savePreferences() } }
    @Published var qualityPreset: QualityPreset = .recommended { didSet { savePreferences() } }
    @Published var originalPolicy: OriginalFilePolicy = .keep
    @Published var destination: DestinationStrategy = .sameFolder
    @Published var duplicatePolicy: DuplicatePolicy = .addNumber
    @Published var recentConversions: [ConversionRecord] = []
    @Published var conversionPhase: ConversionPhase = .idle
    @Published private(set) var conversionSessionID = UUID()
    @Published var webPAvailable = false
    @Published private(set) var watchedFolder: URL
    @Published private(set) var monitoringStatus = "Starting"
    @Published private(set) var monitoringNeedsAccess = false

    private let environment: AppEnvironment
    private let incomingMonitor = IncomingImageMonitor()
    private var launchObservation: AnyCancellable?
    private var watchedFolderBookmark: Data?
    private var scopedFolder: URL?
    private var monitoringRevision = 0
    private var pendingConversions: [ImageConversionRequest] = []
    private var activeSources: Set<String> = []
    private var completedSources: [String: SourceIdentitySnapshot] = [:]
    private var conversionTask: Task<Void, Never>?
    private var preferencesLoaded = false

    init(environment: AppEnvironment) {
        self.environment = environment
        let preferences = environment.preferencesStore?.load() ?? AppPreferences()
        self.watchedFolder = preferences.watchedFolderPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        self.watchedFolderBookmark = preferences.watchedFolderBookmark
        self.monitoringEnabled = preferences.monitoringEnabled
        self.animateLeaves = preferences.animateLeaves
        self.notificationsEnabled = preferences.notificationsEnabled
        self.removeLocationInformation = preferences.removeLocationInformation
        self.selectedFormat = preferences.selectedFormat
        self.qualityPreset = preferences.qualityPreset
        self.webPAvailable = environment.webPInspector.isWebPEncodingAvailable
        if !webPAvailable && selectedFormat == .webP { selectedFormat = .jpeg }
        if environment.automaticallyMonitorFolder {
            launchObservation = NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)
                .sink { [weak self] _ in
                    Task { await self?.restartAutomaticMonitoring() }
                }
        }
        preferencesLoaded = true
        Task {
            await refreshHistory()
        }
    }

    var availableFormats: [OutputFormat] {
        OutputFormat.allCases.filter { format in
            format != .webP || webPAvailable
        }
    }

    var statusText: String {
        switch conversionPhase {
        case .running:
            "Converting"
        case .failed:
            "Attention Required"
        default:
            monitoringEnabled ? monitoringStatus : "Paused"
        }
    }

    func navigate(_ route: AppRoute) {
        self.route = route
    }

    func chooseFilesForConversion() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Choose images to convert"
        panel.prompt = "Choose"
        panel.allowedContentTypes = [
            UTType(importedAs: "public.heic"),
            UTType(importedAs: "public.heif"),
            UTType.image
        ]

        if panel.runModal() == .OK {
            startManualConversion(urls: panel.urls)
        }
    }

    func startManualConversion(urls: [URL]) {
        guard !urls.isEmpty else {
            conversionPhase = .failed(message: "Choose at least one image.")
            route = .conversion
            return
        }

        route = .conversion
        for url in urls {
            enqueue(url: url, expectedIdentity: nil)
        }
    }

    func chooseWatchedFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = watchedFolder
        panel.title = "Choose the folder for incoming HEIC photos"
        panel.prompt = "Watch Folder"
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        watchedFolder = folder
        watchedFolderBookmark = (try? folder.bookmarkData(options: .withSecurityScope,
            includingResourceValuesForKeys: nil, relativeTo: nil))
            ?? (try? folder.bookmarkData(options: .minimalBookmark,
                includingResourceValuesForKeys: nil, relativeTo: nil))
        savePreferences()
        Task { await restartAutomaticMonitoring() }
    }

    func restartAutomaticMonitoring() async {
        monitoringRevision += 1
        let revision = monitoringRevision
        await incomingMonitor.stop()
        guard revision == monitoringRevision else { return }
        scopedFolder?.stopAccessingSecurityScopedResource()
        scopedFolder = nil
        monitoringNeedsAccess = false
        guard monitoringEnabled else {
            monitoringStatus = "Paused"
            return
        }
        monitoringStatus = "Starting"
        if let bookmark = watchedFolderBookmark {
            var stale = false
            do {
                let resolved = try URL(resolvingBookmarkData: bookmark,
                    options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
                watchedFolder = resolved
                if resolved.startAccessingSecurityScopedResource() { scopedFolder = resolved }
                if stale {
                    watchedFolderBookmark = try resolved.bookmarkData(options: .withSecurityScope,
                        includingResourceValuesForKeys: nil, relativeTo: nil)
                    savePreferences()
                }
            } catch {
                monitoringStatus = "Folder access needed"
                monitoringNeedsAccess = true
                return
            }
        }
        do {
            try await incomingMonitor.start(folder: watchedFolder) { [weak self] url, snapshot in
                await self?.receiveAutomaticImage(url, snapshot: snapshot, revision: revision)
            } onFailure: { [weak self] url, error in
                await self?.monitoringFailed(url: url, error: error, revision: revision)
            }
            guard revision == monitoringRevision else { return }
            monitoringStatus = "Watching \(watchedFolder.lastPathComponent)"
        } catch {
            guard revision == monitoringRevision else { return }
            monitoringStatus = "Folder access needed"
            monitoringNeedsAccess = true
        }
    }

    private func receiveAutomaticImage(_ url: URL, snapshot: SourceIdentitySnapshot, revision: Int) {
        guard monitoringEnabled, revision == monitoringRevision else { return }
        enqueue(url: url, expectedIdentity: snapshot)
    }

    private func monitoringFailed(url: URL, error: ConversionError, revision: Int) {
        guard revision == monitoringRevision else { return }
        if error == .permissionDenied {
            monitoringStatus = "Folder access needed"
            monitoringNeedsAccess = true
        } else {
            conversionPhase = .failed(message: "\(url.lastPathComponent): \(error.userFacingSummary)")
        }
    }

    private func enqueue(url: URL, expectedIdentity: SourceIdentitySnapshot?) {
        let key = url.standardizedFileURL.resolvingSymlinksInPath().path
        if let expectedIdentity, completedSources[key] == expectedIdentity { return }
        guard activeSources.insert(key).inserted else { return }
        pendingConversions.append(ImageConversionRequest(
            sourceURL: url,
            targetFormat: selectedFormat,
            qualityPreset: qualityPreset,
            destination: destination,
            duplicatePolicy: duplicatePolicy,
            metadataPolicy: removeLocationInformation ? .removeLocation : .preserveCompatible,
            originalPolicy: .keep,
            expectedSourceIdentity: expectedIdentity
        ))
        if conversionTask == nil {
            conversionSessionID = UUID()
            conversionPhase = .running(filename: url.lastPathComponent)
            conversionTask = Task { await drainConversionQueue() }
        }
    }

    private func drainConversionQueue() async {
        while !pendingConversions.isEmpty {
            let request = pendingConversions.removeFirst()
            conversionPhase = .running(filename: request.sourceURL.lastPathComponent)
            do {
                let record = try await environment.converter.convert(request)
                completedSources[request.sourceURL.standardizedFileURL.resolvingSymlinksInPath().path] =
                    try? SourceIdentitySnapshot.capture(for: request.sourceURL)
                try await environment.historyStore.add(record)
                await refreshHistory()
                conversionPhase = .succeeded(record: record)
            } catch {
                let message = (error as? ConversionError)?.userFacingSummary ?? error.localizedDescription
                conversionPhase = .failed(message: message)
            }
            activeSources.remove(request.sourceURL.standardizedFileURL.resolvingSymlinksInPath().path)
        }
        conversionTask = nil
    }

    private func savePreferences() {
        guard preferencesLoaded else { return }
        environment.preferencesStore?.save(AppPreferences(
            monitoringEnabled: monitoringEnabled, animateLeaves: animateLeaves,
            notificationsEnabled: notificationsEnabled, removeLocationInformation: removeLocationInformation,
            selectedFormat: selectedFormat, qualityPreset: qualityPreset,
            watchedFolderPath: watchedFolder.path, watchedFolderBookmark: watchedFolderBookmark
        ))
    }

    func revealLatestOutputInFinder() {
        guard let latestPath = recentConversions.first(where: { $0.status == .completed })?.outputPathSnapshot else {
            return
        }
        let url = URL(fileURLWithPath: latestPath)
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }

    func refreshHistory() async {
        do {
            recentConversions = try await environment.historyStore.records()
        } catch {
            recentConversions = []
        }
    }

    func clearHistory() {
        Task {
            try? await environment.historyStore.clear()
            await refreshHistory()
        }
    }
}
