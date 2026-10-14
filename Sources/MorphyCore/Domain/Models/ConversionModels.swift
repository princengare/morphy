import Foundation

public enum OutputFormat: String, CaseIterable, Codable, Identifiable, Sendable {
    case jpeg
    case png
    case webP = "webp"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .jpeg: "JPEG"
        case .png: "PNG"
        case .webP: "WebP"
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .webP: "webp"
        }
    }

    public var utiIdentifier: String {
        switch self {
        case .jpeg: "public.jpeg"
        case .png: "public.png"
        case .webP: "org.webmproject.webp"
        }
    }

    public var supportsLossyQuality: Bool {
        self != .png
    }
}

public enum QualityPreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case smallerFile
    case recommended
    case bestQuality

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .smallerFile: "Smaller File"
        case .recommended: "Recommended"
        case .bestQuality: "Best Quality"
        }
    }

    public func encoderQuality(for format: OutputFormat) -> Double? {
        switch (self, format) {
        case (_, .png):
            nil
        case (.smallerFile, .jpeg):
            0.76
        case (.recommended, .jpeg):
            0.92
        case (.bestQuality, .jpeg):
            0.98
        case (.smallerFile, .webP):
            0.70
        case (.recommended, .webP):
            0.85
        case (.bestQuality, .webP):
            0.95
        }
    }
}

public enum OriginalFilePolicy: String, CaseIterable, Codable, Identifiable, Sendable {
    case keep
    case archive
    case moveToTrash
    case ask

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .keep: "Keep Original"
        case .archive: "Move Original Aside"
        case .moveToTrash: "Move Original to Trash"
        case .ask: "Ask Each Time"
        }
    }
}

public enum DuplicatePolicy: String, CaseIterable, Codable, Identifiable, Sendable {
    case addNumber
    case replaceExisting
    case skip
    case ask
    case appendTimestamp

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .addNumber: "Add a Number"
        case .replaceExisting: "Replace Existing"
        case .skip: "Skip"
        case .ask: "Ask"
        case .appendTimestamp: "Add Date and Time"
        }
    }
}

public enum DestinationStrategy: Codable, Equatable, Sendable {
    case sameFolder
    case folder(URL)
}

public enum MetadataPolicy: String, CaseIterable, Codable, Identifiable, Sendable {
    case preserveCompatible
    case cameraAndDateOnly
    case removeLocation
    case removeAll

    public var id: String { rawValue }
}

public enum ConversionStatus: String, Codable, Sendable {
    case discovered
    case waitingForStability
    case ready
    case queued
    case decoding
    case encoding
    case validating
    case writing
    case handlingOriginal
    case recordingHistory
    case completed
    case failed
    case cancelled
}

public struct SourceIdentitySnapshot: Codable, Equatable, Sendable {
    public let canonicalPath: String
    public let fileResourceIdentifier: String?
    public let volumeIdentifier: String?
    public let size: Int64
    public let modificationDate: Date?
    public let creationDate: Date?
    public let sourceUTI: String?

    public init(
        canonicalPath: String,
        fileResourceIdentifier: String?,
        volumeIdentifier: String?,
        size: Int64,
        modificationDate: Date?,
        creationDate: Date?,
        sourceUTI: String?
    ) {
        self.canonicalPath = canonicalPath
        self.fileResourceIdentifier = fileResourceIdentifier
        self.volumeIdentifier = volumeIdentifier
        self.size = size
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.sourceUTI = sourceUTI
    }

    public static func capture(for url: URL, sourceUTI: String? = nil) throws -> SourceIdentitySnapshot {
        let standardizedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        let values = try? standardizedURL.resourceValues(forKeys: [
            .fileResourceIdentifierKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .typeIdentifierKey
        ])
        let attributes = try FileManager.default.attributesOfItem(atPath: standardizedURL.path)
        let size = (values?.fileSize).map(Int64.init)
            ?? (attributes[.size] as? NSNumber)?.int64Value
            ?? 0
        return SourceIdentitySnapshot(
            canonicalPath: standardizedURL.path,
            fileResourceIdentifier: values?.fileResourceIdentifier.map { String(describing: $0) },
            volumeIdentifier: nil,
            size: size,
            modificationDate: values?.contentModificationDate ?? attributes[.modificationDate] as? Date,
            creationDate: values?.creationDate ?? attributes[.creationDate] as? Date,
            sourceUTI: sourceUTI ?? values?.typeIdentifier
        )
    }
}

public struct ImageConversionRequest: Sendable {
    public let sourceURL: URL
    public let targetFormat: OutputFormat
    public let qualityPreset: QualityPreset
    public let destination: DestinationStrategy
    public let duplicatePolicy: DuplicatePolicy
    public let metadataPolicy: MetadataPolicy
    public let preserveColorProfile: Bool
    public let preserveCreationDate: Bool
    public let originalPolicy: OriginalFilePolicy
    public let expectedSourceIdentity: SourceIdentitySnapshot?

    public init(
        sourceURL: URL,
        targetFormat: OutputFormat,
        qualityPreset: QualityPreset = .recommended,
        destination: DestinationStrategy = .sameFolder,
        duplicatePolicy: DuplicatePolicy = .addNumber,
        metadataPolicy: MetadataPolicy = .preserveCompatible,
        preserveColorProfile: Bool = true,
        preserveCreationDate: Bool = true,
        originalPolicy: OriginalFilePolicy = .keep,
        expectedSourceIdentity: SourceIdentitySnapshot? = nil
    ) {
        self.sourceURL = sourceURL
        self.targetFormat = targetFormat
        self.qualityPreset = qualityPreset
        self.destination = destination
        self.duplicatePolicy = duplicatePolicy
        self.metadataPolicy = metadataPolicy
        self.preserveColorProfile = preserveColorProfile
        self.preserveCreationDate = preserveCreationDate
        self.originalPolicy = originalPolicy
        self.expectedSourceIdentity = expectedSourceIdentity
    }
}

