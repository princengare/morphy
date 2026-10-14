import CWebP

public struct WebPCapabilityInspector: WebPCapabilityInspecting {
    public init() {}

    public var isWebPEncodingAvailable: Bool {
        WebPGetEncoderVersion() > 0
    }
}
