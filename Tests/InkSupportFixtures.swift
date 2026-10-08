import Foundation

/// Synthetic positives and negatives for v2, separate from the frozen v1 migration fixture.
enum InkSupportFixtures {
  static func jitter(_ strokes: [[CGPoint]], height: CGFloat) -> [[CGPoint]] {
    strokes.map { stroke in
      stroke.enumerated().map { index, point in
        CGPoint(
          x: point.x + sin(Double(index) * 0.73) * height * 0.02,
          y: point.y + cos(Double(index) * 0.91) * height * 0.02)
      }
    }
  }

  static func scribble(reference: [[CGPoint]], seed: UInt64) -> [[CGPoint]] {
    let points = reference.flatMap { $0 }
    let left = points.map { $0.x }.min()!
    let top = points.map { $0.y }.min()!
    let width = points.map { $0.x }.max()! - left
    let height = points.map { $0.y }.max()! - top
    var state = seed
    func unit() -> CGFloat {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return CGFloat(Double(state >> 11) / 9_007_199_254_740_992)
    }
    return [(0..<96).map { _ in CGPoint(x: left + unit() * width, y: top + unit() * height) }]
  }

  static func cases(lesson: PracticeLesson, guide: WritingGuide) -> [(String, [[CGPoint]])] {
    let reference = lesson.referenceStrokes(in: guide)
    let negatives = ScoringFixtures.cases(lesson: lesson, guide: guide).filter {
      $0.0.hasPrefix("unrelated-")
    }
    let crosshatch = negatives.first { $0.0 == "unrelated-crosshatch" }!.1
    return [
      ("exact-model", reference),
      ("synthetic-2-percent-jitter", jitter(reference, height: guide.height)),
      ("trace-plus-crosshatch", reference + crosshatch),
      ("seeded-scribble", scribble(reference: reference, seed: 42)),
      ("partial-model", reference.map { Array($0.prefix(max(2, $0.count / 2))) }),
      ("reverse-direction", reference.map { Array($0.reversed()) }),
      ("reverse-stroke-order", Array(reference.reversed())),
      ("double-trace", reference + reference),
    ] + negatives
  }
}
