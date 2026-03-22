import Foundation
import WebKit

nonisolated enum NavigationWaitCondition: String, Sendable {
    case load
    case domContentLoaded
    case networkIdle
}

nonisolated enum LocatorState: String, Sendable {
    case visible
    case hidden
    case attached
}

nonisolated enum TraceCategory: String, Sendable {
    case navigation
    case action
    case evaluate
    case screenshot
    case wait
    case assertion
    case system
}

nonisolated struct TraceEntry: Sendable, Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let category: TraceCategory
    let message: String
    let pageID: UUID

    var formatted: String {
        let ms = Int(timestamp.timeIntervalSince1970 * 1000) % 100000
        return "[\(ms)] [\(category.rawValue)] \(message)"
    }
}

nonisolated enum PlaywrightError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case navigationFailed(String)
    case timeout(String)
    case elementNotFound(String)
    case elementNotVisible(String)
    case elementNotInteractable(String)
    case javaScriptError(String)
    case screenshotFailed(String)
    case assertionFailed(String)
    case pageDisposed

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): "Invalid URL: \(url)"
        case .navigationFailed(let reason): "Navigation failed: \(reason)"
        case .timeout(let detail): "Timeout: \(detail)"
        case .elementNotFound(let selector): "Element not found: \(selector)"
        case .elementNotVisible(let selector): "Element not visible: \(selector)"
        case .elementNotInteractable(let selector): "Element not interactable: \(selector)"
        case .javaScriptError(let detail): "JavaScript error: \(detail)"
        case .screenshotFailed(let detail): "Screenshot failed: \(detail)"
        case .assertionFailed(let detail): "Assertion failed: \(detail)"
        case .pageDisposed: "Page has been disposed"
        }
    }
}

@MainActor
final class PlaywrightPage: Identifiable {

    let id: UUID
    let webView: WKWebView
    let defaultTimeout: TimeInterval

    private(set) var tracingEnabled: Bool = false
    private var traceLog: [TraceEntry] = []
    private var networkIdleInjected: Bool = false
    private let navigationDelegate: PageNavigationDelegate
    private weak var orchestrator: PlaywrightOrchestrator?
    private let autoWaitStabilityDelay: TimeInterval = 0.15

    init(webView: WKWebView, id: UUID, defaultTimeout: TimeInterval = 30.0, orchestrator: PlaywrightOrchestrator? = nil) {
        self.webView = webView
        self.id = id
        self.defaultTimeout = defaultTimeout
        self.orchestrator = orchestrator
        self.navigationDelegate = PageNavigationDelegate()
        webView.navigationDelegate = navigationDelegate
    }

    // MARK: - Navigation

    func goto(_ urlString: String, waitUntil: NavigationWaitCondition = .load, timeout: TimeInterval? = nil) async throws {
        let effectiveTimeout = timeout ?? defaultTimeout
        guard let url = URL(string: urlString) else {
            throw PlaywrightError.invalidURL(urlString)
        }

        trace(.navigation, "goto(\(urlString))")
        navigationDelegate.reset()

        webView.load(URLRequest(url: url))

        try await injectNetworkIdleMonitor()
        try await waitForNavigation(condition: waitUntil, timeout: effectiveTimeout)

        trace(.navigation, "goto complete — \(webView.url?.absoluteString ?? "unknown")")
    }

    func reload(waitUntil: NavigationWaitCondition = .load, timeout: TimeInterval? = nil) async throws {
        let effectiveTimeout = timeout ?? defaultTimeout
        trace(.navigation, "reload()")
        navigationDelegate.reset()
        webView.reload()
        try await waitForNavigation(condition: waitUntil, timeout: effectiveTimeout)
    }

    func goBack() async throws {
        trace(.navigation, "goBack()")
        navigationDelegate.reset()
        webView.goBack()
        try await waitForNavigation(condition: .load, timeout: defaultTimeout)
    }

    func goForward() async throws {
        trace(.navigation, "goForward()")
        navigationDelegate.reset()
        webView.goForward()
        try await waitForNavigation(condition: .load, timeout: defaultTimeout)
    }

