// ContentFilterView.swift
// Content safety filter interface

import SwiftUI

struct ContentFilterView: View {
    @StateObject private var viewModel = ContentFilterViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Input Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Content to Analyze")
                            .font(.headline)
                        
                        TextEditor(text: $viewModel.inputText)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
                    // Domain (optional)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Domain (optional)")
                            .font(.headline)
                        
                        TextField("example.com", text: $viewModel.domain)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                    
                    // Age Group Selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Age Group")
                            .font(.headline)
                        
                        Picker("Age Group", selection: $viewModel.selectedAgeGroup) {
                            Text("<10").tag("below10")
                            Text("10-13").tag("10-13")
                            Text("13-16").tag("13-16")
                            Text("16-18").tag("16-18")
                            Text("18+").tag("adult")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    
                    // Analyze Button
                    Button(action: {
                        Task {
                            await viewModel.analyzeContent()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            }
                            Text(viewModel.isLoading ? "Analyzing..." : "Analyze Content")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isLoading ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isLoading || viewModel.inputText.isEmpty)
                    .padding(.horizontal)
                    
                    // Results Section
                    if let result = viewModel.result {
                        VStack(spacing: 15) {
                            Divider()
                            
                            // Action Badge
                            HStack {
                                Text("Verdict:")
                                    .font(.headline)
                                Spacer()
                                Text(result.action)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(actionColor(for: result.action))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            
                            // Confidence
                            HStack {
                                Text("Confidence:")
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(result.confidence * 100))%")
                                    .font(.title3)
                            }
                            .padding(.horizontal)
                            
                            // Categories
                            if !result.categories.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Categories Detected:")
                                        .font(.headline)
                                    
                                    ForEach(result.categories, id: \.self) { category in
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                            Text(category.capitalized)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                            
                            // Reason
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reason:")
                                    .font(.headline)
                                Text(result.reason)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            
                            // Details
                            if let details = result.details {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Analysis Details:")
                                        .font(.headline)
                                    
                                    if !details.major_categories.isEmpty {
                                        ForEach(Array(details.major_categories.sorted(by: { $0.value > $1.value })), id: \.key) { category, score in
                                            HStack {
                                                Text(category.capitalized)
                                                Spacer()
                                                Text("\(Int(score * 100))%")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    HStack {
                                        Text("Processing Time:")
                                        Spacer()
                                        Text(String(format: "%.1f ms", details.processing_time_ms))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Error Message
                    if let error = viewModel.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Error")
                                    .font(.headline)
                            }
                            Text(error)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("Content Filter")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            viewModel.inputText = "This is a test with violent content: fight, blood, weapons"
                        }) {
                            Label("Violence Example", systemImage: "figure.boxing")
                        }
                        
                        Button(action: {
                            viewModel.inputText = "Explicit adult content XXX porn nude photos"
                        }) {
                            Label("Explicit Example", systemImage: "eye.slash")
                        }
                        
                        Button(action: {
                            viewModel.inputText = "Safe educational content about science and nature"
                        }) {
                            Label("Safe Example", systemImage: "checkmark.shield")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private func actionColor(for action: String) -> Color {
        switch action.uppercased() {
        case "ALLOW":
            return .green
        case "GATE":
            return .orange
        case "BLOCK":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - ViewModel

@MainActor
class ContentFilterViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var domain: String = ""
    @Published var selectedAgeGroup: String = "10-13"
    @Published var isLoading: Bool = false
    @Published var result: KomalWebAPI.FilterResponse?
    @Published var errorMessage: String?
    
    private let api = KomalWebAPI(baseURL: "http://localhost:5000")
    
    func analyzeContent() async {
        isLoading = true
        errorMessage = nil
        result = nil
        
        do {
            let response = try await api.analyzeContent(
                inputText,
                ageGroup: selectedAgeGroup,
                domain: domain.isEmpty ? nil : domain
            )
            result = response
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
