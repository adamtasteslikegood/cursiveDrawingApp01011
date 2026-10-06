// Appended to the app analyzer source by scripts/test.sh; no duplicate implementation.
import XCTest

final class AnalyzerRegressionTests: XCTestCase {
  func testLevenshteinHandlesEmptyUnicodeAndEdits() {
    XCTAssertEqual(StringSimilarity.levenshteinDistance("", "loop"), 4)
    XCTAssertEqual(StringSimilarity.levenshteinDistance("loop", ""), 4)
    XCTAssertEqual(StringSimilarity.levenshteinDistance("loop", "look"), 1)
    XCTAssertEqual(StringSimilarity.levenshteinDistance("é", "e"), 1)
    XCTAssertEqual(StringSimilarity.levenshteinSimilarity(a: "", b: ""), 1)
    XCTAssertEqual(StringSimilarity.levenshteinSimilarity(a: "loop", b: "look"), 0.75)
  }

  func testDTWIdenticalAndDisplacedStrokes() {
    let points = [CGPoint(x: 0, y: 0), CGPoint(x: 0.5, y: 1), CGPoint(x: 1, y: 0)]
    XCTAssertEqual(DTW.distance(sequenceA: points, sequenceB: points), 0)
    let displaced = points.map { CGPoint(x: $0.x + 10, y: $0.y + 10) }
    XCTAssertGreaterThan(DTW.distance(sequenceA: points, sequenceB: displaced), 0)
    XCTAssertEqual(
      DTW.distance(sequenceA: points, sequenceB: displaced),
      DTW.distance(sequenceA: displaced, sequenceB: points), accuracy: 0.0001)
  }

  func testNormalizationHandlesTranslationAndDegenerateStroke() {
    let points = [CGPoint(x: 10, y: 20), CGPoint(x: 30, y: 60)]
    let normalized = CoordinateNormalizer.normalize(points: points, in: .zero)
    XCTAssertEqual(normalized, [.zero, CGPoint(x: 1, y: 1)])
    XCTAssertEqual(CoordinateNormalizer.normalize(points: [], in: .zero), [])
    XCTAssertEqual(CoordinateNormalizer.normalize(points: [points[0]], in: .zero), [.zero])
  }

  func testScoringToleranceAndFloor() {
    XCTAssertEqual(Scoring.slantScore(for: -20, targetSlantDeg: -20, toleranceDeg: 10), 100)
    XCTAssertEqual(Scoring.slantScore(for: -10, targetSlantDeg: -20, toleranceDeg: 10), 100)
    XCTAssertEqual(Scoring.slantScore(for: 180, targetSlantDeg: -20, toleranceDeg: 10), 0)
    XCTAssertEqual(Scoring.proportionScore(xHeightRatio: 0.45, ideal: 0.45, tolerance: 0.18), 100)
    XCTAssertEqual(Scoring.curvatureScore(meanCurvature: 1), 0)
  }

  func testReportJSONRoundTripPreservesFeedbackAndBounds() throws {
    let features = FeatureScores(
      legibilityScore: 10, shapeSimilarityScore: 20, slantScore: 30,
      proportionScore: 40, connectionScore: 50, curvatureScore: 60, timingScore: 70)
    let bounds = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
    let report = AnalysisReport(
      timestamp: Date(timeIntervalSince1970: 1234), overallScore: 42,
      letters: [
        LetterReport(
          letter: "l", boundingBox: bounds, finalScore: 42,
          featureScores: features, notes: ["Practice smooth joins."])
      ])
    let decoded = try JSONDecoder().decode(AnalysisReport.self, from: JSONEncoder().encode(report))
    XCTAssertEqual(decoded.timestamp, report.timestamp)
    XCTAssertEqual(decoded.overallScore, 42)
    XCTAssertEqual(decoded.letters.count, 1)
    XCTAssertEqual(decoded.letters[0].letter, "l")
    XCTAssertEqual(decoded.letters[0].boundingBox, bounds)
    XCTAssertEqual(decoded.letters[0].notes, report.letters[0].notes)
    XCTAssertEqual(decoded.letters[0].featureScores.timingScore, 70)
  }
}

final class ReviewRegressionTests: XCTestCase {
  private func segments(_ text: String) -> [Segment] {
    text.enumerated().map { index, character in
      let x = CGFloat(index) * 20
      return Segment(
        points: [CGPoint(x: x, y: 0), CGPoint(x: x + 10, y: 40)],
        boundingBox: CGRect(x: x, y: 0, width: 10, height: 40), recognizedString: String(character))
    }
  }

