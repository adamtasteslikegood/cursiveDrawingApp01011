import Foundation

/// Deterministic synthetic probes, not recordings of a person's handwriting.
enum ScoringFixtures {
  static func cases(lesson: PracticeLesson, guide: WritingGuide) -> [(String, [[CGPoint]])] {
    let reference = lesson.referencePoints(in: guide)
    let minX = reference.map { $0.x }.min()!
    let maxX = reference.map { $0.x }.max()!
    let minY = reference.map { $0.y }.min()!
    let maxY = reference.map { $0.y }.max()!
    let zigzag = (0...40).map { index in
      CGPoint(
        x: minX + (maxX - minX) * CGFloat(index) / 40,
        y: index.isMultiple(of: 2) ? minY : maxY)
    }
    let noisyTrace = reference.enumerated().map { index, point in
      CGPoint(
        x: point.x + sin(Double(index) * 0.73) * guide.height * 0.02,
        y: point.y + cos(Double(index) * 0.91) * guide.height * 0.02)
    }
    let crosshatch = (0...12).map { row in
      let y = minY + (maxY - minY) * CGFloat(row) / 12
      return [CGPoint(x: minX, y: y), CGPoint(x: maxX, y: y)]
    }
    return [
      ("exact-model", [reference]), ("synthetic-2-percent-jitter", [noisyTrace]),
      ("unrelated-zigzag", [zigzag]), ("unrelated-crosshatch", crosshatch),
    ]
  }
}
