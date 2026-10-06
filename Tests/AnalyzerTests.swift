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

final class LessonTests: XCTestCase {
  private let canvas = CGSize(width: 700, height: 320)

  func testEveryLessonReferenceCanScoreOneHundred() {
    for lesson in PracticeLesson.all {
      let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
      let result = LessonScorer.evaluate(
        strokes: [lesson.referencePoints(in: guide)], lesson: lesson, guide: guide)
      XCTAssertEqual(result.score, 100, accuracy: 0.001, lesson.word)
      XCTAssertEqual(result.shape, 100, accuracy: 0.001)
    }
  }

  func testGuidesAndModelsFitCompactAndLargeCanvases() {
    for size in [CGSize(width: 288, height: 220), canvas, CGSize(width: 1100, height: 360)] {
      for lesson in PracticeLesson.all {
        let guide = WritingGuide(size: size, wordWidth: lesson.width)
        XCTAssertEqual(guide.middle, (guide.top + guide.baseline) / 2)
        XCTAssertGreaterThan(guide.top, 0)
        XCTAssertLessThan(guide.descender, size.height)
        for point in lesson.referencePoints(in: guide) {
          XCTAssertGreaterThanOrEqual(point.x, 0)
          XCTAssertLessThanOrEqual(point.x, size.width)
          XCTAssertGreaterThanOrEqual(point.y, 0)
          XCTAssertLessThanOrEqual(point.y, size.height)
        }
      }
    }
  }

  func testVerticalMovementChangesPositionWithoutInventingShapeError() {
    let lesson = PracticeLesson.all[0]
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    let points = lesson.referencePoints(in: guide).map { CGPoint(x: $0.x, y: $0.y + guide.height) }
    let result = LessonScorer.evaluate(strokes: [points], lesson: lesson, guide: guide)
    XCTAssertEqual(result.shape, 100, accuracy: 0.001)
    XCTAssertEqual(result.placement, 0, accuracy: 0.001)
    XCTAssertTrue(result.notes.contains { $0.contains("highlighted band") })
  }

  func testUniformSizeChangePreservesShapeButLowersHeightMatch() {
    let lesson = PracticeLesson.all[0]
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    let points = lesson.referencePoints(in: guide).map {
      CGPoint(
        x: canvas.width / 2 + ($0.x - canvas.width / 2) * 0.4,
        y: canvas.height / 2 + ($0.y - canvas.height / 2) * 0.4)
    }
    let result = LessonScorer.evaluate(strokes: [points], lesson: lesson, guide: guide)
    XCTAssertEqual(result.shape, 100, accuracy: 0.001)
    XCTAssertLessThan(result.size, 30)
    XCTAssertTrue(result.notes.contains { $0.contains("taller") })
  }

  func testWrongWordAndAspectDistortionLowerShapeMatch() {
    let lesson = PracticeLesson.all[0]
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    let wrong = LessonScorer.evaluate(
      strokes: [PracticeLesson.all[1].referencePoints(in: guide)], lesson: lesson, guide: guide)
    XCTAssertLessThan(wrong.shape, 80)
    let distorted = lesson.referencePoints(in: guide).map { CGPoint(x: $0.x * 0.2, y: $0.y) }
    let result = LessonScorer.evaluate(strokes: [distorted], lesson: lesson, guide: guide)
    XCTAssertLessThan(result.shape, 80)
  }

  func testEmptyAndDegenerateInkProduceFiniteZeroFeedback() {
    let lesson = PracticeLesson.all[0]
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    for strokes in [[], [[CGPoint.zero]], [[CGPoint.zero, CGPoint.zero]]] as [[[CGPoint]]] {
      let result = LessonScorer.evaluate(strokes: strokes, lesson: lesson, guide: guide)
      XCTAssertEqual(result.score, 0)
      XCTAssertTrue(result.score.isFinite)
      XCTAssertTrue(result.notes.contains { $0.contains("whole word") })
    }
  }

  func testGeometryDoesNotClaimStrokeDirectionOrSpeed() {
    let lesson = PracticeLesson.all[0]
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    let reversed = Array(lesson.referencePoints(in: guide).reversed())
    let result = LessonScorer.evaluate(strokes: [reversed], lesson: lesson, guide: guide)
    XCTAssertEqual(result.shape, 100, accuracy: 0.001)
    XCTAssertFalse(result.notes.contains { $0.contains("speed") || $0.contains("stroke order") })
  }

  func testSparseAndDenseSamplingGiveSimilarShapeScores() {
    let lesson = PracticeLesson.all[0]
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    let reference = lesson.referencePoints(in: guide)
    let sparse =
      stride(from: 0, to: reference.count, by: 4).map { reference[$0] } + [reference.last!]
    let result = LessonScorer.evaluate(strokes: [sparse], lesson: lesson, guide: guide)
    XCTAssertGreaterThan(result.shape, 97)
  }

