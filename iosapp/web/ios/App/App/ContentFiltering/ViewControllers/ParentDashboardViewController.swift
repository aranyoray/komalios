//
//  ParentDashboardViewController.swift
//  Komal - Parent Dashboard
//
//  Main parent control panel with statistics and settings
//

import UIKit
import LocalAuthentication
import SwiftUI

class ParentDashboardViewController: UIViewController {

    private let parentControl = ParentControlService.shared
    private let filterService = ContentFilterService.shared
    private let logger = ContentLogger.shared

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        authenticateParent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshStats()
    }

    // MARK: - Authentication
    private func authenticateParent() {
        if parentControl.useBiometrics && parentControl.isBiometricsAvailable() {
            parentControl.authenticateWithBiometrics { [weak self] success, error in
                if !success {
                    self?.showPINEntry()
                }
            }
        } else {
            showPINEntry()
        }
    }

    private func showPINEntry() {
        let alert = UIAlertController(
            title: "Parent Access",
            message: "Enter your 4-digit PIN",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "PIN"
            textField.keyboardType = .numberPad
            textField.isSecureTextEntry = true
        }

        let submitAction = UIAlertAction(title: "Submit", style: .default) { [weak self, weak alert] _ in
            guard let pin = alert?.textFields?[0].text else { return }

            if self?.parentControl.validatePIN(pin) == true {
                // Authenticated
                self?.setupUI()
            } else {
                self?.showError("Invalid PIN")
                self?.showPINEntry()
            }
        }

        alert.addAction(submitAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true)
        })

        present(alert, animated: true)
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Parent Dashboard"

        // Use SwiftUI view for modern UI
        let dashboardView = ParentDashboardView()
        let hostingController = UIHostingController(rootView: dashboardView)

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
    }

    private func refreshStats() {
        // Stats automatically refresh via SwiftUI
    }

    // MARK: - Helpers
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
