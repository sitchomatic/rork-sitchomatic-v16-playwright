import Foundation

@MainActor
final class SiteLoginAutomationService {
    static let shared = SiteLoginAutomationService()

    private let logger: DebugLogger = .shared
    private let selectorPollInterval: Duration = .milliseconds(150)

    private init() {}

    func executeLogin(
        on page: PlaywrightPage,
        site: AutomationSite,
        credential: LoginCredential,
        speedMode: SpeedMode,
        overrideURL: String? = nil
    ) async throws -> DualLoginOutcome {
        let loginURL: String = normalizedURL(overrideURL, fallback: site.defaultLoginURL)
        let selectorSummary: String = site.loginFormSelectors.joined(separator: " | ")

        page.trace(.system, "Site login start — site: \(site.rawValue), url: \(loginURL)")
        logger.log(
            "Starting \(site.displayName) login for \(credential.displayName) using selectors: \(selectorSummary)",
            category: .automation,
            level: .info
        )

        do {
            try await page.goto(loginURL, waitUntil: .networkIdle, timeout: 30)

            let usernameSelector: String = try await resolveFirstAvailableSelector(
                site.usernameSelectors,
                on: page,
                timeout: 12
            )
            let passwordSelector: String = try await resolveFirstAvailableSelector(
                site.passwordSelectors,
                on: page,
                timeout: 12
            )
            let submitSelector: String = try await resolveFirstAvailableSelector(
                site.submitSelectors,
                on: page,
                timeout: 12
            )

            page.trace(.action, "Resolved selectors — username: \(usernameSelector), password: \(passwordSelector), submit: \(submitSelector)")

            try await page.locator(usernameSelector).fill(credential.username)
            try await page.locator(passwordSelector).fill(credential.password)
            try await page.locator(submitSelector).click()

            try? await page.waitForLoadState(.networkIdle, timeout: 8)
            try await page.waitForTimeout(speedMode.postSubmitWaitMs)

            let outcome: DualLoginOutcome = try await classifyOutcome(
                on: page,
                site: site,
                loginURL: loginURL,
                submitSelector: submitSelector
            )

            page.trace(.assertion, "Site login classified as \(outcome.rawValue) for \(site.rawValue)")
            return outcome
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as PlaywrightError {
            switch error {
            case .invalidURL, .navigationFailed:
                logger.log(
                    "\(site.displayName) navigation failure: \(error.localizedDescription)",
                    category: .automation,
                    level: .error
                )
                return .networkError
            case .timeout(let message):
                logger.log(
                    "\(site.displayName) timeout: \(message)",
                    category: .automation,
                    level: .warning
                )
                return .tempDisabled
            case .pageDisposed:
                return .crashed
            case .elementNotFound, .elementNotInteractable, .elementNotVisible:
                logger.log(
                    "\(site.displayName) selector failure: \(error.localizedDescription)",
                    category: .automation,
                    level: .error
                )
                return .unsure
            case .javaScriptError, .screenshotFailed, .assertionFailed:
                return .unsure
            }
        } catch {
            logger.log(
                "\(site.displayName) unexpected login error: \(error.localizedDescription)",
                category: .automation,
                level: .error
            )
            return .unsure
        }
    }

    private func resolveFirstAvailableSelector(
        _ selectors: [String],
        on page: PlaywrightPage,
        timeout: TimeInterval
    ) async throws -> String {
        let deadline: Date = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            for selector in selectors {
                let locator: Locator = page.locator(selector)
                let exists: Bool = ((try? await locator.count()) ?? 0) > 0
                let visible: Bool = (try? await locator.isVisible()) ?? false
                if exists || visible {
                    return selector
                }
            }
            try await Task.sleep(for: selectorPollInterval)
        }

        throw PlaywrightError.elementNotFound(selectors.joined(separator: " | "))
    }

    private func classifyOutcome(
        on page: PlaywrightPage,
        site: AutomationSite,
        loginURL: String,
        submitSelector: String
    ) async throws -> DualLoginOutcome {
        let currentURL: String = page.url().lowercased()
        let pageText: String = try await readVisibleText(on: page)
        let loweredText: String = pageText.lowercased()
        let submitStillVisible: Bool = (try? await page.locator(submitSelector).isVisible()) ?? false

        if containsAny(site.permanentFailureTextHints, in: loweredText) || containsAny(site.invalidCredentialTextHints, in: loweredText) {
            return .permDisabled
        }

        if containsAny(site.temporaryFailureTextHints, in: loweredText) {
            return .tempDisabled
        }

        let movedAwayFromLogin: Bool = !site.matchesLoginURL(currentURL) && currentURL != normalizedURL(loginURL, fallback: site.defaultLoginURL).lowercased()
        let successHintPresent: Bool = containsAny(site.successTextHints, in: loweredText)

        if successHintPresent || movedAwayFromLogin {
            return .success
        }

        if submitStillVisible {
            return .unsure
        }

        return .tempDisabled
    }

    private func readVisibleText(on page: PlaywrightPage) async throws -> String {
        let script: String = """
        (function() {
            var body = document.body;
            if (!body) return '';
            return body.innerText || body.textContent || '';
        })()
        """
        return try await page.evaluate(script)
    }

    private func containsAny(_ hints: [String], in text: String) -> Bool {
        hints.contains { text.contains($0) }
    }

    private func normalizedURL(_ value: String?, fallback: String) -> String {
        let trimmedValue: String = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedValue.isEmpty ? fallback : trimmedValue
    }
}
