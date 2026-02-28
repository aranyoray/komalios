//
//  Nonce+SHAHelper.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//

import Foundation
import CryptoKit

enum NonceError: LocalizedError {
    case randomGenerationFailed(OSStatus)
    var errorDescription: String? {
        switch self {
        case .randomGenerationFailed(let status): return "Unable to generate nonce. OSStatus \(status)"
        }
    }
}

enum Nonce {
    static func randomString(length: Int = 32) throws -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess { throw NonceError.randomGenerationFailed(status) }

            for r in randoms {
                if remaining == 0 { break }
                if r < charset.count {
                    result.append(charset[Int(r)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
