//
//  PathManager.swift
//  Komalios
//
//  Navigation path manager for NavigationStack
//

import SwiftUI

@MainActor
class PathManager: ObservableObject {
    @Published var path: NavigationPath = NavigationPath()
    
    func push(_ route: Routes) {
        path.append(route)
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToRoot() {
        path = NavigationPath()
    }
}
