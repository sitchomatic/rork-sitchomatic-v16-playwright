import Foundation

@MainActor
final class CrashProtectionService {
    static let shared = CrashProtectionService()

    private(set) var isMonitoring: Bool = false
    private(set) var currentMemoryUsageMB: Double = 0
    private(set) var peakMemoryUsageMB: Double = 0
    private(set) var crashCount: Int = 0
    private var monitorTask: Task<Void, Never>?

    private let memoryCriticalThresholdMB: Double = 800
    private let memoryEmergencyThresholdMB: Double = 1000
    private let memorySafeThresholdMB: Double = 500
    private let memoryHighThresholdMB: Double = 600

    private init() {}

    var isMemoryCritical: Bool { currentMemoryUsageMB > memoryCriticalThresholdMB }
    var isMemoryEmergency: Bool { currentMemoryUsageMB > memoryEmergencyThresholdMB }
    var isMemorySafeForNewSession: Bool { currentMemoryUsageMB < memorySafeThresholdMB }
    var shouldReduceConcurrency: Bool { currentMemoryUsageMB > memoryHighThresholdMB }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.updateMemoryUsage()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
    }

    func waitForMemoryToDrop(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            updateMemoryUsage()
            if isMemorySafeForNewSession { return true }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return isMemorySafeForNewSession
    }

    func recordCrash() {
        crashCount += 1
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            currentMemoryUsageMB = Double(info.resident_size) / 1_048_576
            peakMemoryUsageMB = max(peakMemoryUsageMB, currentMemoryUsageMB)
        }
    }

    var diagnosticSummary: String {
        "Memory: \(String(format: "%.0f", currentMemoryUsageMB))MB (peak: \(String(format: "%.0f", peakMemoryUsageMB))MB) | Crashes: \(crashCount) | Safe: \(isMemorySafeForNewSession)"
    }
}
