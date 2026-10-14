import Foundation
import ImageIO
import Testing
@testable import MorphyCore

@Suite("Incoming HEIC files")
struct IncomingImageTests {
    @Test("New arrivals are detected once; existing photos and outputs are ignored")
    func arrivals() async throws {
        let folder = try ImageTestFolder()
        let data = try heicFixture()
        try data.write(to: folder.url.appendingPathComponent("existing.heic"))
        let recorder = ArrivalRecorder()
        let monitor = IncomingImageMonitor(stabilityChecker: fastStabilityChecker())
        try await monitor.start(folder: folder.url) { url, _ in
            await recorder.add(url)
        } onFailure: { _, error in await recorder.fail(error) }

        try data.write(to: folder.url.appendingPathComponent("first.HEIC"))
        try data.write(to: folder.url.appendingPathComponent("second.heif"))
        try await waitFor { await recorder.count == 2 }
        try Data("converted output".utf8).write(to: folder.url.appendingPathComponent("first.jpg"))
        try FileManager.default.setAttributes([.modificationDate: Date()],
            ofItemAtPath: folder.url.appendingPathComponent("first.HEIC").path)
        try await Task.sleep(for: .milliseconds(200))
        #expect(await recorder.names == Set(["first.HEIC", "second.heif"]))
        #expect(await recorder.count == 2)
        #expect(await recorder.failures.isEmpty)
        await monitor.stop()
    }

    @Test("A partial transfer is not delivered until the complete image arrives")
    func partialTransfer() async throws {
        let folder = try ImageTestFolder()
        let data = try heicFixture()
        let recorder = ArrivalRecorder()
        let monitor = IncomingImageMonitor(stabilityChecker: fastStabilityChecker())
        try await monitor.start(folder: folder.url) { url, _ in
            await recorder.add(url)
        } onFailure: { _, error in await recorder.fail(error) }
        let incoming = folder.url.appendingPathComponent("incoming.heic")
        try data.prefix(64).write(to: incoming)
        try await Task.sleep(for: .milliseconds(250))
        #expect(await recorder.count == 0)
        let handle = try FileHandle(forWritingTo: incoming)
        try handle.seekToEnd()
        try handle.write(contentsOf: data.dropFirst(64))
        try handle.close()
        try await waitFor { await recorder.count == 1 }
        #expect(await recorder.failures.isEmpty)
        await monitor.stop()
    }

    @Test("Atomic renames are detected and stopping cancels monitoring")
    func renameAndPause() async throws {
        let folder = try ImageTestFolder()
        let recorder = ArrivalRecorder()
        let monitor = IncomingImageMonitor(stabilityChecker: fastStabilityChecker())
        try await monitor.start(folder: folder.url) { url, _ in
            await recorder.add(url)
        } onFailure: { _, error in await recorder.fail(error) }
        let partial = folder.url.appendingPathComponent(".incoming.partial")
        try heicFixture().write(to: partial)
        try FileManager.default.moveItem(at: partial, to: folder.url.appendingPathComponent("renamed.heic"))
        try await waitFor { await recorder.count == 1 }
        await monitor.stop()
        try heicFixture().write(to: folder.url.appendingPathComponent("paused.heic"))
        try await Task.sleep(for: .milliseconds(200))
        #expect(await recorder.count == 1)
    }
}

@Suite("Real image conversion")
struct ImageConversionTests {
    @Test("HEIC converts to each format without changing the original", arguments: OutputFormat.allCases)
    func allFormats(_ format: OutputFormat) async throws {
        let folder = try ImageTestFolder()
        let source = folder.url.appendingPathComponent("photo.heic")
        let data = try heicFixture()
        try data.write(to: source)
        let record = try await ImageConversionService().convert(ImageConversionRequest(sourceURL: source, targetFormat: format))
        let output = try #require(record.outputPathSnapshot)
        let decoder = try #require(CGImageSourceCreateWithURL(URL(fileURLWithPath: output) as CFURL, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(decoder, 0, nil))
        #expect(decoded.width == 64)
        #expect(decoded.height == 48)
        #expect(try Data(contentsOf: source) == data)
        #expect(record.status == .completed)
    }

    @Test("A source changed after discovery is rejected before writing output")
    func changedIdentity() async throws {
        let folder = try ImageTestFolder()
        let source = folder.url.appendingPathComponent("photo.heic")
        try heicFixture().write(to: source)
        let expected = try SourceIdentitySnapshot.capture(for: source)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 123)], ofItemAtPath: source.path)
        await #expect(throws: ConversionError.sourceUnstable) {
            try await ImageConversionService().convert(ImageConversionRequest(sourceURL: source, targetFormat: .jpeg,
                expectedSourceIdentity: expected))
        }
        #expect(!FileManager.default.fileExists(atPath: folder.url.appendingPathComponent("photo.jpg").path))
    }

    @Test("WebP bakes in orientation instead of losing the rotation")
    func webPOrientation() async throws {
        let folder = try ImageTestFolder()
        let source = folder.url.appendingPathComponent("rotated.heic")
        try heicFixture(orientation: 6).write(to: source)
        let record = try await ImageConversionService().convert(ImageConversionRequest(sourceURL: source, targetFormat: .webP))
        #expect(record.width == 48)
        #expect(record.height == 64)
    }
}

private actor ArrivalRecorder {
    private var arrivals: [URL] = []
    private(set) var failures: [ConversionError] = []
    var count: Int { arrivals.count }
    var names: Set<String> { Set(arrivals.map(\.lastPathComponent)) }
    func add(_ url: URL) { arrivals.append(url) }
    func fail(_ error: ConversionError) { failures.append(error) }
}

private func fastStabilityChecker() -> FileStabilityChecker {
    FileStabilityChecker(policy: FileStabilityPolicy(initialDelay: .milliseconds(20),
        pollInterval: .milliseconds(20), requiredStableObservations: 3, maximumWait: .seconds(3)))
}

private func waitFor(_ condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(4))
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(20))
    }
    throw TestImageError.timeout
}

private func heicFixture(orientation: Int = 1) throws -> Data {
    let context = try #require(CGContext(data: nil, width: 64, height: 48, bitsPerComponent: 8,
        bytesPerRow: 256, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    context.setFillColor(CGColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
    let data = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(data, "public.heic" as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try #require(context.makeImage()),
        [kCGImagePropertyOrientation: orientation] as CFDictionary)
    #expect(CGImageDestinationFinalize(destination))
    return data as Data
}

private enum TestImageError: Error { case timeout }

private final class ImageTestFolder {
    let url: URL
    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("MorphyImages-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: url) }
}
