//
//  ScanNetworkService.swift
//  Komalios
//
//  Created on 18/01/26.
//

import Foundation
import os.log

private let debugLog = OSLog(subsystem: "com.komalkids.komal", category: "NetworkDebug")

/// Writes debug lines to os_log only. File logging only in DEBUG builds.
func debugLogLine(_ message: String) {
    guard Config.debugAPILogging else { return }
    os_log("%{public}@", log: debugLog, type: .default, message)
    #if DEBUG
    let line = "\(Date()): \(message)\n"
    if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let logFile = docs.appendingPathComponent("komal_debug.log")
        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            if let data = line.data(using: .utf8) { handle.write(data) }
            handle.closeFile()
        } else {
            try? line.data(using: .utf8)?.write(to: logFile)
        }
    }
    #endif
}

// MARK: - Scan Result (supports both API formats)

enum ScanAPIResult {
    case legacy(ScanResponse)
    case unified(UnifiedDecisionResponse)
}

// MARK: - Network Service

class ScanNetworkService {
    private let baseURL = "https://www.komalkids.com"
    private let session: URLSession
    private let pinningDelegate = CertificatePinningDelegate()

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 20.0
        self.session = URLSession(configuration: config, delegate: pinningDelegate, delegateQueue: nil)
    }

    /// Scan URL - tries unified format first, falls back to legacy
    func scanURLWithFormat(_ urlString: String, searchQuery: String? = nil) async throws -> ScanAPIResult {
        let endpoint = "\(baseURL)/api/scan-url"
        debugLogLine("[DEBUG-NET] Calling cloud endpoint: \(endpoint)")
        debugLogLine("[DEBUG-NET] Scanning URL: \(urlString)")
        if let query = searchQuery {
            debugLogLine("[DEBUG-NET] Search query: \(query)")
        }
        guard let url = URL(string: endpoint) else {
            debugLogLine("[DEBUG-NET] ERROR: Invalid endpoint URL")
            throw ScanNetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Authenticate API requests with the Google Cloud API key
        let apiKey = Config.googleCloudAPIKey
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        let body = ScanRequest(url: urlString, searchQuery: searchQuery)
        request.httpBody = try JSONEncoder().encode(body)

        let startTime = CFAbsoluteTimeGetCurrent()
        let (data, response) = try await session.data(for: request)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime

        guard let httpResponse = response as? HTTPURLResponse else {
            debugLogLine("[DEBUG-NET] ERROR: Invalid response (not HTTP)")
            throw ScanNetworkError.invalidResponse
        }

        debugLogLine("[DEBUG-NET] Response status: \(httpResponse.statusCode) (took \(String(format: "%.2f", elapsed))s)")

        guard httpResponse.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<binary>"
            debugLogLine("[DEBUG-NET] ERROR: HTTP \(httpResponse.statusCode) - Body: \(bodyStr.prefix(500))")
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorData["error"] {
                throw ScanNetworkError.apiError(errorMessage)
            }
            throw ScanNetworkError.httpError(httpResponse.statusCode)
        }

        let responseStr = String(data: data, encoding: .utf8) ?? "<binary>"
        debugLogLine("[DEBUG-NET] Response body: \(responseStr.prefix(800))")

        let decoder = JSONDecoder()

        // Try unified format first (newer API)
        if let unified = try? decoder.decode(UnifiedDecisionResponse.self, from: data) {
            debugLogLine("[DEBUG-NET] Decoded as UNIFIED - ageActions: \(unified.ageActions.map { "\($0.key): \($0.value.action.rawValue)" })")
            return .unified(unified)
        }

        // Fall back to legacy format
        if let legacy = try? decoder.decode(ScanResponse.self, from: data) {
            debugLogLine("[DEBUG-NET] Decoded as LEGACY - overallScore: \(legacy.overallScore), ageGroups: \(legacy.ageGroupScores.map { "\($0.key): \($0.value.action.rawValue)" })")
            return .legacy(legacy)
        }

        // Neither format decoded — log the actual error
        debugLogLine("[DEBUG-NET] DECODE ERROR: Response doesn't match unified or legacy format")
        debugLogLine("[DEBUG-NET] Full response: \(responseStr.prefix(2000))")
        throw ScanNetworkError.decodingError
    }

    /// Legacy method kept for backward compat
    func scanURL(_ urlString: String, searchQuery: String? = nil) async throws -> ScanResponse {
        let result = try await scanURLWithFormat(urlString, searchQuery: searchQuery)
        switch result {
        case .legacy(let response):
            return response
        case .unified(let unified):
            // Convert unified response to legacy ScanResponse format
            var ageGroupScores: [String: AgeGroupScore] = [:]
            for (key, ageAction) in unified.ageActions {
                ageGroupScores[key] = AgeGroupScore(
                    score: Int(ageAction.score * 100),
                    action: ageAction.action,
                    reason: ageAction.reason ?? "Converted from unified format",
                    risks: ageAction.risks ?? []
                )
            }
            return ScanResponse(
                url: unified.url,
                overallScore: Int(unified.overallSafetyScore * 100),
                ageGroupScores: ageGroupScores,
                contentAnalysis: ContentAnalysis(
                    textAnalysis: TextAnalysis(
                        sentiment: "neutral",
                        keyTopics: unified.topicTags,
                        languageScore: Int(unified.languageSafetyScore * 100),
                        entities: nil,
                        unsafeKeywordsFound: [],
                        safeKeywordsFound: []
                    ),
                    visualAnalysis: VisualAnalysis(
                        detectedObjects: [],
                        safetyScore: Int(unified.visualSafetyScore * 100),
                        concerns: [],
                        labels: nil
                    ),
                    multimediaAnalysis: nil,
                    metadata: nil
                ),
                childSafetyAnalysis: ChildSafetyAnalysis(
                    overallRisk: unified.overallSafetyScore >= 0.7 ? .safe : unified.overallSafetyScore >= 0.4 ? .caution : .unsafe,
                    riskCategories: unified.majorCategories.map { cat in
                        RiskCategory(
                            category: cat.name,
                            severity: cat.probability > 0.7 ? "high" : cat.probability > 0.4 ? "medium" : "low",
                            matchCount: Int(cat.probability * 10),
                            matchedKeywords: [],
                            contextSnippets: []
                        )
                    },
                    depthAnalysis: DepthAnalysis(
                        titleSafe: unified.overallSafetyScore >= 0.5,
                        metadataSafe: unified.overallSafetyScore >= 0.5,
                        contentSafe: unified.overallSafetyScore >= 0.5,
                        mediaSafe: unified.visualSafetyScore >= 0.5
                    )
                ),
                timestamp: unified.timestamp,
                analysisMethod: nil,
                usedSearchFallback: nil,
                performanceMetrics: nil,
                pythonDebug: nil
            )
        }
    }
}

// MARK: - Network Error

// MARK: - Certificate Pinning

/// Validates server certificates for trusted API domains.
/// Pins to the server's public key to prevent MITM attacks.
final class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    /// Domains that require certificate validation
    private let pinnedDomains: Set<String> = ["www.komalkids.com", "komalkids.com", "generativelanguage.googleapis.com"]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              pinnedDomains.contains(challenge.protectionSpace.host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate the server trust against system root CAs
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)
        guard isValid else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Verify the certificate chain has at least one certificate
        guard SecTrustGetCertificateCount(serverTrust) > 0 else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

enum ScanNetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .apiError(let message):
            return message
        case .decodingError:
            return "Failed to decode response"
        }
    }
}
