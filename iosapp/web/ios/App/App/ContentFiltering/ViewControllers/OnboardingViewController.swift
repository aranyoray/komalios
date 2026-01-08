//
//  OnboardingViewController.swift
//  Komal - Onboarding Flow
//
//  30-question parent onboarding survey
//

import UIKit
import SwiftUI

class OnboardingViewController: UIViewController {

    private let parentControl = ParentControlService.shared
    private var currentSection = 0
    private var answers: [String: Any] = [:]

    var onComplete: (() -> Void)?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Setup - Komal"

        // Use SwiftUI view for onboarding
        let onboardingView = OnboardingView { [weak self] responses in
            self?.handleCompletion(responses: responses)
        }

        let hostingController = UIHostingController(rootView: onboardingView)

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
    }

    // MARK: - Completion
    private func handleCompletion(responses: [String: Any]) {
        // Save responses
        answers = responses

        // Extract child age
        if let age = responses["child_age"] as? Int {
            parentControl.childAge = age
        }

        // Set up PIN
        showPINSetup()
    }

    private func showPINSetup() {
        let alert = UIAlertController(
            title: "Create Parent PIN",
            message: "Create a 4-digit PIN to protect parent settings",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "4-digit PIN"
            textField.keyboardType = .numberPad
            textField.isSecureTextEntry = true
        }

        alert.addTextField { textField in
            textField.placeholder = "Confirm PIN"
            textField.keyboardType = .numberPad
            textField.isSecureTextEntry = true
        }

        let createAction = UIAlertAction(title: "Create", style: .default) { [weak self, weak alert] _ in
            guard let pin1 = alert?.textFields?[0].text,
                  let pin2 = alert?.textFields?[1].text else { return }

            if pin1 == pin2 {
                do {
                    try self?.parentControl.setPIN(pin1)
                    self?.setupBiometrics()
                } catch {
                    self?.showError(error.localizedDescription)
                }
            } else {
                self?.showError("PINs don't match")
                self?.showPINSetup()
            }
        }

        alert.addAction(createAction)
        present(alert, animated: true)
    }

    private func setupBiometrics() {
        if parentControl.isBiometricsAvailable() {
            let alert = UIAlertController(
                title: "Enable Face ID/Touch ID?",
                message: "Use biometrics for faster access to parent controls",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "Enable", style: .default) { [weak self] _ in
                self?.parentControl.useBiometrics = true
                self?.finishOnboarding()
            })

            alert.addAction(UIAlertAction(title: "Skip", style: .cancel) { [weak self] _ in
                self?.finishOnboarding()
            })

            present(alert, animated: true)
        } else {
            finishOnboarding()
        }
    }

    private func finishOnboarding() {
        parentControl.isOnboardingCompleted = true
        parentControl.enableAutoCleanup()

        dismiss(animated: true) { [weak self] in
            self?.onComplete?()
        }
    }

    // MARK: - Helpers
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
