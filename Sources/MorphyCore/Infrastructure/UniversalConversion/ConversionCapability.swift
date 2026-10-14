import Foundation

public enum QualityClass: String, Codable, Sendable {
    case lossless
    case visuallyLossless
    case highQuality
    case featureReducing
    case unsupported
}

public enum ConversionFeature: String, Codable, Sendable {
    case imageQuality
    case transparency
    case animation
    case metadata
    case colorProfile
    case livePhotoMotion
    case locationMetadata
}

public struct ConversionCompatibility: Codable, Equatable, Sendable {
    public let sourceType: String
    public let destinationType: String
    public let qualityClass: QualityClass
    public let preservedFeatures: [ConversionFeature]
    public let changedFeatures: [ConversionFeature]
    public let removedFeatures: [ConversionFeature]
    public let userFacingSummary: String

    public init(
        sourceType: String,
        destinationType: String,
        qualityClass: QualityClass,
        preservedFeatures: [ConversionFeature],
        changedFeatures: [ConversionFeature],
        removedFeatures: [ConversionFeature],
        userFacingSummary: String
    ) {
        self.sourceType = sourceType
        self.destinationType = destinationType
        self.qualityClass = qualityClass
        self.preservedFeatures = preservedFeatures
        self.changedFeatures = changedFeatures
        self.removedFeatures = removedFeatures
        self.userFacingSummary = userFacingSummary
    }
}
