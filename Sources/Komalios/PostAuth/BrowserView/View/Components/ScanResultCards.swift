//
//  ScanResultCards.swift
//  Komalios
//
//  Created on 18/01/26.
//

import SwiftUI

// MARK: - Overall Score Card

struct OverallScoreCard: View {
    let result: ScanResponse
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Overall Safety Score")
                    .font(.headline)
                Spacer()
                ScoreBadge(score: result.overallScore)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(scoreColor(result.overallScore))
                        .frame(width: geometry.size.width * CGFloat(result.overallScore) / 100, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            Text("Scanned: \(result.url)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let method = result.analysisMethod {
                HStack {
                    Text(method == "live" ? "Live Analysis" : "Demo Mode")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(method == "live" ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .foregroundColor(method == "live" ? .green : .orange)
                        .cornerRadius(8)
                    
                    if result.childSafetyAnalysis.overallRisk == .dangerous {
                        Text("🚫 Blocked for under 16")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    func scoreColor(_ score: Int) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
}

struct ScoreBadge: View {
    let score: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(score)")
                .font(.title)
                .fontWeight(.bold)
            Text("/100")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(scoreColor(score).opacity(0.2))
        .foregroundColor(scoreColor(score))
        .cornerRadius(12)
    }
    
    func scoreColor(_ score: Int) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        return .red
    }
}

// MARK: - Age Group Actions Card

struct AgeGroupActionsCard: View {
    let ageGroupActions: [(ageGroup: String, action: Action, score: Int, reason: String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Age-Appropriate Actions")
                .font(.headline)
            
            ForEach(ageGroupActions, id: \.ageGroup) { item in
                AgeGroupActionRow(
                    ageGroup: item.ageGroup,
                    action: item.action,
                    score: item.score,
                    reason: item.reason
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct AgeGroupActionRow: View {
    let ageGroup: String
    let action: Action
    let score: Int
    let reason: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ageGroup)
                    .font(.headline)
                Spacer()
                ActionBadge(action: action)
            }
            
            HStack {
                Text("Score: \(score)/100")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text(reason)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding()
        .background(actionBackgroundColor(action).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(actionBorderColor(action), lineWidth: 2)
        )
    }
    
    func actionBackgroundColor(_ action: Action) -> Color {
        switch action {
        case .block: return .red
        case .gate: return .orange
        case .allow: return .green
        }
    }
    
    func actionBorderColor(_ action: Action) -> Color {
        switch action {
        case .block: return .red
        case .gate: return .orange
        case .allow: return .green
        }
    }
}

struct ActionBadge: View {
    let action: Action
    
    var body: some View {
        Text(action.rawValue)
            .font(.headline)
            .fontWeight(.bold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(actionColor(action))
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    func actionColor(_ action: Action) -> Color {
        switch action {
        case .block: return .red
        case .gate: return .orange
        case .allow: return .green
        }
    }
}

// MARK: - Risk Categories Card

struct RiskCategoriesCard: View {
    let riskCategories: [RiskCategory]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Safety Risks Detected")
                .font(.headline)
            
            ForEach(Array(riskCategories.enumerated()), id: \.offset) { index, risk in
                RiskCategoryRow(risk: risk)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct RiskCategoryRow: View {
    let risk: RiskCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SeverityBadge(severity: risk.severity)
                Text(risk.category)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("(\(risk.matchCount) matches)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !risk.matchedKeywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(risk.matchedKeywords.prefix(5), id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
    }
}

struct SeverityBadge: View {
    let severity: String
    
    var body: some View {
        Text(severity.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(severityColor(severity))
            .foregroundColor(.white)
            .cornerRadius(6)
    }
    
    func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "critical": return .red
        case "high": return .red.opacity(0.8)
        case "medium": return .orange
        case "low": return .yellow
        default: return .gray
        }
    }
}

// MARK: - Content Analysis Card

struct ContentAnalysisCard: View {
    let contentAnalysis: ContentAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content Analysis")
                .font(.headline)
            
            // NLP Text Analysis
            VStack(alignment: .leading, spacing: 8) {
                Text("NLP Text Analysis")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    Text("Sentiment:")
                        .foregroundColor(.secondary)
                    Text(contentAnalysis.textAnalysis.sentiment)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Language Score:")
                        .foregroundColor(.secondary)
                    Text("\(contentAnalysis.textAnalysis.languageScore)/100")
                        .fontWeight(.medium)
                }
                
                if !contentAnalysis.textAnalysis.keyTopics.isEmpty {
                    Text("Key Topics:")
                        .foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(contentAnalysis.textAnalysis.keyTopics.prefix(5), id: \.self) { topic in
                                Text(topic)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundColor(.purple)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
            
            // Vision Analysis
            if contentAnalysis.visualAnalysis.safetyScore > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vision AI Analysis")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text("Visual Safety Score:")
                            .foregroundColor(.secondary)
                        Text("\(contentAnalysis.visualAnalysis.safetyScore)/100")
                            .fontWeight(.medium)
                    }
                    
                    if !contentAnalysis.visualAnalysis.detectedObjects.isEmpty {
                        Text("Detected Objects:")
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(contentAnalysis.visualAnalysis.detectedObjects.prefix(5), id: \.self) { obj in
                                    Text(obj)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
