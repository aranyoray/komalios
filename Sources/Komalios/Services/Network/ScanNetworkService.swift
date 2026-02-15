//
//  ScanNetworkService.swift
//  Komalios
//
//  Created on 18/01/26.
//

import Foundation
import os.log

private let debugLog = OSLog(subsystem: "com.komalkids.komal", category: "NetworkDebug")

/// Writes debug lines to both os_log and a file in the app's Documents directory
func debugLogLine(_ message: String) {
    os_log("%{public}@", log: debugLog, type: .default, message)
    let line = "\(Date()): \(message)\n"
    if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let logFile = docs.appendingPathComponent("komal_debug.log")
        if let handle = try? FileHandle(forWritingTo: logFile) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? line.data(using: .utf8)?.write(to: logFile)
        }
    }
}

// MARK: - Network Service

class ScanNetworkService {
    private let baseURL = "https://www.komalkids.com"
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }
    
    /// Main function to scan URL - sends URL and raw search input to server for analysis
    func scanURL(_ urlString: String, searchQuery: String? = nil) async throws -> ScanResponse {
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
        debugLogLine("[DEBUG-NET] Response body: \(responseStr.prefix(500))")

        let decoder = JSONDecoder()
        do {
            let result = try decoder.decode(ScanResponse.self, from: data)
            debugLogLine("[DEBUG-NET] Decoded successfully - overallScore: \(result.overallScore), ageGroups: \(result.ageGroupScores.map { "\($0.key): \($0.value.action.rawValue)" })")
            return result
        } catch {
            debugLogLine("[DEBUG-NET] DECODE ERROR: \(error)")
            throw error
        }
    }
}

// MARK: - Network Error

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
