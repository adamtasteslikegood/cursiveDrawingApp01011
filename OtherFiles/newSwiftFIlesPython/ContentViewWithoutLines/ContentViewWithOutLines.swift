import SwiftUI
import PencilKit
import Vision

struct ContentView: View {
    @State private var canvasView = PKCanvasView()
    @State private var recognizedText: String = ""
    @State private var feedback: String = ""

    private let targetPhrase = "loop"

    var body: some View {
        VStack {
            Text("Write in cursive: \\(targetPhrase)")
                .font(.title)
                .padding()

            WritingCanvas(canvasView: $canvasView)
                .frame(height: 300)
                .border(Color.gray, width: 1)
                .padding()

            HStack {
                Button("Clear") {
                    canvasView.drawing = PKDrawing()
                    recognizedText = ""
                    feedback = ""
                }
                Spacer()
                Button("Evaluate") {
                    evaluateDrawing()
                }
            }
            .padding()

            Text("Recognized: \\(recognizedText)")
                .font(.headline)
                .padding(.top)

            Text("Feedback: \\(feedback)")
                .foregroundColor(.blue)
                .padding(.top)

            Spacer()
        }
        .padding()
    }

    private func drawingToImage() -> UIImage {
        let imageBounds = canvasView.drawing.bounds
        return canvasView.drawing.image(from: imageBounds, scale: 2.0)
    }

    private func evaluateDrawing() {
        let image = drawingToImage()

        recognizeHandwriting(from: image) { recognized in
            DispatchQueue.main.async {
                self.recognizedText = recognized

                let textScore = compareText(targetPhrase, recognized)
                let strokeMetrics = CursiveAnalyzer.analyzeStrokes(self.canvasView.drawing)

                self.feedback = \"\"\"
                Text match: \\(Int(textScore * 100))%
                Avg slant: \\(String(format: "%.1f", strokeMetrics.slantAngle))°
                Baseline error: \\(String(format: "%.1f", strokeMetrics.baselineError)) pts
                \"\"\"
            }
        }
    }

    private func recognizeHandwriting(from image: UIImage, completion: @escaping (String) -> Void) {
        let request = VNRecognizeTextRequest { request, _ in
            let recognized = request.results?
                .compactMap { ($0 as? VNRecognizedTextObservation)?.topCandidates(1).first?.string }
                .joined(separator: " ") ?? ""
            completion(recognized)
        }
        request.recognitionLanguages = ["en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        guard let cgImage = image.cgImage else { return }
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try? handler.perform([request])
    }

    private func compareText(_ target: String, _ student: String) -> Double {
        let distance = CursiveAnalyzer.levenshtein(target.lowercased(), student.lowercased())
        let maxLen = max(target.count, student.count)
        return maxLen > 0 ? 1.0 - (Double(distance) / Double(maxLen)) : 0
    }
}

struct WritingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.allowsFingerDrawing = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}