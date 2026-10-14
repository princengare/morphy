import Foundation
@preconcurrency import ImageIO

public struct ValidatedImageOutput: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let fileSize: Int64
}

public struct ConversionValidationService: Sendable {
    public init() {}

    public func validateImage(at url: URL) throws -> ValidatedImageOutput {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ConversionError.outputValidationFailure("Output file does not exist.")
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard fileSize > 0 else {
            throw ConversionError.outputValidationFailure("Output file is empty.")
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ConversionError.outputValidationFailure("Image I/O could not open output.")
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw ConversionError.outputValidationFailure("Image properties were unavailable.")
        }

        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0

        guard width > 0, height > 0 else {
            throw ConversionError.outputValidationFailure("Image dimensions were invalid.")
        }

        return ValidatedImageOutput(width: width, height: height, fileSize: fileSize)
    }
}
