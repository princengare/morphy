import Foundation

public enum ConversionError: Error, Equatable, LocalizedError, Sendable {
    case sourceNotFound
    case sourceNotReadable
    case sourceUnstable
    case unsupportedSourceFormat
    case unsupportedOutputFormat(String)
    case decoderFailure(String?)
    case encoderFailure(String?)
    case metadataFailure(String?)
    case invalidDestination
    case permissionDenied
    case bookmarkStale
    case duplicateConflict
    case insufficientDiskSpace
    case outputValidationFailure(String?)
    case atomicMoveFailure(String?)
    case archiveFailure(String?)
    case trashFailure(String?)
    case historyWriteFailure(String?)
    case cloudMaterializationTimeout
    case cloudMaterializationFailed(underlyingDescription: String?)
    case providerUnavailable
    case cancelled
    case unknown(String?)

    public var errorDescription: String? {
        userFacingSummary
    }

    public var code: String {
        switch self {
        case .sourceNotFound: "sourceNotFound"
        case .sourceNotReadable: "sourceNotReadable"
        case .sourceUnstable: "sourceUnstable"
        case .unsupportedSourceFormat: "unsupportedSourceFormat"
        case .unsupportedOutputFormat: "unsupportedOutputFormat"
        case .decoderFailure: "decoderFailure"
        case .encoderFailure: "encoderFailure"
        case .metadataFailure: "metadataFailure"
        case .invalidDestination: "invalidDestination"
        case .permissionDenied: "permissionDenied"
        case .bookmarkStale: "bookmarkStale"
        case .duplicateConflict: "duplicateConflict"
        case .insufficientDiskSpace: "insufficientDiskSpace"
        case .outputValidationFailure: "outputValidationFailure"
        case .atomicMoveFailure: "atomicMoveFailure"
        case .archiveFailure: "archiveFailure"
        case .trashFailure: "trashFailure"
        case .historyWriteFailure: "historyWriteFailure"
        case .cloudMaterializationTimeout: "cloudMaterializationTimeout"
        case .cloudMaterializationFailed: "cloudMaterializationFailed"
        case .providerUnavailable: "providerUnavailable"
        case .cancelled: "cancelled"
        case .unknown: "unknown"
        }
    }

    public var userFacingSummary: String {
        switch self {
        case .sourceNotFound:
            "morphy could not find the original file."
        case .sourceNotReadable:
            "morphy could not read this file."
        case .sourceUnstable:
            "This file is still changing. Try again when the transfer finishes."
        case .unsupportedSourceFormat:
            "morphy cannot convert this kind of file yet."
        case .unsupportedOutputFormat(let format):
            "This Mac cannot create \(format) files with the current morphy build."
        case .decoderFailure:
            "morphy could not open this image."
        case .encoderFailure:
            "morphy could not create the converted image."
        case .metadataFailure:
            "morphy could not copy some image details."
        case .invalidDestination:
            "morphy could not use the selected save location."
        case .permissionDenied:
            "morphy does not have permission to use this folder."
        case .bookmarkStale:
            "morphy needs folder access to be refreshed."
        case .duplicateConflict:
            "A file with that name already exists."
        case .insufficientDiskSpace:
            "There is not enough free space to safely finish this conversion."
        case .outputValidationFailure:
            "morphy created a file, but it did not pass the safety check."
        case .atomicMoveFailure:
            "morphy could not move the finished file into place."
        case .archiveFailure:
            "morphy could not move the original aside."
        case .trashFailure:
            "morphy could not move the original to Trash."
        case .historyWriteFailure:
            "morphy converted the file but could not save the history record."
        case .cloudMaterializationTimeout:
            "This file is still downloading from iCloud or its file provider."
        case .cloudMaterializationFailed:
            "morphy could not download this file from its storage provider."
        case .providerUnavailable:
            "The storage provider for this file is currently unavailable."
        case .cancelled:
            "The conversion was cancelled."
        case .unknown:
            "Something went wrong."
        }
    }

    public var technicalDetails: String? {
        switch self {
        case .unsupportedOutputFormat(let value):
            value
        case .decoderFailure(let value),
             .encoderFailure(let value),
             .metadataFailure(let value),
             .outputValidationFailure(let value),
             .atomicMoveFailure(let value),
             .archiveFailure(let value),
             .trashFailure(let value),
             .historyWriteFailure(let value),
             .cloudMaterializationFailed(let value),
             .unknown(let value):
            value
        default:
            nil
        }
    }
}

public enum FileAvailabilityState: Equatable, Sendable {
    case localAndCurrent
    case localButNotCurrent
    case notDownloaded
    case downloading(progress: Double?)
    case downloadFailed(message: String?)
    case notCloudManaged
    case unavailableUnknown
}

public struct CompanionAsset: Codable, Equatable, Sendable {
    public let url: URL
    public let assetIdentifier: String?

    public init(url: URL, assetIdentifier: String?) {
        self.url = url
        self.assetIdentifier = assetIdentifier
    }
}

public struct CompanionAssetGroup: Codable, Equatable, Sendable {
    public let stillImage: URL
    public let companions: [CompanionAsset]
    public let identifiersMatched: Bool

    public init(stillImage: URL, companions: [CompanionAsset], identifiersMatched: Bool) {
        self.stillImage = stillImage
        self.companions = companions
        self.identifiersMatched = identifiersMatched
    }
}

public enum WatchedFolderConflict: Equatable, Sendable {
    case exactSameResource
    case sameCanonicalPath
    case existingRecursiveParent
    case newRecursiveParent
    case mutuallyOverlappingRules
    case unresolvedIdentity
}

public enum FolderAccessState: Equatable, Sendable {
    case availableReadWrite
    case availableReadOnly
    case bookmarkStale
    case permissionDenied
    case permissionRevokedExternally
    case folderMissing
    case volumeUnavailable
    case providerUnavailable
    case unknownFailure
}
