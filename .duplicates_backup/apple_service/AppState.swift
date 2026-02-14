//
//  AppState.swift
//  Komalios
//
//  Global app state and user preferences
//

import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
    @Published var childName: String {
        didSet {
            UserDefaults.standard.set(childName, forKey: "childName")
        }
    }
    
    @Published var childAge: Int {
        didSet {
            UserDefaults.standard.set(childAge, forKey: "childAge")
        }
    }
    
    @Published var selectedCategories: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(selectedCategories), forKey: "selectedCategories")
        }
    }
    
    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.childName = UserDefaults.standard.string(forKey: "childName") ?? ""
        self.childAge = UserDefaults.standard.integer(forKey: "childAge")
        
        let categoriesArray = UserDefaults.standard.stringArray(forKey: "selectedCategories") ?? []
        self.selectedCategories = Set(categoriesArray)
    }
    
    func savePreferences() {
        hasCompletedOnboarding = true
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        childName = ""
        childAge = 0
        selectedCategories = []
    }
}