  private func report(_ text: String, target: String = "loop") -> AnalysisReport {
    let ink = segments(text)
    return ReportBuilder.build(
      strokes: ink.map { $0.points }, segments: ink,
      targetText: target, cropBounds: CGRect(x: 0, y: 0, width: 100, height: 40), templates: [:])
  }

  func testTargetAlignmentScoresSubstitutionAgainstExpectedCharacter() {
    let result = report("look")
    XCTAssertEqual(result.letters.map { $0.letter }, ["l", "o", "o", "p"])
    XCTAssertEqual(result.letters.map { $0.recognizedLetter }, ["l", "o", "o", "k"])
    XCTAssertEqual(result.letters.map { $0.featureScores.legibilityScore }, [100, 100, 100, 0])
    XCTAssertLessThan(result.overallScore, report("loop").overallScore)
    XCTAssertTrue(result.letters.last!.notes.contains { $0.contains("Expected 'p'") })
  }

  func testTargetAlignmentRetainsMissingAndExtraCharacters() {
    let missing = report("lop")
    XCTAssertEqual(missing.letters.count, 4)
    let omitted = missing.letters.first { $0.recognizedLetter == nil }!
    XCTAssertEqual(omitted.finalScore, 0)
    XCTAssertEqual(omitted.boundingBox, .zero)
    XCTAssertTrue(omitted.notes.contains { $0.contains("Missing") })
    let extra = report("loopx")
    XCTAssertEqual(extra.letters.count, 5)
    XCTAssertEqual(extra.letters.last!.featureScores.legibilityScore, 0)
    XCTAssertEqual(extra.letters.last!.finalScore, 0)
    XCTAssertTrue(extra.letters.last!.notes.contains { $0.contains("Extra") })
    XCTAssertLessThan(missing.overallScore, report("loop").overallScore)
    XCTAssertLessThan(extra.overallScore, report("loop").overallScore)
  }

