//
//  ScanNetworkService.swift
//  Komalios
//
//  Created on 18/01/26.
//

import Foundation

// MARK: - Network Service

class ScanNetworkService {
    private let baseURL = "https://komalkids.com"
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }
    
    /// Main function to scan URL - replicates analyzeUrlOptimized() flow
    func scanURL(_ urlString: String) async throws -> ScanResponse {
        let endpoint = "\(baseURL)/api/scan-url"
        guard let url = URL(string: endpoint) else {
            throw ScanNetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ScanRequest(url: urlString)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScanNetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorData["error"] {
                throw ScanNetworkError.apiError(errorMessage)
            }
            throw ScanNetworkError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ScanResponse.self, from: data)
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
