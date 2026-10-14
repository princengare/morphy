import Darwin
import Foundation

enum MonitoringLeaderLockError: Error {
    case couldNotCreateDirectory
    case couldNotOpenLock
    case alreadyLocked
}

final class MonitoringLeaderLock {
    private let fileDescriptor: Int32

    private init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }

    static func acquire() throws -> MonitoringLeaderLock {
        let lockURL = try lockFileURL()
        let descriptor = open(lockURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw MonitoringLeaderLockError.couldNotOpenLock
        }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            throw MonitoringLeaderLockError.alreadyLocked
        }

        let diagnostics = "pid=\(getpid())\nstartedAt=\(ISO8601DateFormatter().string(from: Date()))\n"
        ftruncate(descriptor, 0)
        lseek(descriptor, 0, SEEK_SET)
        diagnostics.utf8.withContiguousStorageIfAvailable { bytes in
            _ = write(descriptor, bytes.baseAddress, bytes.count)
        }

        return MonitoringLeaderLock(fileDescriptor: descriptor)
    }

    deinit {
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
    }

    private static func lockFileURL() throws -> URL {
        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = supportURL.appendingPathComponent("Morphy", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("Morphy.lock")
    }
}
