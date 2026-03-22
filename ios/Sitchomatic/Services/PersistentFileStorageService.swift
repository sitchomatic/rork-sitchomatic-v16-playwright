import Foundation

@MainActor
final class PersistentFileStorageService {
    static let shared = PersistentFileStorageService()

    private let baseDirectory: URL
    private let logger = DebugLogger.shared

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        baseDirectory = docs.appendingPathComponent("SitchomaticV16", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
    }

    func save(data: Data, filename: String) {
        let url = baseDirectory.appendingPathComponent(filename)
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            logger.log("File save failed: \(filename) — \(error.localizedDescription)", category: .persistence, level: .error)
        }
    }

    func load(filename: String) -> Data? {
        let url = baseDirectory.appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    func delete(filename: String) {
        let url = baseDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    func exists(filename: String) -> Bool {
        let url = baseDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path)
    }

    func listFiles(in subdirectory: String = "") -> [String] {
        let dir = subdirectory.isEmpty ? baseDirectory : baseDirectory.appendingPathComponent(subdirectory)
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [] }
        return contents
    }

    func purgeAll() {
        try? FileManager.default.removeItem(at: baseDirectory)
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        logger.log("All stored files purged", category: .persistence, level: .warning)
    }

    var storageSizeMB: Double {
        guard let enumerator = FileManager.default.enumerator(at: baseDirectory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return Double(total) / 1_048_576
    }
}
