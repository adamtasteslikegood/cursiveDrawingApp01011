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