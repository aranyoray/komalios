//
//  ProtectedBrowserViewController.swift
//  Komal - Protected Browser
//
//  Web browser with content filtering
//

import UIKit
import WebKit

class ProtectedBrowserViewController: UIViewController {

    private let browserService = BrowserService.shared
    private var webView: WKWebView!
    private var urlTextField: UITextField!
    private var progressView: UIProgressView!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground

        // URL bar
        let toolbar = UIView()
        toolbar.backgroundColor = .systemGray6
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        urlTextField = UITextField()
        urlTextField.placeholder = "Enter URL or search..."
        urlTextField.borderStyle = .roundedRect
        urlTextField.keyboardType = .URL
        urlTextField.autocapitalizationType = .none
        urlTextField.returnKeyType = .go
        urlTextField.delegate = self
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(urlTextField)

        let goButton = UIButton(type: .system)
        goButton.setTitle("Go", for: .normal)
        goButton.addTarget(self, action: #selector(goButtonTapped), for: .touchUpInside)
        goButton.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(goButton)

        // Progress bar
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)

        // WebView
        webView = browserService.createProtectedWebView(frame: .zero)
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        // Layout
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 56),

            urlTextField.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 16),
            urlTextField.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            urlTextField.trailingAnchor.constraint(equalTo: goButton.leadingAnchor, constant: -8),

            goButton.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -16),
            goButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            goButton.widthAnchor.constraint(equalToConstant: 60),

            progressView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Setup browser callbacks
        browserService.onContentBlocked = { [weak self] decision in
            self?.showBlockedAlert(decision: decision)
        }

        browserService.onContentGated = { [weak self] decision, callback in
            self?.showGatedAlert(decision: decision, callback: callback)
        }

        // Load home page
        loadHomePage()
    }

    private func setupObservers() {
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            progressView.progress = Float(webView.estimatedProgress)
            progressView.isHidden = webView.estimatedProgress >= 1.0
        } else if keyPath == "url" {
            urlTextField.text = webView.url?.absoluteString
        }
    }

    // MARK: - Navigation
    @objc private func goButtonTapped() {
        guard let text = urlTextField.text, !text.isEmpty else { return }
        navigateToURL(text)
    }

    private func navigateToURL(_ urlString: String) {
        var finalURL = urlString

        // Add https if needed
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if urlString.contains(".") {
                finalURL = "https://" + urlString
            } else {
                // Search query
                finalURL = "https://www.google.com/search?q=" + urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            }
        }

        browserService.navigate(to: finalURL)
    }

    private func loadHomePage() {
        browserService.navigate(to: "https://www.google.com")
    }

    // MARK: - Alerts
    private func showBlockedAlert(decision: FilterDecision) {
        let alert = UIAlertController(
            title: "Content Blocked",
            message: "\(decision.category.displayName) content was blocked for your safety.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showGatedAlert(decision: FilterDecision, callback: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "Parent Approval Needed",
            message: "This \(decision.category.displayName) content requires parent approval. Ask your parent to approve.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            callback(false)
        })

        alert.addAction(UIAlertAction(title: "Ask Parent", style: .default) { _ in
            // In a real app, this would send a notification to parent
            NotificationHelper.shared.notifyContentGated(category: decision.category, url: decision.reason ?? "")
            callback(false)
        })

        present(alert, animated: true)
    }

    deinit {
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
    }
}

// MARK: - UITextFieldDelegate
extension ProtectedBrowserViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        goButtonTapped()
        textField.resignFirstResponder()
        return true
    }
}
