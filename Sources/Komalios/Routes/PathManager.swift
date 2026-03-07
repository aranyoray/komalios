//
//  PathManager.swift
//  Komalios
//
//  Created by Amit Kumar on 22/01/26.
//

import Foundation
import SwiftUI

enum Routes: Hashable {
    case loginView
    case rootView
    case onboardingView
    case settingView
    
}

@MainActor
class PathManager: ObservableObject {
    @Published var path = NavigationPath() {
        didSet {
            // Sync elements when NavigationPath changes externally (e.g. back gesture)
            if path.count < elements.count {
                elements.removeLast(elements.count - path.count)
            }
        }
    }
    private var elements: [AnyHashable] = []

    // MARK: - Push a new destination onto the stack
    func push<T: Hashable>(_ value: T) {
        path.append(value)
        elements.append(value)
    }

    // MARK: - Pop the last destination from the stack
    func pop() {
        guard !elements.isEmpty else { return }
        path.removeLast()
        elements.removeLast()
    }

    // MARK: - Pop to a specific destination
    func popTo<T: Hashable>(_ value: T) {
        let wrappedValue = AnyHashable(value)
        guard let index = elements.firstIndex(where: { element in
            guard let route = element.base as? Routes, let targetRoute = value as? Routes else {
                return element == wrappedValue
            }
            return route == targetRoute
        }) else {
            return
        }
        let countToRemove = elements.count - index - 1
        guard countToRemove > 0 else { return }
        path.removeLast(countToRemove)
        elements.removeLast(countToRemove)
    }

    //MARK: - Reset the stack to root
    func popToRoot() {
        path = NavigationPath()
        elements.removeAll()
    }
}
