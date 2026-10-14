import Foundation
import Testing
@testable import MorphyCore

@Suite("Quality presets")
struct QualityPresetTests {
    @Test("Recommended maps to user-hidden encoder values")
    func recommendedQualityValues() {
        #expect(QualityPreset.recommended.encoderQuality(for: .jpeg) == 0.92)
        #expect(QualityPreset.recommended.encoderQuality(for: .webP) == 0.85)
        #expect(QualityPreset.recommended.encoderQuality(for: .png) == nil)
    }
}

@Suite("Duplicate names")
struct DuplicateNameResolverTests {
    @Test("Add number keeps existing output untouched")
    func addNumberPolicy() throws {
        let folder = try TemporaryFolder()
        let existing = folder.url.appendingPathComponent("IMG_4821.jpg")
        FileManager.default.createFile(atPath: existing.path, contents: Data("existing".utf8))

        let resolved = try DuplicateNameResolver().resolvedURL(for: existing, policy: .addNumber)

        #expect(resolved.lastPathComponent == "IMG_4821 2.jpg")
        #expect(FileManager.default.fileExists(atPath: existing.path))
    }

    @Test("Skip reports a conflict")
    func skipPolicyThrows() throws {
        let folder = try TemporaryFolder()
        let existing = folder.url.appendingPathComponent("IMG_4821.jpg")
        FileManager.default.createFile(atPath: existing.path, contents: Data())

        #expect(throws: ConversionError.duplicateConflict) {
            try DuplicateNameResolver().resolvedURL(for: existing, policy: .skip)
        }
    }
}

@Suite("History store")
struct HistoryStoreTests {
    @Test("Clearing history does not remove converted files")
    func clearHistoryLeavesFilesAlone() async throws {
        let folder = try TemporaryFolder()
        let output = folder.url.appendingPathComponent("converted.jpg")
        FileManager.default.createFile(atPath: output.path, contents: Data("image".utf8))
        let storeURL = folder.url.appendingPathComponent("history.json")
        let store = JSONHistoryStore(fileURL: storeURL)
        let record = ConversionRecord(
            sourceFilename: "source.heic",
            sourcePathSnapshot: folder.url.appendingPathComponent("source.heic").path,
            outputFilename: output.lastPathComponent,
            outputPathSnapshot: output.path,
            sourceFormat: "public.heic",
            outputFormat: .jpeg,
            sourceFileSize: 10,
            outputFileSize: 5,
            width: 1,
            height: 1,
            qualityPreset: .recommended,
            startedAt: Date(),
            completedAt: Date(),
            duration: 0.1,
            originalPolicy: .keep,
            status: .completed,
            errorCode: nil,
            errorMessage: nil,
            metadataPolicy: .preserveCompatible
        )

        try await store.add(record)
        try await store.clear()

        #expect(try await store.records().isEmpty)
        #expect(FileManager.default.fileExists(atPath: output.path))
    }
}

@Suite("Folder validation")
struct WatchedFolderValidationTests {
    @Test("Recursive parent conflicts with child watch")
    func recursiveParentConflict() {
        let service = WatchedFolderValidationService()
        let parent = WatchedFolder(displayURL: URL(fileURLWithPath: "/tmp/MorphyParent"), includeSubfolders: true)
        let child = WatchedFolder(displayURL: URL(fileURLWithPath: "/tmp/MorphyParent/Child"))

        #expect(service.conflict(between: parent, candidate: child) == .existingRecursiveParent)
    }
}

private final class TemporaryFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MorphyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}
