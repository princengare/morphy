import Foundation

public actor JSONHistoryStore: HistoryStoring {
    private let fileURL: URL
    private var cachedRecords: [ConversionRecord]?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultStore() throws -> JSONHistoryStore {
        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = supportURL.appendingPathComponent("Morphy", isDirectory: true)
        return JSONHistoryStore(fileURL: folder.appendingPathComponent("conversion-history.json"))
    }

    public func records() async throws -> [ConversionRecord] {
        if let cachedRecords {
            return cachedRecords
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cachedRecords = []
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let decoded = try JSONDecoder.morphy.decode([ConversionRecord].self, from: data)
        cachedRecords = decoded
        return decoded
    }

    public func add(_ record: ConversionRecord) async throws {
        var currentRecords = try await records()
        currentRecords.insert(record, at: 0)
        try save(currentRecords)
        cachedRecords = currentRecords
    }

    public func clear() async throws {
        cachedRecords = []
        try save([])
    }

    private func save(_ records: [ConversionRecord]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.morphy.encode(records)
        try data.write(to: fileURL, options: .atomic)
    }
}

public actor InMemoryHistoryStore: HistoryStoring {
    private var storedRecords: [ConversionRecord] = []

    public init() {}

    public func records() async throws -> [ConversionRecord] {
        storedRecords
    }

    public func add(_ record: ConversionRecord) async throws {
        storedRecords.insert(record, at: 0)
    }

    public func clear() async throws {
        storedRecords.removeAll()
    }
}

private extension JSONEncoder {
    static var morphy: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var morphy: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