  func testSeparateStrokeChunksRetainReferenceGeometry() {
    let lesson = PracticeLesson.all[0]
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    let reference = lesson.referencePoints(in: guide)
    let split = reference.count / 2
    let result = LessonScorer.evaluate(
      strokes: [Array(reference[...split]), Array(reference[split...])], lesson: lesson,
      guide: guide)
    XCTAssertGreaterThan(result.shape, 97)
  }

  func testPracticeFeedbackRoundTripsWithAnalyzerReport() throws {
    let lesson = PracticeLesson.all[0]
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    let feedback = LessonScorer.evaluate(
      strokes: [lesson.referencePoints(in: guide)], lesson: lesson, guide: guide)
    let report = AnalysisReport(
      timestamp: Date(), overallScore: 20, letters: [], practice: feedback)
    let decoded = try JSONDecoder().decode(AnalysisReport.self, from: JSONEncoder().encode(report))
    XCTAssertEqual(decoded.practice?.score, 100)
    XCTAssertEqual(decoded.overallScore, 20)  // Recognition diagnostics remain separate.
  }
}

#if canImport(PencilKit)
  final class LessonIntegrationTests: XCTestCase {
    func testReferenceDrawingScoresHighlyThroughRealAnalyzer() {
      let lesson = PracticeLesson.all[0]
      let guide = WritingGuide(size: CGSize(width: 700, height: 320), wordWidth: lesson.width)
      let points = lesson.referencePoints(in: guide).enumerated().map { index, point in
        PKStrokePoint(
          location: point, timeOffset: Double(index) / 100,
          size: CGSize(width: 4, height: 4), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
      }
      let stroke = PKStroke(
        ink: PKInk(.pen, color: .black),
        path: PKStrokePath(controlPoints: points, creationDate: Date()), transform: .identity,
        mask: nil)
      let finished = expectation(description: "Real drawing analyzed")
      CursiveAnalyzer.shared.analyze(
        drawing: PKDrawing(strokes: [stroke]), targetText: lesson.word,
        lesson: lesson, guide: guide
      ) { result in
        switch result {
        case .success(let report):
          XCTAssertNotNil(report.practice)
          XCTAssertGreaterThan(report.practice?.score ?? 0, 98)
        case .failure(let error): XCTFail("\(error)")
        }
        finished.fulfill()
      }
      wait(for: [finished], timeout: 30)
    }
  }
#endif

final class AdvancedLetterTests: XCTestCase {
  private let canvas = CGSize(width: 700, height: 320)

  func testNineWordsInThreeSetsUseOneIdentifiedPrimer() {
    XCTAssertEqual(PracticeLesson.all.count, 9)
    XCTAssertEqual(Set(PracticeLesson.all.map { $0.id }).count, 9)
    for set in 1...3 { XCTAssertEqual(PracticeLesson.all.filter { $0.set == set }.count, 3) }
    XCTAssertEqual(Set(PracticeLesson.all.map { $0.primer.id }), ["prototype-cursive"])
  }

  func testEveryReferenceHasOneHighMatchRowPerExpectedOccurrence() {
    for lesson in PracticeLesson.all {
      let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
      let result = LessonScorer.evaluate(
        strokes: [lesson.referencePoints(in: guide)], lesson: lesson, guide: guide)
      let rows = result.letters!
      XCTAssertEqual(rows.map { $0.letter }.joined(), lesson.word)
      XCTAssertEqual(Set(rows.map { $0.id }).count, lesson.word.count)
      XCTAssertEqual(result.primerID, lesson.primer.id)
      XCTAssertEqual(result.primerRevision, lesson.primer.revision)
      for row in rows { XCTAssertGreaterThan(row.shape ?? 0, 98, "\(lesson.word) \(row.id)") }
      XCTAssertEqual(rows.compactMap { $0.incomingJoin }.count, lesson.word.count - 1)
      XCTAssertTrue(rows.dropFirst().allSatisfy { $0.incomingJoin?.continuousInk == true })
    }
  }

  func testSeparateLettersThatTouchDoNotFabricateContinuousJoins() {
    let lesson = PracticeLesson.all[0]
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    let strokes = lesson.letters.map { letter in
      letter.points.map {
        CGPoint(x: guide.originX + $0.x * guide.height, y: guide.top + $0.y * guide.height)
      }
    }
    let result = LessonScorer.evaluate(strokes: strokes, lesson: lesson, guide: guide)
    XCTAssertTrue(
      result.letters!.dropFirst().allSatisfy { $0.incomingJoin?.continuousInk == false })
    // Connection observations do not penalize the primary grade.
    XCTAssertGreaterThan(result.score, 97)
  }

  func testMissingMiddleWindowIsNotAssignedNeighbourInk() {
    let lesson = PracticeLesson.all[0]
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    let strokes = lesson.letters.filter { $0.id != 1 }.map { letter in
      letter.points.map {
        CGPoint(x: guide.originX + $0.x * guide.height, y: guide.top + $0.y * guide.height)
      }
    }
    let result = LessonScorer.evaluate(strokes: strokes, lesson: lesson, guide: guide)
    XCTAssertNil(result.letters![1].shape)
    XCTAssertTrue(result.letters![1].note.contains("Not enough ink"))
    XCTAssertNotNil(result.letters![2].shape)
  }

  func testLocalLetterDistortionChangesItsEstimate() {
    let lesson = PracticeLesson.all[2]  // hello: h/l retain the full bounds while e changes.
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    let strokes = lesson.letters.map { letter in
      letter.points.map { point in
        CGPoint(
          x: guide.originX + point.x * guide.height,
          y: guide.top + (letter.id == 1 ? 1 - (1 - point.y) * 0.4 : point.y) * guide.height)
      }
    }
    let result = LessonScorer.evaluate(strokes: strokes, lesson: lesson, guide: guide)
    XCTAssertLessThan(result.letters![1].shape ?? 100, 75)
    XCTAssertGreaterThan(result.letters![2].shape ?? 0, 95)
  }

  func testEmptyInkKeepsRowsButWithholdsLetterEstimates() {
    let lesson = PracticeLesson.all[2]
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    let result = LessonScorer.evaluate(strokes: [], lesson: lesson, guide: guide)
    XCTAssertEqual(result.letters?.count, lesson.word.count)
    XCTAssertTrue(result.letters!.allSatisfy { $0.shape == nil && $0.incomingJoin == nil })
  }

  func testClipperPreservesSparseCrossingsAndDoesNotBridgeExcursions() {
    let result = LetterWindow.clip(
      [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)], left: 25, right: 75)
    XCTAssertEqual(result, [[CGPoint(x: 25, y: 25), CGPoint(x: 75, y: 75)]])
    let outside = LetterWindow.clip(
      [CGPoint(x: 30, y: 0), CGPoint(x: 100, y: 40), CGPoint(x: 30, y: 80)], left: 25, right: 50)
    XCTAssertEqual(outside.count, 2)
    XCTAssertEqual(outside[0].last!.x, 50)
    XCTAssertEqual(outside[1].first!.x, 50)
  }

  func testPrimerAndOccurrenceFeedbackRoundTrip() throws {
    let lesson = PracticeLesson.all[2]
    let guide = WritingGuide(size: canvas, wordWidth: lesson.width)
    let result = LessonScorer.evaluate(
      strokes: [lesson.referencePoints(in: guide)], lesson: lesson, guide: guide)
    let decoded = try JSONDecoder().decode(
      PracticeFeedback.self, from: JSONEncoder().encode(result))
    XCTAssertEqual(decoded.primerID, result.primerID)
    XCTAssertEqual(decoded.letters?.map { $0.id }, [0, 1, 2, 3, 4])
    XCTAssertEqual(decoded.letters?[3].incomingJoin?.combination, "ll")
  }
}

