import Foundation

nonisolated enum SessionVisibilityFilter: String, Hashable, CaseIterable, Sendable {
    case all
    case active
    case failed
    case succeeded

    var title: String {
        switch self {
        case .all: "All"
        case .active: "Active"
        case .failed: "Failed"
        case .succeeded: "Succeeded"
        }
    }
}
