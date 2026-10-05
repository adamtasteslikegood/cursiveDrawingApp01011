import PencilKit
import SwiftUI
import Vision

struct ContentView: View {
  @State private var canvasView = PKCanvasView()
  @State private var toolPicker = PKToolPicker()
  @State private var recognizedText: String = ""
  @State private var feedback: String = ""
  @State private var isAnalyzing: Bool = false
  @State private var analysisReport: AnalysisReport?

  // Target phrase for the lesson
  private let targetPhrase = "loop"

  var body: some View {
    VStack {
      Text("Write in cursive: \(targetPhrase)")
        .font(.largeTitle)
        .padding()

      ZStack {
        LinedPaperBackground()

        WritingCanvas(canvasView: $canvasView, toolPicker: $toolPicker)
      }
      .frame(height: 400)
      .border(Color.gray, width: 1)
      .cornerRadius(8)
      .overlay(
        Group {
          if isAnalyzing {
            ProgressView("Analyzing...")
              .padding()
              .background(Color(.systemBackground).opacity(0.8))
              .cornerRadius(10)
          }
        }
      )
      .padding()

      HStack {
        Button(action: clearCanvas) {
          Label("Clear", systemImage: "trash")
            .foregroundColor(.red)
        }
        .padding()
        .disabled(isAnalyzing)

        Spacer()

        Button(action: evaluateDrawing) {
          Label("Evaluate", systemImage: "checkmark.circle.fill")
            .font(.headline)
        }
        .padding()
        .buttonStyle(.borderedProminent)
        .disabled(isAnalyzing)
      }
      .padding(.horizontal)

      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          if !recognizedText.isEmpty {
            Text("Recognized: \(recognizedText)")
              .font(.headline)
          }

          if let report = analysisReport {
            Text("Overall Score: \(Int(report.overallScore))/100")
              .font(.title2)
              .foregroundColor(scoreColor(report.overallScore))

            ForEach(report.letters, id: \.letter) { letter in
              VStack(alignment: .leading) {
                Text("Letter '\(letter.letter)': \(Int(letter.finalScore))%")
                  .font(.headline)

                ForEach(letter.notes, id: \.self) { note in
                  Text("• \(note)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
              }
              .padding(.vertical, 4)
              .padding(.horizontal)
              .background(Color(.secondarySystemBackground))
              .cornerRadius(8)
            }
          } else if !feedback.isEmpty {
            Text(feedback)
              .foregroundColor(.red)
          }
        }
        .padding()
      }

      Spacer()
    }
  }

  private func clearCanvas() {
    canvasView.drawing = PKDrawing()
    recognizedText = ""
    feedback = ""
    analysisReport = nil
  }

  private func evaluateDrawing() {
    guard !canvasView.drawing.strokes.isEmpty else {
      feedback = "Please write something first."
      return
    }

    isAnalyzing = true
    feedback = ""

    // Use the shared analyzer
    CursiveAnalyzer.shared.analyze(drawing: canvasView.drawing, targetText: targetPhrase) {
      result in
      isAnalyzing = false
      switch result {
      case .success(let report):
        self.analysisReport = report
        // Best guess at what was written based on the first letter report or overall logic
        // For this prototype, we just grab the recognized strings from segments if available
        // But the analyzer returns recognized text in segments.
        // We'll just display what the analyzer thought the letters were.
        let recognized = report.letters.map { $0.letter }.joined()
        self.recognizedText = recognized.isEmpty ? "(No text recognized)" : recognized

      case .failure(let error):
        self.feedback = "Analysis failed: \(error.localizedDescription)"
      }
    }
  }

  private func scoreColor(_ score: Double) -> Color {
    if score >= 80 { return .green }
    if score >= 50 { return .orange }
    return .red
  }
}

struct WritingCanvas: UIViewRepresentable {
  @Binding var canvasView: PKCanvasView
  @Binding var toolPicker: PKToolPicker

  func makeUIView(context: Context) -> PKCanvasView {
    canvasView.drawingPolicy = .anyInput
    canvasView.isOpaque = false
    canvasView.backgroundColor = .clear

    // Set default tool
    canvasView.tool = PKInkingTool(.pen, color: .black, width: 10)

    // Setup tool picker
    toolPicker.setVisible(true, forFirstResponder: canvasView)
    toolPicker.addObserver(canvasView)
    canvasView.becomeFirstResponder()

    return canvasView
  }

  func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
