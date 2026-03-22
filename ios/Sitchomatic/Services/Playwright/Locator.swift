import Foundation
import WebKit

@MainActor
final class Locator {

    let selector: String

    private let page: PlaywrightPage
    private let timeout: TimeInterval
    private let pollInterval: TimeInterval = 0.15
    private let maxRetries: Int = 3
    private let parentSelector: String?
    private let nthIndex: Int?
    private let textFilter: String?

    init(
        page: PlaywrightPage,
        selector: String,
        timeout: TimeInterval = 30.0,
        parentSelector: String? = nil,
        nthIndex: Int? = nil,
        textFilter: String? = nil
    ) {
        self.page = page
        self.selector = selector
        self.timeout = timeout
        self.parentSelector = parentSelector
        self.nthIndex = nthIndex
        self.textFilter = textFilter
    }

    // MARK: - Actions

    func click(timeout: TimeInterval? = nil) async throws {
        let effectiveTimeout = timeout ?? self.timeout
        page.trace(.action, "click(\(selector))")
        let speed = PlaywrightOrchestrator.shared.currentSpeedMode

        try await retryAction(timeout: effectiveTimeout) {
            try await self.waitForActionable(timeout: effectiveTimeout)
            try await self.humanDelay(speed.actionDelayWithVariance())

            let js = """
            (function() {
                \(self.resolveElementJS())
                if (!el) return JSON.stringify({error: 'not_found'});
                el.scrollIntoView({behavior: 'instant', block: 'center', inline: 'nearest'});
                var rect = el.getBoundingClientRect();
                var cx = rect.left + rect.width / 2;
                var cy = rect.top + rect.height / 2;
                var pointEl = document.elementFromPoint(cx, cy);
                if (pointEl && (pointEl === el || el.contains(pointEl) || pointEl.contains(el))) {
                    el.click();
                    return JSON.stringify({success: true});
                }
                el.click();
                return JSON.stringify({success: true});
            })()
            """

            let result: String = try await self.page.evaluate(js)
            let parsed = try self.parseActionResult(result)
            guard parsed["success"] != nil else {
                throw PlaywrightError.elementNotInteractable(self.selector)
            }
        }
    }

    func fill(_ value: String, timeout: TimeInterval? = nil) async throws {
        let effectiveTimeout = timeout ?? self.timeout
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        page.trace(.action, "fill(\(selector), '\(String(value.prefix(40)))')")
        let speed = PlaywrightOrchestrator.shared.currentSpeedMode

        try await retryAction(timeout: effectiveTimeout) {
            try await self.waitForActionable(timeout: effectiveTimeout)
            try await self.humanDelay(speed.actionDelayWithVariance())

            let js = """
            (function() {
                \(self.resolveElementJS())
                if (!el) return JSON.stringify({error: 'not_found'});
                el.focus();
                el.select && el.select();
                el.value = '';
                el.dispatchEvent(new Event('input', {bubbles: true}));
                el.value = '\(escaped)';
                el.dispatchEvent(new Event('input', {bubbles: true}));
                el.dispatchEvent(new Event('change', {bubbles: true}));
                el.dispatchEvent(new Event('blur', {bubbles: true}));
                return JSON.stringify({success: true});
            })()
            """

            let result: String = try await self.page.evaluate(js)
            let parsed = try self.parseActionResult(result)
            guard parsed["success"] != nil else {
                throw PlaywrightError.elementNotInteractable(self.selector)
            }
        }
    }

    func clear(timeout: TimeInterval? = nil) async throws {
        let effectiveTimeout = timeout ?? self.timeout
        page.trace(.action, "clear(\(selector))")

        try await retryAction(timeout: effectiveTimeout) {
            try await self.waitForActionable(timeout: effectiveTimeout)

            let js = """
            (function() {
                \(self.resolveElementJS())
                if (!el) return JSON.stringify({error: 'not_found'});
                el.focus();
                el.select && el.select();
                el.value = '';
                el.dispatchEvent(new Event('input', {bubbles: true}));
                el.dispatchEvent(new Event('change', {bubbles: true}));
                return JSON.stringify({success: true});
            })()
            """

            let result: String = try await self.page.evaluate(js)
            _ = try self.parseActionResult(result)
        }
    }

