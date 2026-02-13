//
//  AppDelegate.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//

import FirebaseCore
import FirebaseAnalytics
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    Analytics.setAnalyticsCollectionEnabled(true)
    return true
  }
}
