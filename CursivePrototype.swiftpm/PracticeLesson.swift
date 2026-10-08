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
  static let revision = "Lesson prototype 1.5 · 2026-10-08"
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
  var showsDescender: Bool { modelPoints.contains { $0.y > 1 + 0.000001 } }

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
  var inkNearModel: Double? = nil
  var modelCoverage: Double? = nil
  var excessLengthLimit: Double? = nil
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
    let usesInkSupport = parameters.algorithm == "geometry-v2"
    let independentPractice = parameters.algorithm == "geometry-v3"
    let scale: CGFloat
    if usesInkSupport || independentPractice {
      // Fit both extents with one least-squares scale. A little height variation must
      // not shrink a long, otherwise faithful trace across all its letter windows.
      scale =
        (referenceBounds.width * inkBounds.width + referenceBounds.height * inkBounds.height)
        / (inkBounds.width * inkBounds.width + inkBounds.height * inkBounds.height)
    } else {
      scale = min(
        referenceBounds.width / inkBounds.width, referenceBounds.height / inkBounds.height)
    }
    var fitted = strokes.map { stroke in
      stroke.map {
        CGPoint(
          x: ($0.x - inkBounds.midX) * scale + referenceBounds.midX,
          y: ($0.y - inkBounds.midY) * scale + referenceBounds.midY)
      }
    }
    var support: (ink: Double, model: Double)?
    if usesInkSupport {
      // Validated v2 profiles supply this distance in writing-band heights.
      let refined = refineFit(
        fitted, reference: referenceStrokes, tolerance: guide.height * parameters.matchTolerance!)
      fitted = refined.strokes
      support = (refined.ink, refined.model)
    }
    let a = sample(fitted)
    let b = sample(referenceStrokes)
    let distance = (meanNearest(a, b) + meanNearest(b, a)) / 2 / guide.height
    // The selected profile supplies geometry tolerances; these are not validated skill grades.
    var shape = clamp(
      100 * (1 - max(0, distance - parameters.shapeTolerance) / parameters.shapeFalloff))
    var excessLengthLimit: Double?
    if independentPractice {
      let form = practiceForm(fitted, reference: referenceStrokes, height: guide.height)
      // Grade sustained shape differences, not near-exact coverage of the trace.
      let allowance = parameters.shapeTolerance + parameters.shapeFalloff / 4
      shape = min(
        shape, clamp(100 * (1 - max(0, form.deviation - allowance) / parameters.shapeFalloff)))
      excessLengthLimit = 100 / (1 + max(0, form.lengthRatio - parameters.lengthAllowance!))
    }
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
    if let limit = excessLengthLimit, limit < 95 {
      notes.append(
        "There is much more pen travel than this word needs. Extra ink limits this attempt to \(Int(limit.rounded()))/100; try one clear attempt."
      )
    }
    if let support {
      if support.ink < 0.75 {
        notes.append("Much of the ink is away from the example. Clear and try following its paths.")
      }
      if support.model < 0.75 {
        notes.append("Parts of the example are missing from your trace. Try completing its paths.")
      }
    }
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
    let score: Double
    if independentPractice {
      // Good position/height cannot provide points independently of the letter forms.
      score = min(shape * (0.60 + placement * 0.002 + size * 0.002), excessLengthLimit!)
    } else {
      score =
        (shape * 0.60 + placement * 0.20 + size * 0.20)
        * (support?.ink ?? 1) * (support?.model ?? 1)
    }
    return PracticeFeedback(
      score: score,
      shape: shape, placement: placement, size: size, notes: notes,
      letters: letterFeedback(fitted: fitted, lesson: lesson, guide: guide),
      primerID: lesson.primer.id, primerRevision: lesson.primer.revision,
      profileID: lesson.profile.id, assessmentAlgorithm: parameters.algorithm,
      modelStyle: lesson.model.style, modelLanguage: lesson.model.language,
      inkNearModel: support.map { $0.ink * 100 }, modelCoverage: support.map { $0.model * 100 },
      excessLengthLimit: excessLengthLimit)
  }

  /// Compare the most different fifth of each path after a global fit. Distances are
  /// continuous, guide-relative measurements; no trace-coverage percentage enters v3.
  private static func practiceForm(
    _ ink: [[CGPoint]], reference: [[CGPoint]], height: CGFloat
  ) -> (deviation: Double, lengthRatio: Double) {
    let actual = edges(ink)
    let expected = edges(reference)
    guard !actual.isEmpty, !expected.isEmpty else { return (.infinity, .infinity) }
    func tail(_ source: [InkEdge], near target: EdgeIndex) -> Double {
      let total = source.reduce(CGFloat(0)) { $0 + $1.length }
      var index = 0
      var consumed: CGFloat = 0
      var distances: [Double] = []
      for sample in 0..<512 {
        let distance = total * (CGFloat(sample) + 0.5) / 512
        while index < source.count - 1 && consumed + source[index].length < distance {
          consumed += source[index].length
          index += 1
        }
        let edge = source[index]
        let point = edge.point(at: (distance - consumed) / edge.length)
        distances.append(Double(target.nearest(to: point).distance / height))
      }
      let largest = distances.sorted(by: >).prefix(103)
      return largest.reduce(0, +) / Double(largest.count)
    }
    return (
      max(tail(actual, near: EdgeIndex(expected)), tail(expected, near: EdgeIndex(actual))),
      Double(
        actual.reduce(CGFloat(0)) { $0 + $1.length }
          / expected.reduce(CGFloat(0)) { $0 + $1.length })
    )
  }

  private struct InkEdge {
    let start: CGPoint
    let dx: CGFloat
    let dy: CGFloat
    let length: CGFloat

    init(_ start: CGPoint, _ end: CGPoint) {
      self.start = start
      dx = end.x - start.x
      dy = end.y - start.y
      length = hypot(dx, dy)
    }

    func point(at fraction: CGFloat) -> CGPoint {
      CGPoint(x: start.x + dx * fraction, y: start.y + dy * fraction)
    }

    func nearestPoint(to point: CGPoint) -> CGPoint {
      let fraction = max(
        0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / (length * length)))
      return self.point(at: fraction)
    }

  }

  /// A balanced bounding-box tree preserves every segment while pruning distant edges.
  /// It never downsamples a path or inserts a chord across visible ink or an erased gap.
  private final class EdgeIndex {
    struct Entry {
      let id: Int
      let edge: InkEdge
    }

    final class Node {
      let minX: CGFloat
      let minY: CGFloat
      let maxX: CGFloat
      let maxY: CGFloat
      let entries: [Entry]
      let left: Node?
      let right: Node?

      init(_ entries: [Entry]) {
        minX = entries.map { min($0.edge.start.x, $0.edge.point(at: 1).x) }.min()!
        minY = entries.map { min($0.edge.start.y, $0.edge.point(at: 1).y) }.min()!
        maxX = entries.map { max($0.edge.start.x, $0.edge.point(at: 1).x) }.max()!
        maxY = entries.map { max($0.edge.start.y, $0.edge.point(at: 1).y) }.max()!
        if entries.count <= 8 {
          self.entries = entries
          left = nil
          right = nil
        } else {
          self.entries = []
          let horizontal = maxX - minX >= maxY - minY
          let ordered = entries.sorted { a, b in
            let first = horizontal ? a.edge.start.x + a.edge.dx / 2 : a.edge.start.y + a.edge.dy / 2
            let second =
              horizontal ? b.edge.start.x + b.edge.dx / 2 : b.edge.start.y + b.edge.dy / 2
            return first == second ? a.id < b.id : first < second
          }
          let middle = ordered.count / 2
          left = Node(Array(ordered[..<middle]))
          right = Node(Array(ordered[middle...]))
        }
      }

      func distance(to point: CGPoint) -> CGFloat {
        let x = max(0, max(minX - point.x, point.x - maxX))
        let y = max(0, max(minY - point.y, point.y - maxY))
        return hypot(x, y)
      }
    }

    let root: Node?

    init(_ edges: [InkEdge]) {
      let entries = edges.enumerated().map { Entry(id: $0.offset, edge: $0.element) }
      root = entries.isEmpty ? nil : Node(entries)
    }

    func nearest(to point: CGPoint, limit: CGFloat = .infinity)
      -> (point: CGPoint?, distance: CGFloat, comparisons: Int)
    {
      guard let root else { return (nil, limit, 0) }
      var pending = [root]
      var closest: CGPoint?
      var distance = limit
      var firstID = Int.max
      var comparisons = 0
      while let node = pending.popLast() {
        guard node.distance(to: point) <= distance else { continue }
        for entry in node.entries {
          comparisons += 1
          let nearby = entry.edge.nearestPoint(to: point)
          let next = hypot(nearby.x - point.x, nearby.y - point.y)
          if next < distance || (next == distance && entry.id < firstID) {
            closest = nearby
            distance = next
            firstID = entry.id
          }
        }
        if let left = node.left, let right = node.right {
          // Visit the nearer bounds first so its result can prune the other subtree.
          if left.distance(to: point) <= right.distance(to: point) {
            pending.append(right)
            pending.append(left)
          } else {
            pending.append(left)
            pending.append(right)
          }
        }
      }
      return (closest, distance, comparisons)
    }
  }

  private static func edges(_ paths: [[CGPoint]]) -> [InkEdge] {
    paths.flatMap { stroke in
      zip(stroke, stroke.dropFirst()).map { InkEdge($0.0, $0.1) }.filter { $0.length > 0 }
    }
  }

  /// Refine translation without changing scale, rotation or stroke identity. Accept a
  /// candidate only when neither ink support nor model coverage gets worse and at least
  /// one improves: extra ink must not pull an already complete trace away from the model.
  private static func refineFit(
    _ initial: [[CGPoint]], reference: [[CGPoint]], tolerance: CGFloat
  ) -> (strokes: [[CGPoint]], ink: Double, model: Double) {
    let expected = edges(reference)
    let expectedIndex = EdgeIndex(expected)
    var candidate = initial
    var best = initial
    var support = pathSupport(
      ink: initial, expected: expected, expectedIndex: expectedIndex, tolerance: tolerance)
    guard !expected.isEmpty, !edges(initial).isEmpty else {
      return (best, support.ink, support.model)
    }
    for _ in 0..<5 {
      let points = sample(candidate)
      var x: CGFloat = 0
      var y: CGFloat = 0
      for point in points {
        let closest = expectedIndex.nearest(to: point).point ?? point
        x += closest.x - point.x
        y += closest.y - point.y
      }
      x /= CGFloat(points.count)
      y /= CGFloat(points.count)
      if hypot(x, y) < tolerance * 0.0001 { break }
      candidate = candidate.map { $0.map { CGPoint(x: $0.x + x, y: $0.y + y) } }
      let next = pathSupport(
        ink: candidate, expected: expected, expectedIndex: expectedIndex, tolerance: tolerance)
      if next.ink >= support.ink && next.model >= support.model
        && (next.ink > support.ink || next.model > support.model)
      {
        best = candidate
        support = next
      }
    }
    return (best, support.ink, support.model)
  }

  /// Arc-length support against actual polyline segments, never edges across pen lifts.
  /// Sampling is bounded and counts travel uniformly; it does not grade direction/order.
  private static func pathSupport(
    ink: [[CGPoint]], expected: [InkEdge], expectedIndex: EdgeIndex, tolerance: CGFloat
  ) -> (ink: Double, model: Double) {
    let actual = edges(ink)
    guard !actual.isEmpty, !expected.isEmpty else { return (0, 0) }
    let actualIndex = EdgeIndex(actual)

    func fraction(_ source: [InkEdge], near target: EdgeIndex) -> Double {
      let total = source.reduce(CGFloat(0)) { $0 + $1.length }
      let count = 512
      var index = 0
      var consumed: CGFloat = 0
      var matched = 0.0
      for sample in 0..<count {
        let distance = total * (CGFloat(sample) + 0.5) / CGFloat(count)
        while index < source.count - 1 && consumed + source[index].length < distance {
          consumed += source[index].length
          index += 1
        }
        let edge = source[index]
        let point = edge.point(at: (distance - consumed) / edge.length)
        let nearest = target.nearest(to: point, limit: tolerance)
        // Full support inside half the tolerance, falling smoothly to zero at its edge.
        matched += Double(max(0, min(1, 2 * (1 - nearest.distance / tolerance))))
      }
      return Double(matched) / Double(count)
    }
    return (fraction(actual, near: expectedIndex), fraction(expected, near: actualIndex))
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