    func waitForLoadState(_ condition: NavigationWaitCondition, timeout: TimeInterval? = nil) async throws {
        let effectiveTimeout = timeout ?? defaultTimeout
        trace(.wait, "waitForLoadState(\(condition.rawValue))")
        try await waitForNavigation(condition: condition, timeout: effectiveTimeout)
    }

    func waitForTimeout(_ ms: Int) async throws {
        trace(.wait, "waitForTimeout(\(ms)ms)")
        try await Task.sleep(for: .milliseconds(ms))
    }

    // MARK: - Locators

    func locator(_ selector: String, timeout: TimeInterval? = nil) -> Locator {
        Locator(page: self, selector: selector, timeout: timeout ?? defaultTimeout)
    }

    func getByRole(_ role: String, name: String? = nil) -> Locator {
        var selector = "[\(roleAttribute(role))]"
        if let name {
            selector = "[\(roleAttribute(role))][aria-label=\"\(name)\"], [\(roleAttribute(role))]:has-text(\"\(name)\")"
        }
        return Locator(page: self, selector: selector, timeout: defaultTimeout)
    }

    func getByText(_ text: String, exact: Bool = false) -> Locator {
        let selector = exact ? ":text-is(\"\(text)\")" : ":text(\"\(text)\")"
        return Locator(page: self, selector: selector, timeout: defaultTimeout, textFilter: text)
    }

    func getByPlaceholder(_ text: String) -> Locator {
        Locator(page: self, selector: "[placeholder=\"\(text)\"]", timeout: defaultTimeout)
    }

    func getByLabel(_ text: String) -> Locator {
        Locator(page: self, selector: "[aria-label=\"\(text)\"], label:has-text(\"\(text)\") + input, label:has-text(\"\(text)\") + select", timeout: defaultTimeout)
    }

    func getByTestId(_ testId: String) -> Locator {
        Locator(page: self, selector: "[data-testid=\"\(testId)\"]", timeout: defaultTimeout)
    }

    // MARK: - Expectations

    func expect(_ locator: Locator) -> Expectation {
        Expectation(locator: locator, page: self)
    }

    // MARK: - JavaScript Evaluation

