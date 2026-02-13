import FirebaseAnalytics
import Foundation

/// Analytics service wrapping Firebase Analytics / Google Analytics 4
/// GA4 Stream ID: 13324004898
final class AnalyticsService {
    static let shared = AnalyticsService()

    private init() {}

    // MARK: - Screen Tracking

    func logScreenView(screenName: String, screenClass: String? = nil) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass ?? screenName
        ])
    }

    // MARK: - Authentication Events

    func logLogin(method: String) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod: method
        ])
    }

    func logSignUp(method: String) {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [
            AnalyticsParameterMethod: method
        ])
    }

    // MARK: - Browsing Events

    func logBrowsingSession(url: String, duration: TimeInterval) {
        Analytics.logEvent("browsing_session", parameters: [
            "url": url,
            "duration_seconds": Int(duration)
        ])
    }

    func logContentBlocked(url: String, reason: String) {
        Analytics.logEvent("content_blocked", parameters: [
            "url": url,
            "reason": reason
        ])
    }

    func logSafetyScan(url: String, result: String) {
        Analytics.logEvent("safety_scan", parameters: [
            "url": url,
            "result": result
        ])
    }

    // MARK: - User Properties

    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    func setUserId(_ userId: String?) {
        Analytics.setUserID(userId)
    }

    // MARK: - Custom Events

    func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
}
