import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// Hand-authored prototype models, shared by the example, tracing guide, and practice comparison.
/// These are illustrative paths, not validated teacher handwriting or stroke-order instruction.
struct PracticeLesson: Identifiable, Equatable {
  let word: String
  let focus: String
  var set: Int = 1
  var id: String { word }
  static let revision = "Lesson prototype 1.2 · 2026-10-06"
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
    PracticeLesson(
      word: "hope", focus: "Use tall h, round o, a descending p, and a small e.", set: 2),
    PracticeLesson(
      word: "help", focus: "Keep e small; h and l reach the top, and p drops below the baseline.",
      set: 2),
    PracticeLesson(
      word: "peel", focus: "Connect the two small e loops before finishing with a tall l.", set: 2),
    PracticeLesson(
      word: "heel", focus: "Keep both e loops in the lower band between tall h and l.", set: 3),
    PracticeLesson(word: "hole", focus: "Join tall h to small o, then tall l to small e.", set: 3),
    PracticeLesson(
      word: "pole", focus: "Let p descend, keep o and e small, and raise l to the top.", set: 3),
  ]

  var primer: PrimerDescriptor { .prototype }

  var letters: [LessonLetterModel] {
    var offset: CGFloat = 0
    return word.enumerated().map { index, character in
      let glyph = ModelGlyph.glyph(character)
      let result = LessonLetterModel(
        id: index, letter: String(character),
        startX: offset, endX: offset + glyph.width,
        points: glyph.points.map { CGPoint(x: $0.x + offset, y: $0.y) })
      offset += glyph.width
      return result
    }
  }

  var modelPoints: [CGPoint] { letters.flatMap { $0.points } }

  var width: CGFloat { word.reduce(0) { $0 + ModelGlyph.glyph($1).width } }

  func referencePoints(in guide: WritingGuide) -> [CGPoint] {
    modelPoints.map {
      CGPoint(x: guide.originX + $0.x * guide.height, y: guide.top + $0.y * guide.height)
    }
  }
}

/// Identity travels with lesson models; no external curriculum assets are adopted.
struct PrimerDescriptor: Equatable {
  let id: String
  let name: String
  let revision: String
  let provenance: String
  static let prototype = PrimerDescriptor(
    id: "prototype-cursive", name: "Prototype primer",
    revision: "1", provenance: "Hand-authored project paths; educational review pending")
}

struct LessonLetterModel: Identifiable {
  let id: Int
  let letter: String
  let startX: CGFloat
  let endX: CGFloat
  let points: [CGPoint]
}

struct LetterPracticeFeedback: Codable, Identifiable {
  let id: Int
  let letter: String
  let shape: Double?
  let note: String
  let incomingJoin: JoinPracticeFeedback?
}

struct JoinPracticeFeedback: Codable {
  let combination: String
  let continuousInk: Bool
  let note: String
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
  var letters: [LetterPracticeFeedback]? = nil
  var primerID: String? = nil
  var primerRevision: String? = nil
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
        notes: ["Write the whole word before evaluating."],
        letters: lesson.letters.map {
          LetterPracticeFeedback(
            id: $0.id, letter: $0.letter,
            shape: nil, note: "Not enough ink to estimate this letter.", incomingJoin: nil)
        },
        primerID: lesson.primer.id, primerRevision: lesson.primer.revision)
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
      shape: shape, placement: placement, size: size, notes: notes,
      letters: letterFeedback(fitted: fitted, lesson: lesson, guide: guide),
      primerID: lesson.primer.id, primerRevision: lesson.primer.revision)
  }

  private static func letterFeedback(
    fitted: [[CGPoint]], lesson: PracticeLesson, guide: WritingGuide
  )
    -> [LetterPracticeFeedback]
  {
    let models = lesson.letters
    return models.map { model in
      let left = guide.originX + model.startX * guide.height
      let right = guide.originX + model.endX * guide.height
      let clipped = fitted.flatMap { LetterWindow.clip($0, left: left, right: right) }
      let actual = sample(clipped)
      let reference = sample([
        model.points.map {
          CGPoint(x: guide.originX + $0.x * guide.height, y: guide.top + $0.y * guide.height)
        }
      ])
      let hasInk = clipped.contains { stroke in
        zip(stroke, stroke.dropFirst()).contains {
          hypot($0.1.x - $0.0.x, $0.1.y - $0.0.y) > guide.height * 0.01
        }
      }
      let shape: Double? =
        hasInk
        ? clamp(
          100
            * (1 - max(
              0,
              (meanNearest(actual, reference) + meanNearest(reference, actual))
                / 2 / guide.height - 0.015) / 0.14)) : nil
      let note: String
      if let shape {
        note =
          shape >= 75
          ? "Ink follows this part of the model."
          : "Compare this letter's loops and height with the model; try its trace guide."
      } else {
        note = "Not enough ink in this expected region to estimate the letter."
      }
      let join: JoinPracticeFeedback?
      if model.id > 0 {
        let combination = models[model.id - 1].letter + model.letter
        let continuous = fitted.contains { stroke in
          LetterWindow.clip(
            stroke, left: left - guide.height * 0.10, right: left + guide.height * 0.10
          )
          .contains { piece in
            guard piece.contains(where: { $0.x < left - guide.height * 0.02 }),
              piece.contains(where: { $0.x > left + guide.height * 0.02 })
            else { return false }
            return zip(piece, piece.dropFirst()).contains { start, end in
              guard abs(end.x - start.x) > 0.0001 else { return false }
              let t = (left - start.x) / (end.x - start.x)
              guard t >= 0 && t <= 1 else { return false }
              let y = start.y + (end.y - start.y) * t
              return abs(y - guide.baseline) <= guide.height * 0.15
            }
          }
        }
        join = JoinPracticeFeedback(
          combination: combination, continuousInk: continuous,
          note: continuous
            ? "A recorded stroke crosses this model boundary near the baseline."
            : "No continuous stroke was found across this model boundary. An ink gap or pen lift may be intentional; inspect the example."
        )
      } else {
        join = nil
      }
      return LetterPracticeFeedback(
        id: model.id, letter: model.letter, shape: shape,
        note: note, incomingJoin: join)
    }
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

/// Clip actual polyline edges to model X windows without inventing ink across pen lifts.
struct LetterWindow {
  static func clip(_ stroke: [CGPoint], left: CGFloat, right: CGFloat) -> [[CGPoint]] {
    var pieces: [[CGPoint]] = []
    var current: [CGPoint] = []
    for (a, b) in zip(stroke, stroke.dropFirst()) {
      let dx = b.x - a.x
      var low: CGFloat = 0
      var high: CGFloat = 1
      if abs(dx) < 0.0001 {
        if a.x < left || a.x > right {
          if !current.isEmpty {
            pieces.append(current)
            current = []
          }
          continue
        }
      } else {
        let t1 = (left - a.x) / dx
        let t2 = (right - a.x) / dx
        low = max(0, min(t1, t2))
        high = min(1, max(t1, t2))
        if low > high {
          if !current.isEmpty {
            pieces.append(current)
            current = []
          }
          continue
        }
      }
      let start = CGPoint(x: a.x + dx * low, y: a.y + (b.y - a.y) * low)
      let end = CGPoint(x: a.x + dx * high, y: a.y + (b.y - a.y) * high)
      if let last = current.last, hypot(last.x - start.x, last.y - start.y) > 0.0001 {
        pieces.append(current)
        current = []
      }
      if current.isEmpty { current.append(start) }
      current.append(end)
    }
    if !current.isEmpty { pieces.append(current) }
    return pieces
  }
}
