import PencilKit
import SwiftUI
import Vision

struct ContentView: View {
  @State private var canvasView = PKCanvasView()
  @State private var toolPicker = PKToolPicker()
  @State private var evaluation = EvaluationState()

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
          if evaluation.isAnalyzing {
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
        .disabled(evaluation.isAnalyzing)

        Spacer()

        Button(action: evaluateDrawing) {
          Label("Evaluate", systemImage: "checkmark.circle.fill")
            .font(.headline)
        }
        .padding()
        .buttonStyle(.borderedProminent)
        .disabled(evaluation.isAnalyzing)
      }
      .padding(.horizontal)

      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          if !evaluation.recognizedText.isEmpty {
            Text("Recognized: \(evaluation.recognizedText)")
              .font(.headline)
          }

          if let report = evaluation.analysisReport {
            Text("Overall Score: \(Int(report.overallScore))/100")
              .font(.title2)
              .foregroundColor(scoreColor(report.overallScore))

            ForEach(report.rows) { row in
              let letter = row.report
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
          } else if !evaluation.feedback.isEmpty {
            Text(evaluation.feedback)
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
    evaluation.reset()
  }

  private func evaluateDrawing() {
    guard evaluation.begin(hasInk: !canvasView.drawing.strokes.isEmpty) else { return }
    CursiveAnalyzer.shared.analyze(drawing: canvasView.drawing, targetText: targetPhrase) {
      result in
      evaluation.finish(result)
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
