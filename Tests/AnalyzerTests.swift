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
