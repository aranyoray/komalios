//
//  AppleSignInViewModel.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//

import Foundation

@MainActor
final class AppleSignInViewModel: ObservableObject {
    @Published private(set) var state: AppleAuthState = .idle

    private let service: AppleSignInService

    init(service: AppleSignInService = AppleSignInService()) {
        self.service = service
    }

    func signIn() {
        state = .loading

        service.startSignIn(useNonce: true) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let payload):
                // If you have a backend:
                // send payload.identityToken + payload.nonce to server for verification,
                // then create your own session.
                self.state = .signedIn(
                    userId: payload.userId,
                    email: payload.email,
                    fullName: payload.fullName
                )

                // Debug
                // print("identityToken:", payload.identityToken ?? "nil")

            case .failure(let error):
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    func reset() {
        state = .idle
    }
}
