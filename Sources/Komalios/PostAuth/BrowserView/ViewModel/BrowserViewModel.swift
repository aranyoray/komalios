//
//  BrowserViewModel.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//
import Combine
import Foundation

enum BrowserHandleState {
    case notRunning
    case loading
    case success
    case failure(String)
}
final class BrowserState: ObservableObject {
    @Published var urlString = "https://www.khanacademy.org"
    @Published var currentURL: URL?
    @Published var category: ContentCategory = .unknown
    @Published var blockReason: String = ""
    @Published var showGate = false
    @Published var showBlocked = false
    @Published var loading = false
    @Published var tabHistory: [URL] = []
    @Published var showPastTabs = false
    @Published var browserHandleState: BrowserHandleState = .notRunning

    func addToHistory(_ url: URL) {
        if !tabHistory.contains(url) {
            tabHistory.insert(url, at: 0)
            if tabHistory.count > 20 {
                tabHistory.removeLast()
            }
        }
    }
}