    func type(_ text: String, delay: Int? = nil, timeout: TimeInterval? = nil) async throws {
        let effectiveTimeout = timeout ?? self.timeout
        let speed = PlaywrightOrchestrator.shared.currentSpeedMode
        let effectiveDelay = delay ?? speed.typingDelayMs
        page.trace(.action, "type(\(selector), '\(String(text.prefix(40)))', delay: \(effectiveDelay)ms)")

        try await waitForActionable(timeout: effectiveTimeout)

        let focusJS = """
        (function() {
            \(resolveElementJS())
            if (!el) return JSON.stringify({error: 'not_found'});
            el.focus();
            return JSON.stringify({success: true});
        })()
        """

        let focusResult: String = try await page.evaluate(focusJS)
        let parsed = try parseActionResult(focusResult)
        guard parsed["success"] != nil else {
            throw PlaywrightError.elementNotInteractable(selector)
        }

        for char in text {
            let charStr = String(char)

            if charStr == "Enter" || charStr == "\n" {
                let keyJS = """
                (function() {
                    \(resolveElementJS())
                    if (!el) return;
                    var ev = {key: 'Enter', code: 'Enter', bubbles: true, cancelable: true};
                    el.dispatchEvent(new KeyboardEvent('keydown', ev));
                    el.dispatchEvent(new KeyboardEvent('keypress', ev));
                    var form = el.closest('form');
                    if (form) form.dispatchEvent(new Event('submit', {bubbles: true, cancelable: true}));
                    el.dispatchEvent(new KeyboardEvent('keyup', ev));
                })()
                """
                try await page.evaluateVoid(keyJS)
            } else {
                let escapedChar = charStr
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")

                let charJS = """
                (function() {
                    \(resolveElementJS())
                    if (!el) return;
                    var key = '\(escapedChar)';
                    el.dispatchEvent(new KeyboardEvent('keydown', {key: key, bubbles: true}));
                    el.dispatchEvent(new KeyboardEvent('keypress', {key: key, bubbles: true}));
                    el.value += key;
                    el.dispatchEvent(new Event('input', {bubbles: true}));
                    el.dispatchEvent(new KeyboardEvent('keyup', {key: key, bubbles: true}));
                })()
                """
                try await page.evaluateVoid(charJS)
            }

            let variance = Int.random(in: speed.humanVarianceRange)
            try await Task.sleep(for: .milliseconds(effectiveDelay + variance))
        }
    }

    func check(timeout: TimeInterval? = nil) async throws {
        let effectiveTimeout = timeout ?? self.timeout
        page.trace(.action, "check(\(selector))")

        try await retryAction(timeout: effectiveTimeout) {
            try await self.waitForActionable(timeout: effectiveTimeout)

            let js = """
            (function() {
                \(self.resolveElementJS())
                if (!el) return JSON.stringify({error: 'not_found'});
                if (!el.checked) { el.click(); }
                return JSON.stringify({success: true, checked: el.checked});
            })()
            """

            let result: String = try await self.page.evaluate(js)
            _ = try self.parseActionResult(result)
        }
    }

    func uncheck(timeout: TimeInterval? = nil) async throws {
        let effectiveTimeout = timeout ?? self.timeout
        page.trace(.action, "uncheck(\(selector))")

        try await retryAction(timeout: effectiveTimeout) {
            try await self.waitForActionable(timeout: effectiveTimeout)

            let js = """
            (function() {
                \(self.resolveElementJS())
                if (!el) return JSON.stringify({error: 'not_found'});
                if (el.checked) { el.click(); }
                return JSON.stringify({success: true, checked: el.checked});
            })()
            """

            let result: String = try await self.page.evaluate(js)
            _ = try self.parseActionResult(result)
        }
    }

