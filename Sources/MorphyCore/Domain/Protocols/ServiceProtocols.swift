import Foundation

public protocol ImageConverting: Sendable {
    func convert(_ request: ImageConversionRequest) async throws -> ConversionRecord
}

public protocol HistoryStoring: Sendable {
    func records() async throws -> [ConversionRecord]
    func add(_ record: ConversionRecord) async throws
    func clear() async throws
}

public protocol FileStabilityChecking: Sendable {
    func waitUntilStable(_ url: URL) async throws -> SourceIdentitySnapshot
}

public protocol CloudMaterializationChecking: Sendable {
    func availabilityState(for url: URL) async throws -> FileAvailabilityState
    func requestMaterialization(of url: URL) async throws
    func waitUntilMaterialized(_ url: URL, timeout: Duration) async throws
}

public protocol WebPCapabilityInspecting: Sendable {
    var isWebPEncodingAvailable: Bool { get }
}