public struct ConversionRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sourceFilename: String
    public let sourcePathSnapshot: String
    public let outputFilename: String?
    public let outputPathSnapshot: String?
    public let sourceFormat: String
    public let outputFormat: OutputFormat
    public let sourceFileSize: Int64
    public let outputFileSize: Int64?
    public let width: Int?
    public let height: Int?
    public let qualityPreset: QualityPreset
    public let startedAt: Date
    public let completedAt: Date?
    public let duration: TimeInterval?
    public let originalPolicy: OriginalFilePolicy
    public let status: ConversionStatus
    public let errorCode: String?
    public let errorMessage: String?
    public let metadataPolicy: MetadataPolicy
    public let hdrNote: String?
    public let applicationVersion: String

    public init(
        id: UUID = UUID(),
        sourceFilename: String,
        sourcePathSnapshot: String,
        outputFilename: String?,
        outputPathSnapshot: String?,
        sourceFormat: String,
        outputFormat: OutputFormat,
        sourceFileSize: Int64,
        outputFileSize: Int64?,
        width: Int?,
        height: Int?,
        qualityPreset: QualityPreset,
        startedAt: Date,
        completedAt: Date?,
        duration: TimeInterval?,
        originalPolicy: OriginalFilePolicy,
        status: ConversionStatus,
        errorCode: String?,
        errorMessage: String?,
        metadataPolicy: MetadataPolicy,
        hdrNote: String? = nil,
        applicationVersion: String = "0.2.2"
    ) {
        self.id = id
        self.sourceFilename = sourceFilename
        self.sourcePathSnapshot = sourcePathSnapshot
        self.outputFilename = outputFilename
        self.outputPathSnapshot = outputPathSnapshot
        self.sourceFormat = sourceFormat
        self.outputFormat = outputFormat
        self.sourceFileSize = sourceFileSize
        self.outputFileSize = outputFileSize
        self.width = width
        self.height = height
        self.qualityPreset = qualityPreset
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.duration = duration
        self.originalPolicy = originalPolicy
        self.status = status
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.metadataPolicy = metadataPolicy
        self.hdrNote = hdrNote
        self.applicationVersion = applicationVersion
    }
}

public struct WatchedFolder: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var displayURL: URL
    public var isEnabled: Bool
    public var includeSubfolders: Bool
    public var presetID: UUID?

    public init(id: UUID = UUID(), displayURL: URL, isEnabled: Bool = true, includeSubfolders: Bool = false, presetID: UUID? = nil) {
        self.id = id
        self.displayURL = displayURL
        self.isEnabled = isEnabled
        self.includeSubfolders = includeSubfolders
        self.presetID = presetID
    }
}

public struct ConversionPreset: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var outputFormat: OutputFormat
    public var qualityPreset: QualityPreset
    public var originalPolicy: OriginalFilePolicy
    public var metadataPolicy: MetadataPolicy

    public init(
        id: UUID = UUID(),
        name: String,
        outputFormat: OutputFormat,
        qualityPreset: QualityPreset = .recommended,
        originalPolicy: OriginalFilePolicy = .keep,
        metadataPolicy: MetadataPolicy = .preserveCompatible
    ) {
        self.id = id
        self.name = name
        self.outputFormat = outputFormat
        self.qualityPreset = qualityPreset
        self.originalPolicy = originalPolicy
        self.metadataPolicy = metadataPolicy
    }

    public static let photoCompatibility = ConversionPreset(
        name: "Photo Compatibility",
        outputFormat: .jpeg,
        qualityPreset: .recommended,
        originalPolicy: .keep,
        metadataPolicy: .preserveCompatible
    )
}

public struct ConversionRule: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var watchedFolderID: UUID?
    public var presetID: UUID
    public var isEnabled: Bool

    public init(id: UUID = UUID(), name: String, watchedFolderID: UUID? = nil, presetID: UUID, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.watchedFolderID = watchedFolderID
        self.presetID = presetID
        self.isEnabled = isEnabled
    }
}

public struct ConversionJob: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sourceURL: URL
    public let detectedAt: Date
    public let sourceIdentity: SourceIdentitySnapshot?
    public let targetFormat: OutputFormat
    public let qualityPreset: QualityPreset
    public let destination: DestinationStrategy
    public let originalPolicy: OriginalFilePolicy
    public let duplicatePolicy: DuplicatePolicy
    public var status: ConversionStatus

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        detectedAt: Date = Date(),
        sourceIdentity: SourceIdentitySnapshot? = nil,
        targetFormat: OutputFormat,
        qualityPreset: QualityPreset = .recommended,
        destination: DestinationStrategy = .sameFolder,
        originalPolicy: OriginalFilePolicy = .keep,
        duplicatePolicy: DuplicatePolicy = .addNumber,
        status: ConversionStatus = .discovered
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.detectedAt = detectedAt
        self.sourceIdentity = sourceIdentity
        self.targetFormat = targetFormat
        self.qualityPreset = qualityPreset
        self.destination = destination
        self.originalPolicy = originalPolicy
        self.duplicatePolicy = duplicatePolicy
        self.status = status
    }
}