    func evaluate<T>(_ script: String) async throws -> T {
        trace(.evaluate, "evaluate(\(String(script.prefix(80)))...)")
        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: PlaywrightError.javaScriptError(error.localizedDescription))
                } else if let typed = result as? T {
                    continuation.resume(returning: typed)
                } else if result == nil, let nilResult = Optional<Any>.none as? T {
                    continuation.resume(returning: nilResult)
                } else {
                    let desc = result.map { String(describing: $0) } ?? "nil"
                    continuation.resume(throwing: PlaywrightError.javaScriptError("Type mismatch — got \(desc)"))
                }
            }
        }
    }

    func evaluateVoid(_ script: String) async throws {
        trace(.evaluate, "evaluateVoid(\(String(script.prefix(60)))...)")
        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { _, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == "WKJavaScriptExceptionDomain" || nsError.code == 5 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: PlaywrightError.javaScriptError(error.localizedDescription))
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Screenshot

    func screenshot() async throws -> Data {
        trace(.screenshot, "screenshot()")
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = NSNumber(value: Int(webView.frame.width))

        return try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: config) { image, error in
                if let error {
                    continuation.resume(throwing: PlaywrightError.screenshotFailed(error.localizedDescription))
                } else if let image, let data = image.pngData() {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: PlaywrightError.screenshotFailed("No image data"))
                }
            }
        }
    }

    // MARK: - Page Info

    func url() -> String {
        webView.url?.absoluteString ?? ""
    }

    func title() async throws -> String {
        try await evaluate("document.title")
    }

    // MARK: - Close

    func close() {
        orchestrator?.closePage(self)
    }

    // MARK: - Tracing

    func startTracing() {
        tracingEnabled = true
        traceLog.removeAll()
        trace(.system, "Tracing started")
    }

    func stopTracing() -> [TraceEntry] {
        trace(.system, "Tracing stopped — \(traceLog.count) entries")
        tracingEnabled = false
        let log = traceLog
        traceLog.removeAll()
        return log
    }

    func trace(_ category: TraceCategory, _ message: String) {
        guard tracingEnabled else { return }
        traceLog.append(TraceEntry(
            timestamp: Date(),
            category: category,
            message: message,
            pageID: id
        ))
    }

    // MARK: - Private: Network Idle Monitor

    private func injectNetworkIdleMonitor() async throws {
        guard !networkIdleInjected else { return }

        let monitorJS = """
        (function() {
            if (window.__pwNetworkMonitor) return;
            window.__pwNetworkMonitor = {pending: 0, lastActivity: Date.now()};
            var m = window.__pwNetworkMonitor;
            var _fetch = window.fetch;
            window.fetch = function() {
                m.pending++;
                m.lastActivity = Date.now();
                return _fetch.apply(this, arguments).finally(function() {
                    m.pending = Math.max(0, m.pending - 1);
                    m.lastActivity = Date.now();
                });
            };
            var _open = XMLHttpRequest.prototype.open;
            var _send = XMLHttpRequest.prototype.send;
            XMLHttpRequest.prototype.open = function() {
                this.__pw_tracked = true;
                return _open.apply(this, arguments);
            };
            XMLHttpRequest.prototype.send = function() {
                if (this.__pw_tracked) {
                    m.pending++;
                    m.lastActivity = Date.now();
                    this.addEventListener('loadend', function() {
                        m.pending = Math.max(0, m.pending - 1);
                        m.lastActivity = Date.now();
                    });
                }
                return _send.apply(this, arguments);
            };
        })();
        """

        try await evaluateVoid(monitorJS)
        networkIdleInjected = true
    }

    // MARK: - Private: Navigation Wait

    private func waitForNavigation(condition: NavigationWaitCondition, timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        let pollInterval: TimeInterval = 0.1

        while Date() < deadline {
            if let navError = navigationDelegate.navigationError {
                throw PlaywrightError.navigationFailed(navError.localizedDescription)
            }

            let satisfied: Bool
            switch condition {
            case .load:
                satisfied = navigationDelegate.didFinishLoad
            case .domContentLoaded:
                let ready: String = (try? await evaluate("document.readyState")) ?? "loading"
                satisfied = ready == "interactive" || ready == "complete"
            case .networkIdle:
                if !navigationDelegate.didFinishLoad {
                    satisfied = false
                } else {
                    let idleCheck = """
                    (function() {
                        var m = window.__pwNetworkMonitor;
                        if (!m) return true;
                        return m.pending === 0 && (Date.now() - m.lastActivity) > 500;
                    })()
                    """
                    let isIdle: Bool = (try? await evaluate(idleCheck)) ?? true
                    satisfied = isIdle
                }
            }

            if satisfied {
                try await Task.sleep(for: .milliseconds(Int(autoWaitStabilityDelay * 1000)))
                return
            }

            try await Task.sleep(for: .milliseconds(Int(pollInterval * 1000)))
        }

        throw PlaywrightError.timeout("Navigation timed out after \(Int(timeout))s (condition: \(condition))")
    }

    // MARK: - Private: Role Mapping

    private func roleAttribute(_ role: String) -> String {
        switch role.lowercased() {
        case "button": return "role=\"button\""
        case "link": return "role=\"link\""
        case "textbox": return "role=\"textbox\""
        case "checkbox": return "role=\"checkbox\""
        case "heading": return "role=\"heading\""
        case "img", "image": return "role=\"img\""
        case "navigation": return "role=\"navigation\""
        case "dialog": return "role=\"dialog\""
        case "tab": return "role=\"tab\""
        case "listbox": return "role=\"listbox\""
        case "option": return "role=\"option\""
        case "menuitem": return "role=\"menuitem\""
        case "radio": return "role=\"radio\""
        case "slider": return "role=\"slider\""
        case "switch": return "role=\"switch\""
        case "alert": return "role=\"alert\""
        default: return "role=\"\(role)\""
        }
    }
}

// MARK: - Navigation Delegate

private final class PageNavigationDelegate: NSObject, WKNavigationDelegate {
    var didFinishLoad: Bool = false
    var navigationError: Error?

    func reset() {
        didFinishLoad = false
        navigationError = nil
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in self.didFinishLoad = true }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
            self.navigationError = error
            self.didFinishLoad = true
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
            self.navigationError = error
            self.didFinishLoad = true
        }
    }

    nonisolated func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    nonisolated func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
}
