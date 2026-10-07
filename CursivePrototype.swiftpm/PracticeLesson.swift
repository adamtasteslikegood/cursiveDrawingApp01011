import Foundation

#if canImport(CoreGraphics)
  import CoreGraphics
#endif

/// One lesson pins the guide and profile used by rendering and assessment.
struct PracticeLesson: Identifiable, Equatable {
  let word: String
  let focus: String
  let set: Int
  let id: String
  let model: HandwritingGuide
  let profile: HandwritingGuide.Profile
  static let revision = "Lesson prototype 1.3 · 2026-10-07"
  static let all = lessons(in: GuideLibrary.prototype)

  init(
    word: String, focus: String, set: Int = 1, id: String? = nil,
    model: HandwritingGuide = GuideLibrary.prototype, profile: HandwritingGuide.Profile? = nil
  ) {
    self.word = word
    self.focus = focus
    self.set = set
    self.id = id ?? word
    self.model = model
    self.profile = profile ?? model.profiles[0]
  }

  static func lessons(in model: HandwritingGuide, profile: HandwritingGuide.Profile? = nil)
    -> [PracticeLesson]
  {
    model.lessons.map {
      PracticeLesson(
        word: $0.text, focus: $0.instruction, set: $0.set,
        id: $0.id, model: model, profile: profile)
    }
  }

  var primer: PrimerDescriptor {
    PrimerDescriptor(
      id: model.id, name: model.name, revision: model.revision, provenance: model.provenance.source)
  }

  var letters: [LessonLetterModel] {
    var offset: CGFloat = 0
    return word.enumerated().map { index, character in
      // Lessons and guide imports are validated before entering the engine.
      let glyph = model.glyph(String(character))!
      let result = LessonLetterModel(
        id: index, letter: String(character),
        startX: offset, endX: offset + glyph.advance,
        strokes: glyph.strokes.map { $0.points.map { CGPoint(x: $0.x + offset, y: $0.y) } })
      offset += glyph.advance
      return result
    }
  }

  var modelStrokes: [[CGPoint]] {
    var result: [[CGPoint]] = []
    var previous: String?
    for letter in letters {
      var strokes = letter.strokes
      if let previous, model.join(from: previous, to: letter.letter)?.mode == "continuous",
        !result.isEmpty
      {
        result[result.count - 1].append(contentsOf: strokes.removeFirst())
      }
      result.append(contentsOf: strokes)
      previous = letter.letter
    }
    return result
  }

  /// Flattened points are suitable for bounds/exports, never for drawing bridges between strokes.
  var modelPoints: [CGPoint] { modelStrokes.flatMap { $0 } }
  var width: CGFloat { word.reduce(0) { $0 + model.glyph(String($1))!.advance } }
  var showsDescender: Bool { modelPoints.contains { $0.y > 1.08 } }

  func referenceStrokes(in guide: WritingGuide) -> [[CGPoint]] {
    modelStrokes.map { stroke in
      stroke.map {
        CGPoint(x: guide.originX + $0.x * guide.height, y: guide.top + $0.y * guide.height)
      }
    }
  }

  func referencePoints(in guide: WritingGuide) -> [CGPoint] {
    referenceStrokes(in: guide).flatMap { $0 }
  }
}

struct PrimerDescriptor: Equatable {
  let id: String
  let name: String
  let revision: String
  let provenance: String
}

struct LessonLetterModel: Identifiable {
  let id: Int
  let letter: String
  let startX: CGFloat
  let endX: CGFloat
  let strokes: [[CGPoint]]
  var points: [CGPoint] { strokes.flatMap { $0 } }
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
  let lines: HandwritingGuide.Lines
  var height: CGFloat { baseline - top }
  var middle: CGFloat { top + height * lines.midline }
  var descender: CGFloat { top + height * lines.descender }

