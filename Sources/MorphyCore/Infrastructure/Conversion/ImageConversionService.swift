import Foundation
@preconcurrency import ImageIO

public final class ImageConversionService: ImageConverting, @unchecked Sendable {
    private let duplicateNameResolver: DuplicateNameResolver
    private let validationService: ConversionValidationService
    private let capacityService: DiskCapacityService
    private let webPInspector: WebPCapabilityInspecting

    public init(
        duplicateNameResolver: DuplicateNameResolver = DuplicateNameResolver(),
        validationService: ConversionValidationService = ConversionValidationService(),
        capacityService: DiskCapacityService = DiskCapacityService(),
        webPInspector: WebPCapabilityInspecting = WebPCapabilityInspector()
    ) {
        self.duplicateNameResolver = duplicateNameResolver
        self.validationService = validationService
        self.capacityService = capacityService
        self.webPInspector = webPInspector
    }

    public func convert(_ request: ImageConversionRequest) async throws -> ConversionRecord {
        try await Task.detached(priority: .userInitiated) {
            try self.convertSynchronously(request)
        }.value
    }

    private func convertSynchronously(_ request: ImageConversionRequest) throws -> ConversionRecord {
        let startedAt = Date()
        let sourceURL = request.sourceURL
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ConversionError.sourceNotFound
        }
        let sourceIdentity = try SourceIdentitySnapshot.capture(for: sourceURL)
        if let expected = request.expectedSourceIdentity {
            guard isSameSource(sourceIdentity, expected) else { throw ConversionError.sourceUnstable }
        }

        guard request.originalPolicy == .keep else {
            throw ConversionError.archiveFailure("Only Keep Original is implemented in this build.")
        }

        guard request.targetFormat != .webP || webPInspector.isWebPEncodingAvailable else {
            throw ConversionError.unsupportedOutputFormat(request.targetFormat.displayName)
        }

        let sourceAttributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let sourceSize = (sourceAttributes[.size] as? NSNumber)?.int64Value ?? 0

        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ConversionError.decoderFailure("Could not create an image source.")
        }

        let sourceType = CGImageSourceGetType(imageSource) as String? ?? sourceURL.pathExtension.uppercased()
        guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, [
            kCGImageSourceShouldCache: false
        ] as CFDictionary) else {
            throw ConversionError.decoderFailure("Could not decode the first image frame.")
        }

        let pixelCount = image.width * image.height
        let destinationFolder: URL
        switch request.destination {
        case .sameFolder:
            destinationFolder = sourceURL.deletingLastPathComponent()
        case .folder(let folder):
            destinationFolder = folder
        }

        guard FileManager.default.fileExists(atPath: destinationFolder.path) else {
            throw ConversionError.invalidDestination
        }

        guard capacityService.hasRoomForSingleOutput(near: destinationFolder, sourceSize: sourceSize, pixelCount: pixelCount) else {
            throw ConversionError.insufficientDiskSpace
        }

        let proposedURL = destinationFolder
            .appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(request.targetFormat.fileExtension)
        let finalURL = try duplicateNameResolver.resolvedURL(for: proposedURL, policy: request.duplicatePolicy)
        let temporaryURL = destinationFolder
            .appendingPathComponent(".morphy-\(UUID().uuidString)")
            .appendingPathExtension(request.targetFormat.fileExtension)

        do {
            try encode(
                image: image,
                imageSource: imageSource,
                to: temporaryURL,
                request: request
            )
            let validation = try validationService.validateImage(at: temporaryURL)
            let currentIdentity = try SourceIdentitySnapshot.capture(for: sourceURL)
            guard isSameSource(sourceIdentity, currentIdentity) else { throw ConversionError.sourceUnstable }

            if request.duplicatePolicy == .replaceExisting, FileManager.default.fileExists(atPath: finalURL.path) {
                _ = try FileManager.default.replaceItemAt(finalURL, withItemAt: temporaryURL)
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: finalURL)
            }

            if request.preserveCreationDate, let creationDate = sourceAttributes[.creationDate] as? Date {
                try? FileManager.default.setAttributes([.creationDate: creationDate], ofItemAtPath: finalURL.path)
            }

            let completedAt = Date()
            return ConversionRecord(
                sourceFilename: sourceURL.lastPathComponent,
                sourcePathSnapshot: sourceURL.path,
                outputFilename: finalURL.lastPathComponent,
                outputPathSnapshot: finalURL.path,
                sourceFormat: sourceType,
                outputFormat: request.targetFormat,
                sourceFileSize: sourceSize,
                outputFileSize: validation.fileSize,
                width: validation.width,
                height: validation.height,
                qualityPreset: request.qualityPreset,
                startedAt: startedAt,
                completedAt: completedAt,
                duration: completedAt.timeIntervalSince(startedAt),
                originalPolicy: request.originalPolicy,
                status: .completed,
                errorCode: nil,
                errorMessage: nil,
                metadataPolicy: request.metadataPolicy
            )
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw map(error)
        }
    }

    private func encode(
        image: CGImage,
        imageSource: CGImageSource,
        to outputURL: URL,
        request: ImageConversionRequest
    ) throws {
        if request.targetFormat == .webP {
            try WebPEncoder().encode(image: image, source: imageSource, to: outputURL, request: request)
            return
        }
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            request.targetFormat.utiIdentifier as CFString,
            1,
            nil
        ) else {
            throw ConversionError.unsupportedOutputFormat(request.targetFormat.displayName)
        }

        let options = NSMutableDictionary()
        if request.metadataPolicy != .removeAll,
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
            for (key, value) in properties {
                if request.metadataPolicy == .removeLocation, key == kCGImagePropertyGPSDictionary {
                    continue
                }
                options[key] = value
            }
        }

        if let quality = request.qualityPreset.encoderQuality(for: request.targetFormat) {
            options[kCGImageDestinationLossyCompressionQuality] = quality
        }

        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else {
            throw ConversionError.encoderFailure("Image I/O could not finalize \(request.targetFormat.displayName).")
        }
    }

    private func map(_ error: Error) -> Error {
        if let conversionError = error as? ConversionError {
            return conversionError
        }
        return ConversionError.unknown(error.localizedDescription)
    }

    private func isSameSource(_ lhs: SourceIdentitySnapshot, _ rhs: SourceIdentitySnapshot) -> Bool {
        lhs.canonicalPath == rhs.canonicalPath
            && lhs.fileResourceIdentifier == rhs.fileResourceIdentifier
            && lhs.size == rhs.size
            && lhs.modificationDate == rhs.modificationDate
    }
}
