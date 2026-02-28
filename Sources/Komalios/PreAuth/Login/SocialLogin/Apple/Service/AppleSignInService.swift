//
//  AppleSignInService.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//

import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif

final class AppleSignInService: NSObject {
    private var completion: ((Result<AppleSignInResult, Error>) -> Void)?
    private var currentNonce: String?

    func startSignIn(useNonce: Bool = true,
                     completion: @escaping (Result<AppleSignInResult, Error>) -> Void) {
        self.completion = completion

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        if useNonce {
            do {
                let nonce = try Nonce.randomString()
                currentNonce = nonce
                request.nonce = Nonce.sha256(nonce) // Apple expects hashed nonce
            } catch {
                completion?(.failure(error))
                return
            }
        } else {
            currentNonce = nil
        }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
}

extension AppleSignInService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion?(.failure(NSError(domain: "AppleSignIn", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Invalid Apple credential"
            ])))
            return
        }

        let userId = credential.user
        let email = credential.email

        let fullName: String? = {
            let parts = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        }()

        let identityToken = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        let result = AppleSignInResult(
            userId: userId,
            email: email,
            fullName: fullName,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            nonce: currentNonce
        )

        completion?(.success(result))
        completion = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion?(.failure(error))
        completion = nil
    }
}

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if canImport(UIKit)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
