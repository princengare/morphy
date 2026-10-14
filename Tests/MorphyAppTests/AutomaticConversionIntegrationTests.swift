import AppKit
import Foundation
import ImageIO
import MorphyCore
import Testing
@testable import MorphyApp

@Suite("Automatic conversion settings")
@MainActor
struct AutomaticConversionIntegrationTests {
    @Test("Arrivals use the selected format, settings survive reopening, and pause works")
    func selectedFormatsAndPause() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MorphyAppTests-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let suite = "MorphyTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferencesStore(defaults: defaults)
        preferences.save(AppPreferences(watchedFolderPath: folder.path))
        let environment = AppEnvironment(converter: ImageConversionService(), historyStore: InMemoryHistoryStore(),
            webPInspector: WebPCapabilityInspector(), preferencesStore: preferences, automaticallyMonitorFolder: true)
        let state = AppState(environment: environment)
        NotificationCenter.default.post(name: NSApplication.didFinishLaunchingNotification, object: nil)
        try await waitUntil(state: state) { state.monitoringStatus.hasPrefix("Watching ") }
        #expect(state.monitoringNeedsAccess == false)
        let fixture = try makeHEIC()
        for (index, format) in OutputFormat.allCases.enumerated() {
            state.selectedFormat = format
            let original = folder.appendingPathComponent("incoming-\(index).heic")
            try fixture.write(to: original)
            let probe = try #require(CGImageSourceCreateWithURL(original as CFURL, nil))
            #expect(CGImageSourceGetStatus(probe) == .statusComplete)
            #expect(CGImageSourceGetStatusAtIndex(probe, 0) == .statusComplete)
            #expect(CGImageSourceCopyPropertiesAtIndex(probe, 0, nil) != nil)
            try await waitUntil(state: state) { state.recentConversions.count == index + 1 }
            #expect(FileManager.default.fileExists(atPath: original.deletingPathExtension().appendingPathExtension(format.fileExtension).path))
            #expect(try Data(contentsOf: original) == fixture)
        }
        #expect(preferences.load().selectedFormat == .webP)
        let reopened = AppState(environment: AppEnvironment(converter: ImageConversionService(),
            historyStore: InMemoryHistoryStore(), webPInspector: WebPCapabilityInspector(), preferencesStore: preferences))
        #expect(reopened.selectedFormat == .webP)
        #expect(reopened.watchedFolder.path == folder.path)
        state.monitoringEnabled = false
        try await waitUntil(state: state) { state.monitoringStatus == "Paused" }
        try fixture.write(to: folder.appendingPathComponent("paused.heic"))
        try await Task.sleep(for: .milliseconds(250))
        #expect(state.recentConversions.count == 3)
        #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("paused.webp").path))
    }

    private func waitUntil(state: AppState, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(6))
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(30))
        }
        throw IntegrationError.timeout("\(state.monitoringStatus); \(state.conversionPhase); history=\(state.recentConversions.count)")
    }

    private func makeHEIC() throws -> Data {
        let context = try #require(CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8,
            bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        let data = NSMutableData()
        let encoder = try #require(CGImageDestinationCreateWithData(data, "public.heic" as CFString, 1, nil))
        CGImageDestinationAddImage(encoder, try #require(context.makeImage()), nil)
        #expect(CGImageDestinationFinalize(encoder))
        return data as Data
    }
}

private enum IntegrationError: Error { case timeout(String) }
