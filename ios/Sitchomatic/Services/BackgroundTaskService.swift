import Foundation
import UIKit

@MainActor
final class BackgroundTaskService {
    static let shared = BackgroundTaskService()

    private var activeTasks: [String: UIBackgroundTaskIdentifier] = [:]
    private let logger = DebugLogger.shared

    private init() {}

    func beginBackgroundTask(identifier: String, expirationHandler: @escaping @Sendable () -> Void) {
        if let existing = activeTasks[identifier], existing != .invalid {
            return
        }

        let taskID = UIApplication.shared.beginBackgroundTask(withName: identifier) { [weak self] in
            expirationHandler()
            Task { @MainActor in
                self?.endBackgroundTask(identifier: identifier)
            }
        }

        if taskID != .invalid {
            activeTasks[identifier] = taskID
            logger.log("Background task started: \(identifier)", category: .automation, level: .info)
        } else {
            logger.log("Failed to start background task: \(identifier)", category: .automation, level: .warning)
        }
    }

    func endBackgroundTask(identifier: String) {
        guard let taskID = activeTasks[identifier], taskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(taskID)
        activeTasks.removeValue(forKey: identifier)
        logger.log("Background task ended: \(identifier)", category: .automation, level: .info)
    }

    func endAllTasks() {
        for (identifier, taskID) in activeTasks where taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
            logger.log("Background task force-ended: \(identifier)", category: .automation, level: .warning)
        }
        activeTasks.removeAll()
    }

    var activeTaskCount: Int { activeTasks.count }
    var hasActiveTasks: Bool { !activeTasks.isEmpty }
}