  func testAlignmentHandlesCaseWhitespaceEmptyTargetAndUnrecognizedInk() {
    XCTAssertEqual(
      TargetAlignment.align(segments("loop"), targetText: " LOOP ").map { $0.legibility },
      [100, 100, 100, 100])
    XCTAssertEqual(report("", target: "loop").letters.count, 4)
    XCTAssertEqual(report("", target: "loop").overallScore, 0)
    XCTAssertEqual(report("loop", target: "").overallScore, 0)
    let unknown = Segment(
      points: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)], boundingBox: .zero,
      recognizedString: nil)
    XCTAssertEqual(TargetAlignment.align([unknown], targetText: "l")[0].legibility, 0)
  }

  func testTemplateLookupUsesExpectedCharacter() {
    let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)]
    let segment = Segment(
      points: points, boundingBox: CGRect(x: 0, y: 0, width: 10, height: 10), recognizedString: "x")
    let result = ReportBuilder.build(
      strokes: [points], segments: [segment], targetText: "l",
      cropBounds: CGRect(x: 0, y: 0, width: 10, height: 10),
      templates: ["l": [.zero, CGPoint(x: 1, y: 1)], "x": [CGPoint(x: 100, y: 100)]])
    XCTAssertEqual(result.letters[0].featureScores.shapeSimilarityScore, 100)
    XCTAssertEqual(result.letters[0].featureScores.legibilityScore, 0)
  }

  func testVisionBoxConvertsCropOffsetAndFlippedYAxis() {
    let crop = CGRect(x: 100, y: 200, width: 80, height: 40)
    let box = CGRect(x: 0.25, y: 0.1, width: 0.25, height: 0.2)
    let converted = DrawingCoordinates.rectangle(fromVisionBox: box, in: crop)
    XCTAssertEqual(converted.minX, 120, accuracy: 0.0001)
    XCTAssertEqual(converted.minY, 228, accuracy: 0.0001)
    XCTAssertEqual(converted.width, 20, accuracy: 0.0001)
    XCTAssertEqual(converted.height, 8, accuracy: 0.0001)
    let normalized = DrawingCoordinates.normalizedRectangle(converted, in: crop)
    XCTAssertEqual(normalized.minY, 0.7, accuracy: 0.0001)
    XCTAssertEqual(normalized.minX, 0.25, accuracy: 0.0001)
    XCTAssertEqual(
      DrawingCoordinates.point(fromVisionPoint: CGPoint(x: 0.5, y: 0.25), in: crop),
      CGPoint(x: 140, y: 230))
  }

  func testContinuousStrokeIsSplitAcrossFourCharactersAwayFromOrigin() {
    let crop = CGRect(x: 100, y: 200, width: 80, height: 40)
    let anchors = Array("loop").enumerated().map { index, character in
      CharacterAnchor(
        character: String(character),
        normalizedBox: CGRect(x: CGFloat(index) / 4, y: 0, width: 0.25, height: 1))
    }
    // No sampled point is inside either middle letter: clipping must insert boundary points.
    let stroke = [CGPoint(x: 100, y: 220), CGPoint(x: 180, y: 220)]
    let result = Segmenter.segment(strokes: [stroke], anchors: anchors, cropBounds: crop)
    XCTAssertEqual(result.count, 4)
    XCTAssertEqual(result.map { $0.recognizedString }, ["l", "o", "o", "p"])
    for (index, segment) in result.enumerated() {
      XCTAssertEqual(segment.points.count, 2)
      XCTAssertEqual(segment.points.first!.x, 100 + CGFloat(index) * 20)
      XCTAssertEqual(segment.points.last!.x, 120 + CGFloat(index) * 20)
    }
    let report = ReportBuilder.build(
      strokes: [stroke], segments: result, targetText: "loop", cropBounds: crop, templates: [:])
    XCTAssertEqual(report.letters.count, 4)
    XCTAssertEqual(report.letters[0].boundingBox, CGRect(x: 0, y: 0, width: 0.25, height: 1))
  }

  func testStrokeClippingPreservesUnknownInkAndAvoidsDuplicateAssignment() {
    let crop = CGRect(x: 0, y: 0, width: 100, height: 100)
    let anchor = CharacterAnchor(
      character: "l", normalizedBox: CGRect(x: 0.4, y: 0, width: 0.2, height: 1))
    let result = Segmenter.segment(
      strokes: [[CGPoint(x: 0, y: 50), CGPoint(x: 100, y: 50)]],
      anchors: [anchor, anchor], cropBounds: crop)
    XCTAssertEqual(result.filter { $0.recognizedString == nil }.count, 2)
    XCTAssertEqual(result.filter { $0.recognizedString != nil && !$0.points.isEmpty }.count, 1)
    let crossing = result.first { $0.recognizedString == "l" }!
    XCTAssertEqual(crossing.points, [CGPoint(x: 40, y: 50), CGPoint(x: 60, y: 50)])
  }

  func testPhysicalSlantIsNotMeasuredAfterAnisotropicNormalization() {
    let narrow = (0...4).map { CGPoint(x: CGFloat($0) * 5, y: CGFloat($0) * -10) }
    let wide = (0...4).map { CGPoint(x: CGFloat($0) * 20, y: CGFloat($0) * -10) }
    let a = FeatureExtractor.slantAngleDegrees(points: narrow)
    let b = FeatureExtractor.slantAngleDegrees(points: wide)
    XCTAssertEqual(a, -63.4349488, accuracy: 0.0001)
    XCTAssertEqual(b, -26.5650512, accuracy: 0.0001)
    let makeReport: ([CGPoint]) -> AnalysisReport = { points in
      ReportBuilder.build(
        strokes: [points],
        segments: [
          Segment(points: points, boundingBox: Segmenter.bounds(of: points), recognizedString: "l")
        ], targetText: "l",
        cropBounds: CGRect(x: 0, y: -40, width: 80, height: 40), templates: [:])
    }
    XCTAssertLessThan(
      makeReport(narrow).letters[0].featureScores.slantScore,
      makeReport(wide).letters[0].featureScores.slantScore)
  }

  func testProportionsUseDrawingUnitsAndAreTranslationInvariant() {
    let baseline = BaselineInfo(baselineY: 40, xHeight: 18, ascenderLine: 0, descenderLine: 58)
    let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 40)]
    let result = FeatureExtractor.proportions(
      points: points, baselineInfo: baseline, drawingSize: CGSize(width: 10, height: 40))
    XCTAssertEqual(result.xHeightRatio, 0.45, accuracy: 0.0001)
    XCTAssertEqual(
      Scoring.proportionScore(xHeightRatio: result.xHeightRatio, ideal: 0.45, tolerance: 0.18), 100)
    let shifted = FeatureExtractor.proportions(
      points: points.map { CGPoint(x: $0.x + 100, y: $0.y + 200) },
      baselineInfo: BaselineInfo(
        baselineY: 240, xHeight: 18, ascenderLine: 200, descenderLine: 258),
      drawingSize: CGSize(width: 10, height: 40))
    XCTAssertEqual(shifted.xHeightRatio, result.xHeightRatio)
    XCTAssertGreaterThan(report("loop").letters[0].featureScores.proportionScore, 0)
  }

  func testRepeatedLettersAndUnknownRowsHaveDistinctOccurrenceIDs() {
    let report = report("loop??", target: "loop??")
    XCTAssertEqual(report.rows.map { $0.report.letter }, ["l", "o", "o", "p", "?", "?"])
    XCTAssertEqual(Set(report.rows.map { $0.id }).count, 6)
    XCTAssertEqual(report.rows.map { $0.id }, [0, 1, 2, 3, 4, 5])
  }

  func testEvaluationClearsSuccessfulReportBeforeEmptyGuardAndFailure() {
    enum Failure: Error { case test }
    var state = EvaluationState()
    state.finish(.success(report("look")))
    XCTAssertEqual(state.recognizedText, "look")
    XCTAssertNotNil(state.analysisReport)
    XCTAssertFalse(state.begin(hasInk: false))
    XCTAssertNil(state.analysisReport)
    XCTAssertEqual(state.recognizedText, "")
    XCTAssertEqual(state.feedback, "Please write something first.")
    state.finish(.success(report("loop")))
    XCTAssertTrue(state.begin(hasInk: true))
    XCTAssertNil(state.analysisReport)
    XCTAssertEqual(state.recognizedText, "")
    XCTAssertTrue(state.isAnalyzing)
    state.finish(.failure(Failure.test))
    XCTAssertNil(state.analysisReport)
    XCTAssertFalse(state.isAnalyzing)
    XCTAssertTrue(state.feedback.hasPrefix("Analysis failed:"))
  }

  func testReportJSONRetainsExpectedAndRecognizedCharactersSeparately() throws {
    let result = report("look")
    let decoded = try JSONDecoder().decode(AnalysisReport.self, from: JSONEncoder().encode(result))
    XCTAssertEqual(decoded.letters.last!.letter, "p")
    XCTAssertEqual(decoded.letters.last!.recognizedLetter, "k")
  }
}

