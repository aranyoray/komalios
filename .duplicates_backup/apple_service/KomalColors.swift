//
//  KomalColors.swift
//  Komalios
//
//  Color palette for the Komal app
//

import SwiftUI

enum KomalColors {
    // Primary colors
    static let bubblegumPink = Color(red: 1.0, green: 0.4, blue: 0.7)
    static let skyBlue = Color(red: 0.53, green: 0.81, blue: 0.98)
    static let lavender = Color(red: 0.9, green: 0.73, blue: 0.99)
    static let mintGreen = Color(red: 0.6, green: 0.98, blue: 0.82)
    static let sunshineYellow = Color(red: 1.0, green: 0.93, blue: 0.5)
    
    // Neutrals
    static let white = Color.white
    static let softGray = Color(red: 0.95, green: 0.95, blue: 0.95)
    static let mediumGray = Color(red: 0.7, green: 0.7, blue: 0.7)
    static let darkGray = Color(red: 0.3, green: 0.3, blue: 0.3)
    
    // Text colors
    static let textPrimary = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let textSecondary = Color(red: 0.5, green: 0.5, blue: 0.5)
    static let textOnDark = Color.white
    
    // Status colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue
    
    // Background gradients
    static let gradientStart = lavender
    static let gradientEnd = skyBlue
}