  init(
    size: CGSize, wordWidth: CGFloat, lines: HandwritingGuide.Lines = GuideLibrary.prototype.lines
  ) {
    self.lines = lines
    let height = max(
      1,
      min(
        size.height * min(0.52, 0.8 / lines.descender), max(1, size.width - 64) / max(1, wordWidth))
    )
    top = (size.height - height * lines.descender) / 2
    baseline = top + height
    originX = (size.width - wordWidth * height) / 2
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
  var profileID: String? = nil
  var assessmentAlgorithm: String? = nil
  var modelStyle: String? = nil
  var modelLanguage: String? = nil
}

/// Geometry-only practice feedback; does not infer speed, joins, stroke order, or educational mastery.
struct LessonScorer {
  static func evaluate(strokes: [[CGPoint]], lesson: PracticeLesson, guide: WritingGuide)
    -> PracticeFeedback
  {
    let ink = strokes.flatMap { $0 }
    let referenceStrokes = lesson.referenceStrokes(in: guide)
    let reference = referenceStrokes.flatMap { $0 }
    let parameters = lesson.profile.assessment
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
        primerID: lesson.primer.id, primerRevision: lesson.primer.revision,
        profileID: lesson.profile.id, assessmentAlgorithm: parameters.algorithm,
        modelStyle: lesson.model.style, modelLanguage: lesson.model.language)
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
    let b = sample(referenceStrokes)
    let distance = (meanNearest(a, b) + meanNearest(b, a)) / 2 / guide.height
    // The selected profile supplies geometry tolerances; these are not validated skill grades.
    let shape = clamp(
      100 * (1 - max(0, distance - parameters.shapeTolerance) / parameters.shapeFalloff))
    let verticalOffset = abs(inkBounds.midY - referenceBounds.midY) / guide.height
    let placement = clamp(
      100
        * (1 - max(0, Double(verticalOffset) - parameters.positionTolerance)
          / parameters.positionFalloff))
    let heightRatio = inkBounds.height / referenceBounds.height
    let sizeError = abs(log(Double(heightRatio)))
    let size = clamp(
      100 * (1 - max(0, sizeError - parameters.sizeTolerance) / parameters.sizeFalloff))
    var notes: [String] = []
    if shape < 75 {
      notes.append(
        "Compare the loops and letter order with the example; try tracing the guide once.")
    }
    if placement < 75 {
      notes.append(
        "Move your writing toward the example on the guide lines."
      )
    }
    if size < 75 {
      notes.append(
        heightRatio < 1
          ? "Make your writing taller to match the example."
          : "Make your writing smaller to match the example and its guide lines.")
    }
    if notes.isEmpty {
      notes.append(
        "The geometry score is high. Compare your actual letters with the example; this score cannot confirm the word is correct."
      )
    }
    return PracticeFeedback(
      score: shape * 0.60 + placement * 0.20 + size * 0.20,
      shape: shape, placement: placement, size: size, notes: notes,
      letters: letterFeedback(fitted: fitted, lesson: lesson, guide: guide),
      primerID: lesson.primer.id, primerRevision: lesson.primer.revision,
      profileID: lesson.profile.id, assessmentAlgorithm: parameters.algorithm,
      modelStyle: lesson.model.style, modelLanguage: lesson.model.language)
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
      let reference = sample(
        model.strokes.map { stroke in
          stroke.map {
            CGPoint(x: guide.originX + $0.x * guide.height, y: guide.top + $0.y * guide.height)
          }
        })
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
                / 2 / guide.height - lesson.profile.assessment.shapeTolerance)
              / lesson.profile.assessment.letterFalloff)) : nil
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
      if model.id > 0,
        lesson.model.join(from: models[model.id - 1].letter, to: model.letter)?.mode == "continuous"
      {
        let combination = models[model.id - 1].letter + model.letter
        let expectedY = guide.top + lesson.model.glyph(model.letter)!.entry.y * guide.height
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
              return abs(y - expectedY) <= guide.height * 0.15
            }
          }
        }
        join = JoinPracticeFeedback(
          combination: combination, continuousInk: continuous,
          note: continuous
            ? "A recorded stroke crosses this model boundary near the guide’s connection point."
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
