import Foundation

/// State transitions keep old scores from hiding errors during the next evaluation.
struct EvaluationState {
  var recognizedText = ""
  var feedback = ""
  var isAnalyzing = false
  var analysisReport: AnalysisReport?

  mutating func reset() { self = EvaluationState() }

  mutating func begin(hasInk: Bool) -> Bool {
    reset()
    guard hasInk else {
      feedback = "Please write something first."
      return false
    }
    isAnalyzing = true
    return true
  }

  mutating func finish(_ result: Result<AnalysisReport, Error>) {
    isAnalyzing = false
    switch result {
    case .success(let report):
      analysisReport = report
      let text = report.letters.compactMap { $0.recognizedLetter }.joined()
      recognizedText = text.isEmpty ? "(No text recognized)" : text
      feedback = ""
    case .failure(let error):
      analysisReport = nil
      recognizedText = ""
      feedback = "Analysis failed: \(error.localizedDescription)"
    }
  }
}

struct FeedbackRow: Identifiable {
  let id: Int
  let report: LetterReport
}

extension AnalysisReport {
  var rows: [FeedbackRow] {
    letters.enumerated().map { FeedbackRow(id: $0.offset, report: $0.element) }
  }
}