    func selectOption(_ value: String, timeout: TimeInterval? = nil) async throws {
        let effectiveTimeout = timeout ?? self.timeout
        page.trace(.action, "selectOption(\(selector), '\(value)')")

        try await retryAction(timeout: effectiveTimeout) {
            try await self.waitForActionable(timeout: effectiveTimeout)

            let escapedValue = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")

            let js = """
            (function() {
                \(self.resolveElementJS())
                if (!el) return JSON.stringify({error: 'not_found'});
                el.value = '\(escapedValue)';
                el.dispatchEvent(new Event('change', {bubbles: true}));
                el.dispatchEvent(new Event('input', {bubbles: true}));
                return JSON.stringify({success: true});
            })()
            """

            let result: String = try await self.page.evaluate(js)
            _ = try self.parseActionResult(result)
        }
    }

    // MARK: - Queries

    func isVisible() async throws -> Bool {
        let js = """
        (function() {
            \(resolveElementJS())
            if (!el) return false;
            var rect = el.getBoundingClientRect();
            var style = window.getComputedStyle(el);
            return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none' && style.opacity !== '0';
        })()
        """
        return (try? await page.evaluate(js) as Bool) ?? false
    }

    func isEnabled() async throws -> Bool {
        let js = """
        (function() {
            \(resolveElementJS())
            if (!el) return false;
            return !el.disabled;
        })()
        """
        return (try? await page.evaluate(js) as Bool) ?? false
    }

    func isChecked() async throws -> Bool {
        let js = """
        (function() {
            \(resolveElementJS())
            if (!el) return false;
            return !!el.checked;
        })()
        """
        return (try? await page.evaluate(js) as Bool) ?? false
    }

    func textContent() async throws -> String {
        let js = """
        (function() {
            \(resolveElementJS())
            if (!el) return '';
            return el.textContent || '';
        })()
        """
        return try await page.evaluate(js)
    }

    func innerText() async throws -> String {
        let js = """
        (function() {
            \(resolveElementJS())
            if (!el) return '';
            return el.innerText || '';
        })()
        """
        return try await page.evaluate(js)
    }

    func inputValue() async throws -> String {
        let js = """
        (function() {
            \(resolveElementJS())
            if (!el) return '';
            return el.value || '';
        })()
        """
        return try await page.evaluate(js)
    }

    func getAttribute(_ name: String) async throws -> String? {
        let js = """
        (function() {
            \(resolveElementJS())
            if (!el) return null;
            return el.getAttribute('\(name)');
        })()
        """
        return try? await page.evaluate(js) as String
    }

    func count() async throws -> Int {
        let js = """
        (function() {
            var els = document.querySelectorAll('\(selector.replacingOccurrences(of: "'", with: "\\'"))');
            return els.length;
        })()
        """
        let result: Int = (try? await page.evaluate(js)) ?? 0
        return result
    }

    // MARK: - Chaining

    func first() -> Locator {
        Locator(page: page, selector: selector, timeout: timeout, parentSelector: parentSelector, nthIndex: 0, textFilter: textFilter)
    }

    func last() -> Locator {
        Locator(page: page, selector: selector, timeout: timeout, parentSelector: parentSelector, nthIndex: -1, textFilter: textFilter)
    }

    func nth(_ index: Int) -> Locator {
        Locator(page: page, selector: selector, timeout: timeout, parentSelector: parentSelector, nthIndex: index, textFilter: textFilter)
    }

    func filter(hasText: String) -> Locator {
        Locator(page: page, selector: selector, timeout: timeout, parentSelector: parentSelector, nthIndex: nthIndex, textFilter: hasText)
    }

    func locator(_ childSelector: String) -> Locator {
        Locator(page: page, selector: childSelector, timeout: timeout, parentSelector: selector)
    }

    // MARK: - Wait

