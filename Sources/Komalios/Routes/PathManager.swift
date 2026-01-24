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

class PathManager: ObservableObject {
    @Published var path = NavigationPath()
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
        // Look for an index where only the case (not the full value) matches
        guard let index = elements.firstIndex(where: { element in
            // Unwrap `AnyHashable` to check if it's `Routes`
            guard let route = element.base as? Routes, let targetRoute = value as? Routes else {
                return element == wrappedValue // Fallback to exact match
            }

            // Match all `tabBarView` cases regardless of associated value
//            if case .tabBarView = route, case .tabBarView = targetRoute {
//                return true
//            }
            return route == targetRoute
        }) else {
            print("Value not found in elements!")
            return
        }
        let countToRemove = elements.count - index - 1
        path.removeLast(countToRemove)
        elements.removeLast(countToRemove)
    }

    //MARK: - Reset the stack to root
    func popToRoot() {
        path = NavigationPath()
        elements.removeAll()
    }
}
