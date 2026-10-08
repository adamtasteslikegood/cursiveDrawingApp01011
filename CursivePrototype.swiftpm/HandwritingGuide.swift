import Foundation

/// Versioned, local guide data. Decoding is followed by capability and geometry validation.
/// Coordinates use top = 0, baseline = 1 and one glyph advance on the X axis.
struct HandwritingGuide: Codable, Equatable, Identifiable {
  let schemaVersion: Int
  let id: String
  let name: String
  let revision: String
  let style: String
  let language: String
  let script: String
  let direction: String
  let reviewStatus: String
  let provenance: Provenance
  let lines: Lines
  let profiles: [Profile]
  let glyphs: [Glyph]
  let joins: [Join]
  let lessons: [Lesson]

  struct Provenance: Codable, Equatable {
    let author: String
    let license: String
    let source: String
    let instructionalReference: String
    let reviewNotes: String
  }

  struct Lines: Codable, Equatable {
    let midline: Double
    let descender: Double
    let topLabel: String
    let middleLabel: String
    let baselineLabel: String
  }

  struct Profile: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let instruction: String
    let assessment: Assessment
  }

  struct Assessment: Codable, Equatable {
    let algorithm: String
    let shapeTolerance: Double
    let shapeFalloff: Double
    let letterFalloff: Double
    let positionTolerance: Double
    let positionFalloff: Double
    let sizeTolerance: Double
    let sizeFalloff: Double
    let matchTolerance: Double?
  }

  struct Point: Codable, Equatable {
    let x: Double
    let y: Double
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
  }

  struct Curve: Codable, Equatable {
    let control1: Point
    let control2: Point
    let end: Point
  }

  struct Stroke: Codable, Equatable {
    let start: Point
    let curves: [Curve]
    var points: [CGPoint] {
      var result = [start.cgPoint]
      for curve in curves {
        let origin = result.last!
        let a = curve.control1.cgPoint
        let b = curve.control2.cgPoint
        let end = curve.end.cgPoint
        for step in 1...24 {
          let t = CGFloat(step) / 24
          let u = 1 - t
          result.append(
            CGPoint(
              x: u * u * u * origin.x + 3 * u * u * t * a.x + 3 * u * t * t * b.x + t * t * t
                * end.x,
              y: u * u * u * origin.y + 3 * u * u * t * a.y + 3 * u * t * t * b.y + t * t * t
                * end.y))
        }
      }
      return result
    }
  }

  struct Glyph: Codable, Equatable {
    let symbol: String
    let advance: Double
    let strokes: [Stroke]
    let entry: Point
    let exit: Point
    let instruction: String
  }

  struct Join: Codable, Equatable {
    let left: String
    let right: String
    let mode: String
  }

  struct Lesson: Codable, Equatable, Identifiable {
    let id: String
    let text: String
    let set: Int
    let instruction: String
  }

  struct Invalid: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
  }

  static let maximumBytes = 1_048_576

  static func decode(_ data: Data) throws -> HandwritingGuide {
    guard data.count <= maximumBytes else { throw Invalid(reason: "Guide exceeds the 1 MB limit.") }
    let guide: HandwritingGuide
    do { guide = try JSONDecoder().decode(Self.self, from: data) } catch {
      throw Invalid(reason: "Guide JSON is incomplete or has an invalid field type.")
    }
    // Fail closed on misspelled or future semantic fields instead of ignoring their rules.
    let original = try JSONSerialization.jsonObject(with: data)
    let known = try JSONSerialization.jsonObject(with: JSONEncoder().encode(guide))
    try rejectUnknownFields(original, known: known, path: "guide")
    try guide.validate()
    return guide
  }

  private static func rejectUnknownFields(_ original: Any, known: Any, path: String) throws {
    if let fields = original as? [String: Any], let allowed = known as? [String: Any] {
      for (key, value) in fields {
        guard let expected = allowed[key] else {
          throw Invalid(reason: "Unsupported field: \(path).\(key).")
        }
        try rejectUnknownFields(value, known: expected, path: "\(path).\(key)")
      }
    } else if let values = original as? [Any], let expected = known as? [Any] {
      for (index, pair) in zip(values, expected).enumerated() {
        try rejectUnknownFields(pair.0, known: pair.1, path: "\(path)[\(index)]")
      }
    }
  }

  func glyph(_ symbol: String) -> Glyph? { glyphs.first { $0.symbol == symbol } }

  func join(from left: String, to right: String) -> Join? {
    joins.first { $0.left == left && $0.right == right }
  }

  /// This first engine supports one left-to-right line and explicit continuous or lifted joins.
  /// Unsupported shaping is rejected, never silently converted to Latin cursive.
  private func validate() throws {
    func require(_ condition: Bool, _ message: String) throws {
      if !condition { throw Invalid(reason: message) }
    }
    func unique(_ values: [String]) -> Bool {
      !values.isEmpty
        && values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        && Set(values).count == values.count
    }
    try require(schemaVersion == 1, "Unsupported guide schema version; expected 1.")
    try require(direction == "leftToRight", "This engine supports left-to-right guides only.")
    try require(
      [
        id, name, revision, style, language, script, reviewStatus, provenance.author,
        provenance.license, provenance.source, provenance.instructionalReference,
        provenance.reviewNotes,
      ]
      .allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
      "Guide identity, provenance and review status are required.")
    try require(
      lines.midline.isFinite && lines.descender.isFinite
        && lines.midline > 0 && lines.midline < 1 && lines.descender >= 1 && lines.descender <= 2,
      "Guide lines must have 0 < midline < 1 and 1 <= descender <= 2.")
    try require(
      [lines.topLabel, lines.middleLabel, lines.baselineLabel].allSatisfy {
        !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      }, "All three guide-line labels are required.")
    try require(
      unique(profiles.map { $0.id }) && profiles.count <= 16,
      "Profiles need unique IDs (1–16 profiles).")
    for profile in profiles {
      try require(
        [profile.name, profile.instruction].allSatisfy {
          !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }, "Profile names and instructions must contain visible text.")
      let a = profile.assessment
      try require(
        ["geometry-v1", "geometry-v2"].contains(a.algorithm),
        "Unsupported assessment algorithm: \(a.algorithm).")
      if a.algorithm == "geometry-v2" {
        try require(
          a.matchTolerance.map { $0.isFinite && $0 >= 0.005 && $0 <= 0.2 } == true,
          "geometry-v2 requires matchTolerance between 0.005 and 0.2 writing-band heights.")
      } else {
        try require(a.matchTolerance == nil, "geometry-v1 does not use matchTolerance.")
      }
      try require(
        [a.shapeTolerance, a.positionTolerance, a.sizeTolerance].allSatisfy {
          $0.isFinite && $0 >= 0 && $0 <= 1
        }
          && [a.shapeFalloff, a.letterFalloff, a.positionFalloff, a.sizeFalloff].allSatisfy {
            $0.isFinite && $0 > 0 && $0 <= 2
          },
        "Assessment tolerances and falloffs are outside supported limits.")
    }
    try require(
      unique(glyphs.map { $0.symbol }) && glyphs.count <= 256,
      "Glyphs need unique symbols (1–256 glyphs).")
    let pointCount = glyphs.reduce(0) { total, glyph in
      total + glyph.strokes.reduce(0) { $0 + 1 + $1.curves.count * 24 }
    }
    try require(pointCount <= 65536, "Guide geometry exceeds 65,536 sampled points.")
    for glyph in glyphs {
      try require(
        !glyph.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        "Glyph instructions must contain visible text.")
      try require(
        glyph.symbol.count == 1 && !glyph.symbol.contains(where: { $0.isWhitespace }),
        "Each glyph must be one non-whitespace grapheme.")
      try require(
        glyph.advance.isFinite && glyph.advance > 0 && glyph.advance <= 4,
        "Glyph \(glyph.symbol) needs an advance greater than 0 and at most 4.")
      try require(
        !glyph.strokes.isEmpty && glyph.strokes.count <= 8,
        "Glyph \(glyph.symbol) needs 1–8 strokes.")
      for stroke in glyph.strokes {
        try require(
          !stroke.curves.isEmpty && stroke.curves.count <= 64,
          "Each stroke needs 1–64 cubic curves.")
        let coordinates =
          [stroke.start] + stroke.curves.flatMap { [$0.control1, $0.control2, $0.end] }
        try require(
          coordinates.allSatisfy {
            $0.x.isFinite && $0.y.isFinite
              && $0.x >= -0.5 && $0.x <= glyph.advance + 0.5 && $0.y >= -0.5
              && $0.y <= lines.descender + 0.5
          },
          "Glyph \(glyph.symbol) has invalid or out-of-range coordinates.")
        let points = stroke.points
        try require(
          points.allSatisfy {
            $0.x >= -0.000001 && $0.x <= glyph.advance + 0.000001 && $0.y >= -0.000001
              && $0.y <= lines.descender + 0.000001
          },
          "Glyph \(glyph.symbol) leaves its advance or writing lines; contextual overhang is not supported yet."
        )
        try require(
          points.contains { hypot($0.x - points[0].x, $0.y - points[0].y) > 0.0001 },
          "A stroke must have visible length.")
      }
      try require(
        glyph.entry == glyph.strokes.first?.start
          && glyph.exit == glyph.strokes.last?.curves.last?.end,
        "Glyph \(glyph.symbol) entry and exit must match its stroke endpoints.")
    }
    try require(
      joins.count <= 4096 && Set(joins.map { [$0.left, $0.right] }).count == joins.count,
      "Join rules must be unique (at most 4096).")
    for rule in joins {
      guard let left = glyph(rule.left), let right = glyph(rule.right) else {
        throw Invalid(reason: "Join rule references an unsupported glyph.")
      }
      try require(
        rule.mode == "continuous" || rule.mode == "lift", "Join mode must be continuous or lift.")
      if rule.mode == "continuous" {
        try require(
          abs(left.exit.x - left.advance - right.entry.x) < 0.000001
            && abs(left.exit.y - right.entry.y) < 0.000001,
          "Continuous join \(rule.left + rule.right) has mismatched endpoints; provide compatible paths or a lift."
        )
      }
    }
    try require(
      unique(lessons.map { $0.id }) && lessons.count <= 128,
      "Lessons need unique IDs (1–128 lessons).")
    for lesson in lessons {
      try require(
        !lesson.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        "Lesson instructions must contain visible text.")
      try require(
        !lesson.text.isEmpty && lesson.text.count <= 32 && lesson.set > 0 && lesson.set <= 128,
        "Lessons need 1–32 glyphs and a set number from 1–128.")
      let symbols = lesson.text.map(String.init)
      try require(
        symbols.allSatisfy { glyph($0) != nil },
        "Lesson \(lesson.id) contains an unsupported glyph.")
      for (left, right) in zip(symbols, symbols.dropFirst()) {
        try require(
          join(from: left, to: right) != nil,
          "Lesson \(lesson.id) needs an explicit join rule for \(left + right).")
      }
      let lessonPoints = symbols.reduce(0) { count, symbol in
        count + glyph(symbol)!.strokes.reduce(0) { $0 + 1 + $1.curves.count * 24 }
      }
      try require(lessonPoints <= 16384, "Lesson geometry exceeds 16,384 sampled points.")
      var offset = 0.0
      let points = symbols.flatMap { symbol -> [CGPoint] in
        let model = glyph(symbol)!
        defer { offset += model.advance }
        return model.strokes.flatMap { $0.points.map { CGPoint(x: $0.x + offset, y: $0.y) } }
      }
      let xs = points.map { $0.x }
      try require(
        xs.max()! - xs.min()! > 0.0001,
        "Lesson \(lesson.id) needs horizontal extent for geometry assessment.")
      let ys = points.map { $0.y }
      try require(
        ys.max()! - ys.min()! > 0.0001,
        "Lesson \(lesson.id) needs vertical extent for geometry assessment.")
    }
  }
}

enum GuideLibrary {
  static let prototype = bundled("prototype-cursive")
  static let all = [prototype, bundled("stroke-lab")]

  private static func bundled(_ name: String) -> HandwritingGuide {
    #if CURSIVE_TESTS
      let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Guides")!
    #elseif os(iOS)
      // AppleProductTypes app playgrounds copy resources into the main app bundle.
      let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Guides")!
    #else
      // The visual exporter compiles these exact sources outside SwiftPM from the repository root.
      let url = URL(fileURLWithPath: "CursivePrototype.swiftpm/Guides/\(name).json")
    #endif
    do { return try HandwritingGuide.decode(Data(contentsOf: url)) } catch {
      preconditionFailure("Invalid bundled guide \(name): \(error.localizedDescription)")
    }
  }
}
