import Foundation

/// Hand-authored prototype models, shared by the example, tracing guide, and practice comparison.
/// These are illustrative paths, not validated teacher handwriting or stroke-order instruction.
struct PracticeLesson: Identifiable, Equatable {
  let word: String
  let focus: String
  var id: String { word }
  static let revision = "Lesson prototype 1.1 · 2026-10-05"
  static let all = [
    PracticeLesson(
      word: "loop",
      focus: "Let l reach the top line. Keep o at the dashed line; p drops below the baseline."),
    PracticeLesson(
      word: "pool", focus: "Start with p, join the two round o letters, and finish with a tall l."),
    PracticeLesson(
      word: "hello",
      focus:
        "Let h and both l letters reach the top. Keep e and o between the dashed line and baseline."
    ),
  ]

  var modelPoints: [CGPoint] {
    var result: [CGPoint] = []
    var offset: CGFloat = 0
    for character in word {
      let glyph = ModelGlyph.glyph(character)
      result += glyph.points.map { CGPoint(x: $0.x + offset, y: $0.y) }
      offset += glyph.width
    }
    return result
  }

  var width: CGFloat { word.reduce(0) { $0 + ModelGlyph.glyph($1).width } }

  func referencePoints(in guide: WritingGuide) -> [CGPoint] {
    modelPoints.map {
      CGPoint(x: guide.originX + $0.x * guide.height, y: guide.top + $0.y * guide.height)
    }
  }
}

struct WritingGuide: Equatable {
  let top: CGFloat
  let baseline: CGFloat
  let originX: CGFloat
  var height: CGFloat { baseline - top }
  var middle: CGFloat { (top + baseline) / 2 }
  var descender: CGFloat { baseline + height * 0.35 }

  init(size: CGSize, wordWidth: CGFloat) {
    let height = max(1, min(size.height * 0.52, max(1, size.width - 64) / max(1, wordWidth)))
    top = (size.height - height * 1.35) / 2
    baseline = top + height
    originX = (size.width - wordWidth * height) / 2
  }
}

private struct ModelGlyph {
  let width: CGFloat
  let points: [CGPoint]

  /// Each cubic begins at the prior endpoint. All glyphs enter and exit on the baseline.
  static func glyph(_ letter: Character) -> ModelGlyph {
    switch letter {
    case "l":
      return make(
        0.65,
        [
          [0.15, 0.85, 0.58, 0.20, 0.40, 0.02],
          [0.12, -0.12, 0.12, 0.68, 0.30, 0.93],
          [0.38, 1.05, 0.55, 1.04, 0.65, 1.00],
        ])
    case "o":
      return make(
        0.80,
        [
          [0.18, 0.91, 0.25, 0.51, 0.47, 0.51],
          [0.17, 0.42, 0.11, 1.00, 0.39, 1.00],
          [0.67, 1.02, 0.68, 0.53, 0.47, 0.51],
          [0.48, 0.75, 0.65, 0.98, 0.80, 1.00],
        ])
    case "p":
      return make(
        0.85,
        [
          [0.12, 0.86, 0.22, 0.64, 0.27, 0.51],
          [0.23, 0.80, 0.14, 1.35, 0.20, 1.35],
          [0.27, 1.28, 0.24, 0.58, 0.48, 0.53],
          [0.80, 0.40, 0.78, 1.00, 0.43, 0.96],
          [0.55, 1.07, 0.72, 1.04, 0.85, 1.00],
        ])
    case "h":
      return make(
        0.90,
        [
          [0.16, 0.85, 0.54, 0.19, 0.38, 0.02],
          [0.13, -0.12, 0.16, 0.71, 0.26, 1.00],
          [0.30, 0.84, 0.43, 0.51, 0.57, 0.51],
          [0.77, 0.51, 0.59, 0.94, 0.73, 1.00],
          [0.79, 1.04, 0.84, 1.03, 0.90, 1.00],
        ])
    case "e":
      return make(
        0.65,
        [
          [0.18, 0.89, 0.49, 0.66, 0.37, 0.53],
          [0.17, 0.40, 0.07, 0.83, 0.27, 0.97],
          [0.37, 1.08, 0.53, 1.04, 0.65, 1.00],
        ])
    default:
      preconditionFailure("No prototype model for \(letter)")
    }
  }

  private static func make(_ width: CGFloat, _ curves: [[CGFloat]]) -> ModelGlyph {
    var points = [CGPoint(x: 0, y: 1)]
    for curve in curves {
      let start = points.last!
      let a = CGPoint(x: curve[0], y: curve[1])
      let b = CGPoint(x: curve[2], y: curve[3])
      let end = CGPoint(x: curve[4], y: curve[5])
      for step in 1...24 {
        let t = CGFloat(step) / 24
        let u = 1 - t
        points.append(
          CGPoint(
            x: u * u * u * start.x + 3 * u * u * t * a.x + 3 * u * t * t * b.x + t * t * t * end.x,
            y: u * u * u * start.y + 3 * u * u * t * a.y + 3 * u * t * t * b.y + t * t * t * end.y))
      }
    }
    return ModelGlyph(width: width, points: points)
  }
}

