// MainTabView.swift
// Main tab interface with Content Filter and Chatbot

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentFilterView()
                .tabItem {
                    Label("Filter", systemImage: "shield.checkered")
                }
            
            ChatbotView()
                .tabItem {
                    Label("Chatbot", systemImage: "message.fill")
                }
        }
    }
}