    func waitFor(state: LocatorState = .visible, timeout: TimeInterval? = nil) async throws {
        let effectiveTimeout = timeout ?? self.timeout
        page.trace(.wait, "waitFor(\(selector), state: \(state.rawValue))")
        let deadline = Date().addingTimeInterval(effectiveTimeout)

        while Date() < deadline {
            switch state {
            case .visible:
                if try await isVisible() { return }
            case .hidden:
                if try await !isVisible() { return }
            case .attached:
                let exists: Bool = try await page.evaluate("""
                (function() { \(resolveElementJS()); return !!el; })()
                """)
                if exists { return }
            }
            try await Task.sleep(for: .milliseconds(Int(pollInterval * 1000)))
        }

        throw PlaywrightError.timeout("waitFor(\(selector), \(state.rawValue)) timed out after \(Int(effectiveTimeout))s")
    }

    // MARK: - Internal

    func resolveElementJS() -> String {
        var js = ""

        if let parent = parentSelector {
            js += "var parent = document.querySelector('\(parent.replacingOccurrences(of: "'", with: "\\'"))');\n"
            js += "if (!parent) { var el = null; }\n"
            js += "else {\n"
        }

        let escapedSelector = selector.replacingOccurrences(of: "'", with: "\\'")

        if let textFilter {
            let escapedText = textFilter.replacingOccurrences(of: "'", with: "\\'")
            let scope = parentSelector != nil ? "parent" : "document"
            js += "var allEls = \(scope).querySelectorAll('\(escapedSelector)');\n"
            js += "var el = null;\n"
            js += "for (var i = 0; i < allEls.length; i++) {\n"
            js += "  if (allEls[i].textContent && allEls[i].textContent.indexOf('\(escapedText)') !== -1) { el = allEls[i]; break; }\n"
            js += "}\n"
        } else if let nthIndex {
            let scope = parentSelector != nil ? "parent" : "document"
            js += "var allEls = \(scope).querySelectorAll('\(escapedSelector)');\n"
            if nthIndex == -1 {
                js += "var el = allEls.length > 0 ? allEls[allEls.length - 1] : null;\n"
            } else {
                js += "var el = allEls.length > \(nthIndex) ? allEls[\(nthIndex)] : null;\n"
            }
        } else {
            let scope = parentSelector != nil ? "parent" : "document"
            js += "var el = \(scope).querySelector('\(escapedSelector)');\n"
        }

        if parentSelector != nil {
            js += "}\n"
        }

        return js
    }

    private func waitForActionable(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?

        while Date() < deadline {
            do {
                let visible = try await isVisible()
                let enabled = try await isEnabled()
                if visible && enabled { return }
                if !visible { lastError = PlaywrightError.elementNotVisible(selector) }
                if !enabled { lastError = PlaywrightError.elementNotInteractable(selector) }
            } catch {
                lastError = error
            }
            try await Task.sleep(for: .milliseconds(Int(pollInterval * 1000)))
        }

        throw lastError ?? PlaywrightError.timeout("Element \(selector) not actionable after \(Int(timeout))s")
    }

    private func retryAction(timeout: TimeInterval, action: () async throws -> Void) async throws {
        var lastError: Error?
        for attempt in 0..<maxRetries {
            do {
                try await action()
                return
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let backoff = Int(pollInterval * 1000) * (attempt + 1)
                    try await Task.sleep(for: .milliseconds(backoff))
                }
            }
        }
        throw lastError ?? PlaywrightError.timeout("Action on \(selector) failed after \(maxRetries) retries")
    }

    func parseActionResult(_ json: String) throws -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PlaywrightError.javaScriptError("Failed to parse action result: \(json)")
        }

        if let error = dict["error"] as? String {
            switch error {
            case "not_found": throw PlaywrightError.elementNotFound(selector)
            case "not_visible": throw PlaywrightError.elementNotVisible(selector)
            default: throw PlaywrightError.javaScriptError(error)
            }
        }

        return dict
    }

    private func humanDelay(_ ms: Int) async throws {
        guard ms > 0 else { return }
        try await Task.sleep(for: .milliseconds(ms))
    }
}