#if canImport(PencilKit)
  final class PencilKitIntegrationTests: XCTestCase {
    func testStrokeExtractionAppliesTranslationScalingAndRotation() throws {
      let local = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 20), CGPoint(x: 20, y: 40)]
      let points = local.enumerated().map { index, point in
        PKStrokePoint(
          location: point, timeOffset: Double(index) / 10,
          size: CGSize(width: 2, height: 2), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
      }
      let path = PKStrokePath(controlPoints: points, creationDate: Date())
      let transforms = [
        CGAffineTransform(translationX: 100, y: 200),
        CGAffineTransform(scaleX: 2, y: 3), CGAffineTransform(rotationAngle: .pi / 2),
      ]
      for transform in transforms {
        let stroke = PKStroke(
          ink: PKInk(.pen, color: .black), path: path, transform: transform, mask: nil)
        let extracted = try StrokeExtractor.extractStrokePoints(from: PKDrawing(strokes: [stroke]))
        XCTAssertEqual(extracted.count, 1)
        XCTAssertEqual(extracted[0], local.map { $0.applying(transform) })
      }
    }

    func testFastVisionRecognitionProducesPerCharacterAnchors() throws {
      let renderer = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 160))
      let image = renderer.image { context in
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 500, height: 160))
        ("loop" as NSString).draw(
          at: CGPoint(x: 40, y: 40),
          withAttributes: [
            .font: UIFont.systemFont(ofSize: 80), .foregroundColor: UIColor.black,
          ])
      }
      let observations = try VisionHelpers.recognizeTextObservations(in: image)
      let anchors = VisionHelpers.characterAnchors(from: observations)
      XCTAssertEqual(anchors.map { $0.character }.joined(), "loop")
      XCTAssertEqual(anchors.count, 4)
      XCTAssertEqual(Set(anchors.map { $0.normalizedBox.minX }).count, 4)
    }
  }
#endif