#if canImport(PencilKit)
  final class VisibleInkTests: XCTestCase {
    func testFullyMaskedInkDoesNotFallBackToSyntheticContours() {
      let points = [CGPoint(x: 0, y: 30), CGPoint(x: 100, y: 30)].enumerated().map { index, point in
        PKStrokePoint(
          location: point, timeOffset: Double(index) / 10, size: CGSize(width: 2, height: 2),
          opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
      }
      let stroke = PKStroke(
        ink: PKInk(.pen, color: .black),
        path: PKStrokePath(controlPoints: points, creationDate: Date()), transform: .identity,
        mask: UIBezierPath(rect: CGRect(x: 1000, y: 1000, width: 10, height: 10)))
      XCTAssertTrue(stroke.maskedPathRanges.isEmpty)
      XCTAssertThrowsError(
        try StrokeExtractor.extractStrokePoints(from: PKDrawing(strokes: [stroke])))
    }

    func testPartialMaskKeepsVisibleRangesSeparateAfterTransform() throws {
      let points = [0, 25, 50, 75, 100].enumerated().map { index, x in
        PKStrokePoint(
          location: CGPoint(x: CGFloat(x), y: 30), timeOffset: Double(index) / 10,
          size: CGSize(width: 2, height: 2), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
      }
      let mask = UIBezierPath(rect: CGRect(x: -5, y: 20, width: 45, height: 20))
      mask.append(UIBezierPath(rect: CGRect(x: 60, y: 20, width: 45, height: 20)))
      var stroke = PKStroke(
        ink: PKInk(.pen, color: .black),
        path: PKStrokePath(controlPoints: points, creationDate: Date()), mask: mask)
      XCTAssertEqual(
        stroke.maskedPathRanges.count, 2,
        "The fixture must contain two visible path ranges before translation: \(stroke.renderBounds)"
      )
      stroke.transform = CGAffineTransform(translationX: 100, y: 200)
      let extracted = try StrokeExtractor.extractStrokePoints(from: PKDrawing(strokes: [stroke]))
      XCTAssertEqual(extracted.count, 2)
      XCTAssertTrue(extracted[0].allSatisfy { $0.x <= 140.5 })
      XCTAssertTrue(extracted[1].allSatisfy { $0.x >= 159.5 })
      XCTAssertTrue(extracted.flatMap { $0 }.allSatisfy { abs($0.y - 230) < 0.001 })
      XCTAssertLessThan(extracted[0].last!.x, extracted[1].first!.x)
    }
  }
#endif
