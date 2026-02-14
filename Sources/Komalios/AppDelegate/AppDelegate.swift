//
//  AppDelegate.swift
//  Komalios
//
//  Created by Amit Kumar on 18/01/26.
//

#if os(iOS)
import FirebaseCore
import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}
#endif
