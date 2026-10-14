import Foundation
import MorphyCore
import Testing
@testable import MorphyApp

@Suite("Conversion screen timing")
@MainActor
struct ConversionPresentationTests {
    @Test("Fast success stays animated until the current three-second intro finishes")
    func fastSuccess() {
        let sessionID = UUID()
        let record = makePresentationRecord(for: URL(fileURLWithPath: "/tmp/incoming.heic"))
        #expect(ConversionPresentation.minimumAnimationDuration == .seconds(3))
        #expect(ConversionPresentation.phase(for: .succeeded(record: record), sessionID: sessionID,
            completedIntroSessionID: nil) == .running(filename: record.sourceFilename))
        #expect(ConversionPresentation.phase(for: .succeeded(record: record), sessionID: sessionID,
            completedIntroSessionID: sessionID) == .succeeded(record: record))
    }

    @Test("A slow conversion keeps running after the intro; failures are not hidden")
    func slowConversionAndFailure() {
        let sessionID = UUID()
        let running = ConversionPhase.running(filename: "incoming.heic")
        #expect(ConversionPresentation.phase(for: running, sessionID: sessionID,
            completedIntroSessionID: sessionID) == running)
        let failed = ConversionPhase.failed(message: "Could not read the image.")
        #expect(ConversionPresentation.phase(for: failed, sessionID: sessionID,
            completedIntroSessionID: nil) == failed)
        #expect(ConversionPresentation.phase(for: .idle, sessionID: sessionID,
            completedIntroSessionID: nil) == .idle)
    }

    @Test("An old intro completion cannot reveal a new conversion's success")
    func staleIntro() {
        let record = makePresentationRecord(for: URL(fileURLWithPath: "/tmp/new-photo.heic"))
        #expect(ConversionPresentation.phase(for: .succeeded(record: record), sessionID: UUID(),
            completedIntroSessionID: UUID()) == .running(filename: record.sourceFilename))
    }

    @Test("A batch shares one intro session without delaying the conversion queue")
    func batchSessions() async throws {
        let state = AppState(environment: AppEnvironment(converter: FastPresentationConverter(),
            historyStore: InMemoryHistoryStore(), webPInspector: WebPCapabilityInspector()))
        let firstSession = state.conversionSessionID
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let clock = ContinuousClock()
        let started = clock.now
        state.startManualConversion(urls: [folder.appendingPathComponent("one.heic"),
            folder.appendingPathComponent("two.heic")])
        let batchSession = state.conversionSessionID
        #expect(batchSession != firstSession)
        #expect(state.conversionPhase == .running(filename: "one.heic"))
        try await waitForSuccess(state, count: 2)
        #expect(state.conversionSessionID == batchSession)
        #expect(started.duration(to: clock.now) < ConversionPresentation.minimumAnimationDuration)

        state.startManualConversion(urls: [folder.appendingPathComponent("three.heic")])
        #expect(state.conversionSessionID != batchSession)
        try await waitForSuccess(state, count: 3)
        #expect(ConversionPresentation.phase(for: state.conversionPhase, sessionID: state.conversionSessionID,
            completedIntroSessionID: batchSession) == .running(filename: "three.heic"))
    }

    private func waitForSuccess(_ state: AppState, count: Int) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while ContinuousClock.now < deadline {
            if state.recentConversions.count == count, case .succeeded = state.conversionPhase { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw PresentationTestError.timeout
    }
}

private actor FastPresentationConverter: ImageConverting {
    func convert(_ request: ImageConversionRequest) async throws -> ConversionRecord {
        try await Task.sleep(for: .milliseconds(20))
        return makePresentationRecord(for: request.sourceURL)
    }
}

private func makePresentationRecord(for source: URL) -> ConversionRecord {
    let date = Date()
    return ConversionRecord(sourceFilename: source.lastPathComponent, sourcePathSnapshot: source.path,
        outputFilename: source.deletingPathExtension().appendingPathExtension("jpg").lastPathComponent,
        outputPathSnapshot: nil, sourceFormat: "HEIC", outputFormat: .jpeg, sourceFileSize: 100,
        outputFileSize: 80, width: 32, height: 32, qualityPreset: .recommended, startedAt: date,
        completedAt: date, duration: 0.02, originalPolicy: .keep, status: .completed,
        errorCode: nil, errorMessage: nil, metadataPolicy: .preserveCompatible)
}

private enum PresentationTestError: Error { case timeout }
