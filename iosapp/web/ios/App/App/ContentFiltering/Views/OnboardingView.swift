//
//  OnboardingView.swift
//  Komal - Onboarding SwiftUI View
//
//  30-question parent onboarding survey UI
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    let onComplete: ([String: Any]) -> Void

    init(onComplete: @escaping ([String: Any]) -> Void) {
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(onComplete: onComplete))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding()

                // Question content
                ScrollView {
                    VStack(spacing: 24) {
                        if let question = viewModel.currentQuestion {
                            QuestionView(
                                question: question,
                                answer: viewModel.answers[question.id] as? String ?? "",
                                onAnswer: { answer in
                                    viewModel.answerQuestion(answer)
                                }
                            )
                        }
                    }
                    .padding()
                }

                // Navigation buttons
                HStack(spacing: 16) {
                    if viewModel.canGoBack {
                        Button(action: viewModel.previousQuestion) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                    }

                    Button(action: viewModel.nextQuestion) {
                        HStack {
                            Text(viewModel.isLastQuestion ? "Complete" : "Next")
                            if !viewModel.isLastQuestion {
                                Image(systemName: "chevron.right")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.canProceed ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.canProceed)
                }
                .padding()
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Question View
struct QuestionView: View {
    let question: SurveyQuestion
    let answer: String
    let onAnswer: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question text
            Text(question.text)
                .font(.title3)
                .fontWeight(.semibold)

            if let subtitle = question.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Answer options
            switch question.type {
            case .multipleChoice:
                ForEach(question.options ?? [], id: \.self) { option in
                    OptionButton(
                        text: option,
                        isSelected: answer == option,
                        onTap: { onAnswer(option) }
                    )
                }

            case .text:
                TextField("Your answer", text: Binding(
                    get: { answer },
                    set: { onAnswer($0) }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.vertical, 8)

            case .number:
                TextField("Enter age", text: Binding(
                    get: { answer },
                    set: { onAnswer($0) }
                ))
                .keyboardType(.numberPad)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.vertical, 8)

            case .yesNo:
                HStack(spacing: 12) {
                    OptionButton(
                        text: "Yes",
                        isSelected: answer == "Yes",
                        onTap: { onAnswer("Yes") }
                    )
                    OptionButton(
                        text: "No",
                        isSelected: answer == "No",
                        onTap: { onAnswer("No") }
                    )
                }

            case .scale:
                VStack {
                    Text(answer.isEmpty ? "Select a value" : answer)
                        .font(.headline)
                        .foregroundColor(.blue)

                    if let max = question.scaleMax {
                        Slider(value: Binding(
                            get: { Double(answer) ?? 0 },
                            set: { onAnswer(String(Int($0))) }
                        ), in: 0...Double(max), step: 1)
                            .accentColor(.blue)

                        HStack {
                            Text("0")
                            Spacer()
                            Text("\(max)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)

            case .multiSelect:
                ForEach(question.options ?? [], id: \.self) { option in
                    CheckboxButton(
                        text: option,
                        isSelected: answer.components(separatedBy: ",").contains(option),
                        onTap: {
                            var selected = answer.components(separatedBy: ",").filter { !$0.isEmpty }
                            if selected.contains(option) {
                                selected.removeAll { $0 == option }
                            } else {
                                selected.append(option)
                            }
                            onAnswer(selected.joined(separator: ","))
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Option Button
struct OptionButton: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(text)
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Checkbox Button
struct CheckboxButton: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .secondary)
                Text(text)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - View Model
class OnboardingViewModel: ObservableObject {
    @Published var currentQuestionIndex = 0
    @Published var answers: [String: Any] = [:]
    @Published var progress: Double = 0.0

    private let survey = ParentOnboardingSurvey()
    private let onComplete: ([String: Any]) -> Void

    init(onComplete: @escaping ([String: Any]) -> Void) {
        self.onComplete = onComplete
        updateProgress()
    }

    var currentQuestion: SurveyQuestion? {
        guard currentQuestionIndex < survey.allQuestions.count else { return nil }
        return survey.allQuestions[currentQuestionIndex]
    }

    var canGoBack: Bool {
        currentQuestionIndex > 0
    }

    var canProceed: Bool {
        guard let question = currentQuestion else { return false }
        let answer = answers[question.id] as? String ?? ""
        return !answer.isEmpty
    }

    var isLastQuestion: Bool {
        currentQuestionIndex == survey.allQuestions.count - 1
    }

    func answerQuestion(_ answer: String) {
        guard let question = currentQuestion else { return }
        answers[question.id] = answer
    }

    func nextQuestion() {
        if isLastQuestion {
            completeOnboarding()
        } else {
            currentQuestionIndex += 1
            updateProgress()
        }
    }

    func previousQuestion() {
        if canGoBack {
            currentQuestionIndex -= 1
            updateProgress()
        }
    }

    private func updateProgress() {
        progress = Double(currentQuestionIndex) / Double(survey.allQuestions.count)
    }

    private func completeOnboarding() {
        onComplete(answers)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView { _ in }
    }
}
