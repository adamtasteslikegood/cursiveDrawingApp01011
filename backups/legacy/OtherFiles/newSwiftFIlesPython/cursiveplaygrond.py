import os, textwrap, zipfile, pathlib

# Create playground-like structure in a zip file
base_dir = "/mnt/data/CursivePlayground.playground"
sources_dir = os.path.join(base_dir, "Sources")
os.makedirs(sources_dir, exist_ok=True)

# Content of MyPlayground.swift (entry point)
main_swift = textwrap.dedent("""
import SwiftUI
import PlaygroundSupport

PlaygroundPage.current.setLiveView(ContentView())
""")

# Content of ContentView.swift (prototype UI)
content_view_swift = textwrap.dedent("""
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
""")

# Content of CursiveAnalyzer.swift
cursive_analyzer_swift = textwrap.dedent("""
import Foundation
import PencilKit
import CoreGraphics

struct CursiveAnalyzer {
    static func analyzeStrokes(_ drawing: PKDrawing) -> (slantAngle: Double, baselineError: Double) {
        var angles: [Double] = []
        var yOffsets: [CGFloat] = []
        
        for stroke in drawing.strokes {
            let points = stroke.path.flatMap { $0.points }
            for i in 1..<points.count {
                let dx = points[i].location.x - points[i-1].location.x
                let dy = points[i].location.y - points[i-1].location.y
                if dx != 0 {
                    let angle = atan2(dy, dx) * 180 / .pi
                    angles.append(angle)
                }
                yOffsets.append(points[i].location.y)
            }
        }
        
        let avgAngle = angles.isEmpty ? 0 : angles.reduce(0, +) / Double(angles.count)
        let baselineY = yOffsets.isEmpty ? 0 : Double(yOffsets.min() ?? 0)
        let avgBaselineError = yOffsets.isEmpty ? 0 : yOffsets.map { abs(Double($0) - baselineY) }.reduce(0, +) / Double(yOffsets.count)
        
        return (avgAngle, avgBaselineError)
    }
    
    static func levenshtein(_ s: String, _ t: String) -> Int {
        let m = Array(s)
        let n = Array(t)
        var dist = [[Int]](repeating: [Int](repeating: 0, count: n.count + 1), count: m.count + 1)
        
        for i in 0...m.count { dist[i][0] = i }
        for j in 0...n.count { dist[0][j] = j }
        
        for i in 1...m.count {
            for j in 1...n.count {
                if m[i-1] == n[j-1] {
                    dist[i][j] = dist[i-1][j-1]
                } else {
                    dist[i][j] = min(dist[i-1][j-1], dist[i][j-1], dist[i-1][j]) + 1
                }
            }
        }
        return dist[m.count][n.count]
    }
}
""")

# Write files
with open(os.path.join(base_dir, "MyPlayground.swift"), "w") as f:
    f.write(main_swift)
with open(os.path.join(base_dir, "ContentView.swift"), "w") as f:
    f.write(content_view_swift)
with open(os.path.join(sources_dir, "CursiveAnalyzer.swift"), "w") as f:
    f.write(cursive_analyzer_swift)

# Package as zip for download
zip_path = "/mnt/data/CursivePlayground.zip"
with zipfile.ZipFile(zip_path, 'w') as zipf:
    for folder, _, files in os.walk(base_dir):
        for file in files:
            full_path = os.path.join(folder, file)
            rel_path = os.path.relpath(full_path, "/mnt/data")
            zipf.write(full_path, rel_path)

zip_path