# Let's add a lined paper background implementation file
import textwrap

lined_paper_swift = textwrap.dedent("""
import SwiftUI

struct LinedPaperBackground: View {
    let lineSpacing: CGFloat = 40
    let lineColor = Color.gray.opacity(0.3)
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                var y: CGFloat = 0
                while y < geometry.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    y += lineSpacing
                }
            }
            .stroke(lineColor, lineWidth: 1)
        }
    }
}
""")

# Update ContentView.swift to overlay lined paper in the WritingCanvas
content_view_with_lines = textwrap.dedent("""
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
            
            ZStack {
                LinedPaperBackground()
                WritingCanvas(canvasView: $canvasView)
            }
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
        canvasView.backgroundColor = .clear
        canvasView.allowsFingerDrawing = false
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
""")

# Write the new files into playground folder
with open(os.path.join(base_dir, "ContentView.swift"), "w") as f:
    f.write(content_view_with_lines)

with open(os.path.join(base_dir, "LinedPaperBackground.swift"), "w") as f:
    f.write(lined_paper_swift)

# Repackage zip
zip_path_with_lines = "/mnt/data/CursivePlaygroundWithLines.zip"
with zipfile.ZipFile(zip_path_with_lines, 'w') as zipf:
    for folder, _, files in os.walk(base_dir):
        for file in files:
            full_path = os.path.join(folder, file)
            rel_path = os.path.relpath(full_path, "/mnt/data")
            zipf.write(full_path, rel_path)

zip_path_with_lines