struct PracticeFeedback: Codable {
  let score: Double
  let shape: Double
  let placement: Double
  let size: Double
  let notes: [String]
}

/// Geometry-only practice feedback; does not infer speed, joins, stroke order, or educational mastery.
struct LessonScorer {
  static func evaluate(strokes: [[CGPoint]], lesson: PracticeLesson, guide: WritingGuide)
    -> PracticeFeedback
  {
    let ink = strokes.flatMap { $0 }
    let reference = lesson.referencePoints(in: guide)
    guard let inkBounds = bounds(ink), let referenceBounds = bounds(reference),
      inkBounds.width > 1, inkBounds.height > 1
    else {
      return PracticeFeedback(
        score: 0, shape: 0, placement: 0, size: 0,
        notes: ["Write the whole word before evaluating."])
    }
    // Uniform fitting keeps aspect ratio; translation and overall size are judged separately.
    let scale = min(
      referenceBounds.width / inkBounds.width, referenceBounds.height / inkBounds.height)
    let fitted = strokes.map { stroke in
      stroke.map {
        CGPoint(
          x: ($0.x - inkBounds.midX) * scale + referenceBounds.midX,
          y: ($0.y - inkBounds.midY) * scale + referenceBounds.midY)
      }
    }
    let a = sample(fitted)
    let b = sample([reference])
    let distance = (meanNearest(a, b) + meanNearest(b, a)) / 2 / guide.height
    // Ignore small resampling/pen-position differences (1.5% of the writing-band height).
    let shape = clamp(100 * (1 - max(0, distance - 0.015) / 0.24))
    let verticalOffset = abs(inkBounds.midY - referenceBounds.midY) / guide.height
    let placement = clamp(100 * (1 - max(0, verticalOffset - 0.10) / 0.50))
    let heightRatio = inkBounds.height / referenceBounds.height
    let sizeError = abs(log(Double(heightRatio)))
    let size = clamp(100 * (1 - max(0, sizeError - 0.20) / 0.90))
    var notes: [String] = []
    if shape < 75 {
      notes.append(
        "Compare the loops and letter order with the example; try tracing the guide once.")
    }
    if placement < 75 {
      notes.append(
        "Move the word into the highlighted band; small letters sit between the dashed line and baseline."
      )
    }
    if size < 75 {
      notes.append(
        heightRatio < 1
          ? "Make the word taller: tall letters reach the top solid line."
          : "Make the word smaller to fit the writing band; only p drops below the baseline.")
    }
    if notes.isEmpty {
      notes.append(
        "Your ink follows the example's shape, position, and size. Try again without the trace guide."
      )
    }
    return PracticeFeedback(
      score: shape * 0.60 + placement * 0.20 + size * 0.20,
      shape: shape, placement: placement, size: size, notes: notes)
  }

  private static func clamp(_ value: Double) -> Double { min(100, max(0, value)) }
  private static func bounds(_ points: [CGPoint]) -> CGRect? {
    guard let first = points.first else { return nil }
    var minX = first.x
    var maxX = first.x
    var minY = first.y
    var maxY = first.y
    for point in points {
      minX = min(minX, point.x)
      maxX = max(maxX, point.x)
      minY = min(minY, point.y)
      maxY = max(maxY, point.y)
    }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }
  private static func sample(_ strokes: [[CGPoint]]) -> [CGPoint] {
    let lengths = strokes.map { points in
      zip(points, points.dropFirst()).reduce(CGFloat(0)) {
        $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y)
      }
    }
    let total = lengths.reduce(0, +)
    guard total > 0 else { return strokes.compactMap { $0.first } }
    var result: [CGPoint] = []
    for (stroke, length) in zip(strokes, lengths) where !stroke.isEmpty {
      // Resample each actual stroke independently: never manufacture joins across pen lifts.
      var distances = [CGFloat(0)]
      for i in 1..<stroke.count {
        distances.append(
          distances.last! + hypot(stroke[i].x - stroke[i - 1].x, stroke[i].y - stroke[i - 1].y))
      }
      guard stroke.count > 1, length > 0 else {
        result.append(stroke[0])
        continue
      }
      let count = max(2, Int(256 * length / total))
      var index = 1
      for i in 0..<count {
        let target = length * CGFloat(i) / CGFloat(count - 1)
        while index < stroke.count - 1 && distances[index] < target { index += 1 }
        let span = distances[index] - distances[index - 1]
        let t = span > 0 ? (target - distances[index - 1]) / span : 0
        let start = stroke[index - 1]
        let end = stroke[index]
        result.append(
          CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t))
      }
    }
    // Bound nearest-neighbor work even for drawings containing many pen lifts.
    if result.count > 512 {
      return (0..<512).map { result[$0 * (result.count - 1) / 511] }
    }
    return result
  }
  private static func meanNearest(_ a: [CGPoint], _ b: [CGPoint]) -> Double {
    a.reduce(0) { sum, point in
      sum
        + b.reduce(Double.greatestFiniteMagnitude) { nearest, candidate in
          min(nearest, hypot(Double(point.x - candidate.x), Double(point.y - candidate.y)))
        }
    } / Double(a.count)
  }
}
