//
//  CursiveAnalyzer.swift
//  CursiveTutorPrototype
//
//  Created by Adam Schoen and ChatGPT/Codex 4.x, 4o, and 6.1 sol on 2026-10-05 (latest version).
//

import CoreGraphics
import Foundation
import PencilKit
import UIKit
import Vision

// MARK: - Public API

/// Result objects that will be JSON-serializable
struct LetterReport: Codable {
  let letter: String
  let boundingBox: CGRect  // normalized crop-relative bounds, top-left origin
  var recognizedLetter: String? = nil
  let finalScore: Double  // 0..100
  let featureScores: FeatureScores
  let notes: [String]
}

struct FeatureScores: Codable {
  let legibilityScore: Double
  let shapeSimilarityScore: Double
  let slantScore: Double
  let proportionScore: Double
  let connectionScore: Double
  let curvatureScore: Double
  let timingScore: Double
}

/// Top-level analysis result
struct AnalysisReport: Codable {
  let timestamp: Date
  let overallScore: Double
  let letters: [LetterReport]
}

/// Main analyzer entrypoint
final class CursiveAnalyzer {
  static let shared = CursiveAnalyzer()
  private init() {}

  // Teacher templates: map letter -> array of CGPoint (normalized)
  // You must register templates before using DTW comparisons.
  private var templates: [String: [CGPoint]] = [:]

  // Register a canonical stroke template (normalized between 0-1)
  func registerTemplate(letter: String, normalizedPoints: [CGPoint]) {
    templates[letter.lowercased()] = normalizedPoints
  }

  /// Main analysis function.
  /// - Parameters:
  ///   - drawing: PKDrawing from the user's canvas
  ///   - targetText: intended text string (e.g., "loop")
  ///   - completion: returns AnalysisReport or error
  func analyze(
    drawing: PKDrawing, targetText: String,
    completion: @escaping (Result<AnalysisReport, Error>) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        // 1. extract strokes -> stroke groups of points
        let strokes = try StrokeExtractor.extractStrokePoints(from: drawing)

        // 2. rasterize to image for Vision bounding boxes (and to normalize coordinates)
        let image = drawing.asImage(backgroundColor: .white, scale: 3.0)

        // 3. run VNRecognizeTextRequest to get letter bounding boxes (word/letter anchors)
        let observations = try VisionHelpers.recognizeTextObservations(in: image)

        // Vision boxes are converted from the cropped raster back to drawing coordinates.
        let anchors = VisionHelpers.characterAnchors(from: observations)
        let letterSegments = Segmenter.segment(
          strokes: strokes, anchors: anchors, cropBounds: drawing.bounds)
        let report = ReportBuilder.build(
          strokes: strokes, segments: letterSegments, targetText: targetText,
          cropBounds: drawing.bounds, templates: self.templates)
        DispatchQueue.main.async {
          completion(.success(report))
        }
      } catch {
        DispatchQueue.main.async {
          completion(.failure(error))
        }
      }
    }
  }
}

// MARK: - Stroke extraction

enum StrokeExtractionError: Error {
  case cannotExtractPoints
}

private struct StrokeExtractor {
  /// Returns array of strokes; each stroke is array of CGPoints in original drawing space
  static func extractStrokePoints(from drawing: PKDrawing) throws -> [[CGPoint]] {
    // try direct extraction from PKDrawing.strokes
    var all: [[CGPoint]] = []
    if !drawing.strokes.isEmpty {
      for stroke in drawing.strokes {
        // PKStroke path is a collection of PKStrokePoints
        var pts: [CGPoint] = []
        for point in stroke.path {
          pts.append(point.location.applying(stroke.transform))
        }
        if !pts.isEmpty {
          all.append(pts)
        }
      }
      if !all.isEmpty { return all }
    }

    guard !drawing.strokes.isEmpty else { throw StrokeExtractionError.cannotExtractPoints }

    // Fallback: rasterize the drawing and extract contours via Vision's contours request
    // (not as precise but works if direct sampling is unavailable)
    guard let image = drawing.asImage(backgroundColor: .white, scale: 3.0).cgImage else {
      throw StrokeExtractionError.cannotExtractPoints
    }
    let contours = try VisionHelpers.extractContours(from: image)
    return contours.map { points in
      points.map { DrawingCoordinates.point(fromVisionPoint: $0, in: drawing.bounds) }
    }
  }
}

// MARK: - Preprocessing utilities

private struct Preprocessor {
  /// Moving-average smoothing then resample to uniform spacing (arc-length)
  static func resampleAndSmooth(points: [CGPoint], spacing: CGFloat) -> [CGPoint] {
    guard points.count > 2 else { return points }
    // smoothing: simple moving average of window 3
    var smoothed: [CGPoint] = []
    for i in 0..<points.count {
      let prev = points[max(0, i - 1)]
      let cur = points[i]
      let next = points[min(points.count - 1, i + 1)]
      let x = (prev.x + cur.x + next.x) / 3.0
      let y = (prev.y + cur.y + next.y) / 3.0
      smoothed.append(CGPoint(x: x, y: y))
    }
    // compute accumulated arc-length
    var dists: [CGFloat] = [0]
    for i in 1..<smoothed.count {
      let dx = smoothed[i].x - smoothed[i - 1].x
      let dy = smoothed[i].y - smoothed[i - 1].y
      dists.append(dists.last! + hypot(dx, dy))
    }
    let total = dists.last ?? 0
    guard total > 0 else { return smoothed }
    var resampled: [CGPoint] = []
    var target: CGFloat = 0
    while target <= total {
      // find index where dists[idx] <= target <= dists[idx+1]
      if let idx = dists.firstIndex(where: { $0 >= target }) {
        if idx == 0 {
          resampled.append(smoothed[0])
        } else {
          let t1 = dists[idx - 1]
          let t2 = dists[idx]
          let frac = (target - t1) / (t2 - t1)
          let p1 = smoothed[idx - 1]
          let p2 = smoothed[idx]
          let x = p1.x + (p2.x - p1.x) * frac
          let y = p1.y + (p2.y - p1.y) * frac
          resampled.append(CGPoint(x: x, y: y))
        }
      } else {
        resampled.append(smoothed.last!)
      }
      target += spacing
    }
    return resampled
  }
}

// MARK: - Baseline detection & proportions

private struct BaselineInfo {
  let baselineY: CGFloat  // y in drawing coordinates
  let xHeight: CGFloat
  let ascenderLine: CGFloat
  let descenderLine: CGFloat
}

private struct BaselineDetector {
  static func detectBaseline(from strokes: [[CGPoint]]) -> BaselineInfo {
    // gather all y-values of stroke points
    var ys: [CGFloat] = []
    for stroke in strokes {
      for p in stroke { ys.append(p.y) }
    }
    if ys.isEmpty {
      return BaselineInfo(baselineY: 0, xHeight: 10, ascenderLine: 20, descenderLine: -10)
    }
    // histogram approach: bucket y values
    let sorted = ys.sorted()

    // xHeight: use interquartile range to find typical stroke midline size
    let q1 = sorted[max(0, sorted.count / 4)]
    let q3 = sorted[min(sorted.count - 1, sorted.count * 3 / 4)]
    let iqr = q3 - q1
    // baseline is near the median of lower half (letters sit above baseline)
    let baseline = q3  // heuristic
    let xHeight = max(6.0, iqr * 0.6)
    let asc = baseline - (xHeight * 0.9)
    let desc = baseline + (xHeight * 1.2)
    return BaselineInfo(
      baselineY: baseline, xHeight: xHeight, ascenderLine: asc, descenderLine: desc)
  }
}

// MARK: - Segmenter (Vision + clustering heuristics)

private struct Segment {
  let points: [CGPoint]
  let boundingBox: CGRect?  // in image coordinates
  let recognizedString: String?
}

private struct CharacterAnchor {
  let character: String
  let normalizedBox: CGRect  // Vision coordinates: bottom-left origin.
}

private struct DrawingCoordinates {
  static func point(fromVisionPoint point: CGPoint, in crop: CGRect) -> CGPoint {
    CGPoint(x: crop.minX + point.x * crop.width, y: crop.minY + (1 - point.y) * crop.height)
  }

  static func rectangle(fromVisionBox box: CGRect, in crop: CGRect) -> CGRect {
    CGRect(
      x: crop.minX + box.minX * crop.width,
      y: crop.minY + (1 - box.maxY) * crop.height,
      width: box.width * crop.width, height: box.height * crop.height)
  }

  static func normalizedRectangle(_ box: CGRect, in crop: CGRect) -> CGRect {
    guard crop.width > 0, crop.height > 0 else { return .zero }
    return CGRect(
      x: (box.minX - crop.minX) / crop.width,
      y: (box.minY - crop.minY) / crop.height,
      width: box.width / crop.width, height: box.height / crop.height)
  }
}

/// Clip a line to a character box, including crossings with no sampled point inside it.
private struct StrokeClipper {
  static func interval(from a: CGPoint, to b: CGPoint, in box: CGRect) -> ClosedRange<CGFloat>? {
    var lower: CGFloat = 0
    var upper: CGFloat = 1
    let dx = b.x - a.x
    let dy = b.y - a.y
    let edges: [(CGFloat, CGFloat)] = [
      (-dx, a.x - box.minX), (dx, box.maxX - a.x),
      (-dy, a.y - box.minY), (dy, box.maxY - a.y),
    ]
    for (direction, distance) in edges {
      if direction == 0 {
        if distance < 0 { return nil }
      } else {
        let fraction = distance / direction
        if direction < 0 { lower = max(lower, fraction) } else { upper = min(upper, fraction) }
        if lower > upper { return nil }
      }
    }
    return lower...upper
  }

  static func point(from a: CGPoint, to b: CGPoint, fraction: CGFloat) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
  }
}

private struct Segmenter {
  static func segment(strokes: [[CGPoint]], anchors: [CharacterAnchor], cropBounds: CGRect)
    -> [Segment]
  {
    let boxes = anchors.map {
      DrawingCoordinates.rectangle(fromVisionBox: $0.normalizedBox, in: cropBounds)
    }
    var assigned = Array(repeating: [CGPoint](), count: anchors.count)
    var leftovers: [[CGPoint]] = []
    for stroke in strokes where !stroke.isEmpty {
      var remaining: [CGPoint] = []
      if stroke.count == 1 {
        if let index = boxes.firstIndex(where: {
          $0.insetBy(dx: -0.001, dy: -0.001).contains(stroke[0])
        }) {
          assigned[index].append(stroke[0])
        } else {
          leftovers.append(stroke)
        }
        continue
      }
      for (a, b) in zip(stroke, stroke.dropFirst()) {
        let intervals = boxes.map { StrokeClipper.interval(from: a, to: b, in: $0) }
        let cuts = Array(
          Set(
            [CGFloat(0), CGFloat(1)]
              + intervals.compactMap { $0 }.flatMap { [$0.lowerBound, $0.upperBound] })
        ).sorted()
        for (lower, upper) in zip(cuts, cuts.dropFirst()) where upper > lower {
          let middle = (lower + upper) / 2
          let points = [
            StrokeClipper.point(from: a, to: b, fraction: lower),
            StrokeClipper.point(from: a, to: b, fraction: upper),
          ]
          // A piece belongs to one character, even when OCR boxes overlap.
          if let index = intervals.firstIndex(where: { $0?.contains(middle) == true }) {
            assigned[index].append(contentsOf: points)
            if !remaining.isEmpty {
              leftovers.append(remaining)
              remaining = []
            }
          } else {
            remaining.append(contentsOf: points)
          }
        }
      }
      if !remaining.isEmpty { leftovers.append(remaining) }
    }
    var result = zip(anchors.indices, anchors).map { index, anchor in
      Segment(
        points: assigned[index], boundingBox: boxes[index], recognizedString: anchor.character)
    }
    // Keep unknown ink as explicit extra/unknown segments; never assign a whole crossing stroke twice.
    for cluster in clusterByX(leftovers) {
      let points = cluster.flatMap { $0 }
      result.append(Segment(points: points, boundingBox: bounds(of: points), recognizedString: nil))
    }
    // This prototype uses a single writing line; preserve left-to-right occurrence order.
    result = result.enumerated().sorted {
      let a = $0.element.boundingBox?.minX ?? 0
      let b = $1.element.boundingBox?.minX ?? 0
      return a == b ? $0.offset < $1.offset : a < b
    }.map { $0.element }
    return result
  }

  static func bounds(of points: [CGPoint]) -> CGRect {
    guard let first = points.first else { return .zero }
    let minX = points.map { $0.x }.min() ?? first.x
    let maxX = points.map { $0.x }.max() ?? first.x
    let minY = points.map { $0.y }.min() ?? first.y
    let maxY = points.map { $0.y }.max() ?? first.y
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  private static func clusterByX(_ strokes: [[CGPoint]]) -> [[[CGPoint]]] {
    let sorted = strokes.sorted { bounds(of: $0).midX < bounds(of: $1).midX }
    var result: [[[CGPoint]]] = []
    var last: CGRect?
    for stroke in sorted {
      let box = bounds(of: stroke)
      if let previous = last, abs(box.midX - previous.midX) <= 40,
        abs(box.midY - previous.midY) <= max(40, max(box.height, previous.height))
      {
        result[result.count - 1].append(stroke)
      } else {
        result.append([stroke])
      }
      last = box
    }
    return result
  }
}

/// Minimum-edit alignment preserves omissions and insertions instead of scoring recognition against itself.
private struct TargetAlignment {
  struct Item {
    let expected: String?
    let segment: Segment?
    var legibility: Double {
      guard let expected, let recognized = segment?.recognizedString else { return 0 }
      return StringSimilarity.levenshteinSimilarity(a: expected, b: recognized.lowercased()) * 100
    }
  }

  static func align(_ segments: [Segment], targetText: String) -> [Item] {
    let expected = targetText.lowercased().filter { !$0.isWhitespace }.map { String($0) }
    let recognized = segments.map { $0.recognizedString?.lowercased() }
    let n = expected.count
    let m = segments.count
    var costs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
    for i in 0...n { costs[i][0] = i }
    for j in 0...m { costs[0][j] = j }
    if n > 0, m > 0 {
      for i in 1...n {
        for j in 1...m {
          let mismatch = expected[i - 1] == recognized[j - 1] ? 0 : 1
          costs[i][j] = min(
            costs[i - 1][j - 1] + mismatch, costs[i - 1][j] + 1, costs[i][j - 1] + 1)
        }
      }
    }
    var i = n
    var j = m
    var result: [Item] = []
    while i > 0 || j > 0 {
      if i > 0, j > 0,
        costs[i][j] == costs[i - 1][j - 1] + (expected[i - 1] == recognized[j - 1] ? 0 : 1)
      {
        result.append(Item(expected: expected[i - 1], segment: segments[j - 1]))
        i -= 1
        j -= 1
      } else if i > 0, costs[i][j] == costs[i - 1][j] + 1 {
        result.append(Item(expected: expected[i - 1], segment: nil))
        i -= 1
      } else {
        result.append(Item(expected: nil, segment: segments[j - 1]))
        j -= 1
      }
    }
    return result.reversed()
  }
}

private struct ReportBuilder {
  static func build(
    strokes: [[CGPoint]], segments: [Segment], targetText: String,
    cropBounds: CGRect, templates: [String: [CGPoint]], timestamp: Date = Date()
  ) -> AnalysisReport {
    let baseline = BaselineDetector.detectBaseline(from: strokes)
    let letters = TargetAlignment.align(segments, targetText: targetText).map {
      item -> LetterReport in
      let segment = item.segment ?? Segment(points: [], boundingBox: nil, recognizedString: nil)
      let points = Preprocessor.resampleAndSmooth(points: segment.points, spacing: 2.5)
      let normalized = CoordinateNormalizer.normalize(points: points, in: cropBounds)
      let curvatures = FeatureExtractor.curvatures(points: normalized)
      let curvature = curvatures.isEmpty ? 0 : curvatures.reduce(0, +) / Double(curvatures.count)
      // Physical angle and height must use drawing-space points, just like the baseline.
      let slant = FeatureExtractor.slantAngleDegrees(points: points)
      let proportions = FeatureExtractor.proportions(
        points: points, baselineInfo: baseline, drawingSize: cropBounds.size)
      let shape: Double
      if let expected = item.expected, let template = templates[expected], !points.isEmpty {
        shape = max(0, 100 - DTW.distance(sequenceA: normalized, sequenceB: template) * 1000)
      } else {
        shape = points.isEmpty ? 0 : 50
      }
      let features = FeatureScores(
        legibilityScore: item.legibility, shapeSimilarityScore: shape,
        slantScore: Scoring.slantScore(for: slant, targetSlantDeg: -20, toleranceDeg: 10),
        proportionScore: Scoring.proportionScore(
          xHeightRatio: proportions.xHeightRatio, ideal: 0.45, tolerance: 0.18),
        connectionScore: Scoring.connectionScore(for: segment, baselineInfo: baseline),
        curvatureScore: Scoring.curvatureScore(meanCurvature: curvature),
        timingScore: Scoring.timingScore(for: segment))
      let weights = Scoring.Weights()
      let weighted =
        weights.legibility * features.legibilityScore + weights.shape * shape
        + weights.slant * features.slantScore + weights.proportion * features.proportionScore
        + weights.connection * features.connectionScore + weights.curvature
        * features.curvatureScore
        + weights.timing * features.timingScore
      let valid = item.expected != nil && item.segment != nil && !points.isEmpty
      var notes: [String] = []
      if item.expected == nil {
        notes.append("Extra character or unrecognized ink; write only the requested text.")
      } else if item.segment == nil {
        notes.append("Missing '\(item.expected!)'; include every requested character.")
      } else if points.isEmpty {
        notes.append("No ink was associated with this recognized character.")
      } else if item.legibility < 100 {
        notes.append(
          "Expected '\(item.expected!)', recognized '\(segment.recognizedString ?? "?")'.")
      }
      if valid {
        let hints: [(Double, String)] = [
          (shape, "Shape differs from the teacher template; practice the model letter."),
          (features.slantScore, "Practice a consistent slant with the guide-lines."),
          (features.proportionScore, "Practice letter height relative to the writing line."),
          (features.connectionScore, "Practice smooth joins between letters."),
          (features.curvatureScore, "Practice smoother loops."),
        ]
        if weighted < 75, let worst = hints.min(by: { $0.0 < $1.0 }) {
          notes.append(worst.1)
        } else if notes.isEmpty {
          notes.append("Nice! Minor polish recommended.")
        }
      }
      return LetterReport(
        letter: item.expected ?? segment.recognizedString ?? "?",
        boundingBox: segment.boundingBox.map {
          DrawingCoordinates.normalizedRectangle($0, in: cropBounds)
        } ?? .zero,
        recognizedLetter: segment.recognizedString,
        finalScore: valid ? min(max(weighted, 0), 100) : 0,
        featureScores: features, notes: notes)
    }
    let score =
      letters.isEmpty ? 0 : letters.reduce(0) { $0 + $1.finalScore } / Double(letters.count)
    return AnalysisReport(timestamp: timestamp, overallScore: score, letters: letters)
  }
}

// MARK: - Feature extractor

private struct FeatureExtractor {
  /// Slant in degrees (fit line to points)
  static func slantAngleDegrees(points: [CGPoint]) -> Double {
    guard points.count > 2 else { return 0 }
    let xs = points.map { Double($0.x) }
    let ys = points.map { Double($0.y) }
    let xMean = xs.reduce(0, +) / Double(xs.count)
    let yMean = ys.reduce(0, +) / Double(ys.count)
    var num = 0.0
    var den = 0.0
    for (x, y) in zip(xs, ys) {
      num += (x - xMean) * (y - yMean)
      den += (x - xMean) * (x - xMean)
    }
    if den == 0 { return 0.0 }
    let slope = num / den  // dy/dx
    let angleRad = atan(slope)
    let angleDeg = angleRad * 180.0 / .pi
    // convert to signed slant relative to vertical if you prefer; keep horizontal-based here
    return angleDeg
  }

  /// Curvature discrete approximation along polyline
  static func curvatures(points: [CGPoint]) -> [Double] {
    guard points.count >= 3 else { return [] }
    var k: [Double] = []
    for i in 1..<(points.count - 1) {
      let p0 = points[i - 1]
      let p1 = points[i]
      let p2 = points[i + 1]
      let dx1 = Double(p1.x - p0.x)
      let dy1 = Double(p1.y - p0.y)
      let dx2 = Double(p2.x - p1.x)
      let dy2 = Double(p2.y - p1.y)
      let cross = abs(dx1 * dy2 - dy1 * dx2)
      // 'a' was unused

      // stable small denom guard
      let denom = max(1e-6, pow((dx1 * dx1 + dy1 * dy1), 1.5) + 1e-6)
      let curvature = cross / denom
      k.append(curvature)
    }
    return k
  }

  /// Both points and baseline metrics are in the same drawing-space units.
  static func proportions(points: [CGPoint], baselineInfo: BaselineInfo, drawingSize: CGSize) -> (
    xHeightRatio: Double, ascenderRatio: Double, descenderRatio: Double
  ) {
    guard !points.isEmpty else { return (0.0, 0.0, 0.0) }
    let minY = points.map { $0.y }.min() ?? 0
    let maxY = points.map { $0.y }.max() ?? 0
    let totalH = maxY - minY
    let xh = baselineInfo.xHeight
    let xHeightRatio = totalH > 0 ? Double(xh / totalH) : 0.0
    // asc/desc relative to xHeight
    let asc =
      xh > 0 ? max(0.0, Double((baselineInfo.baselineY - baselineInfo.ascenderLine) / xh)) : 0
    let desc =
      xh > 0 ? max(0.0, Double((baselineInfo.descenderLine - baselineInfo.baselineY) / xh)) : 0
    return (xHeightRatio, asc, desc)
  }
}

// MARK: - DTW (Dynamic Time Warping) for shape similarity

private struct DTW {
  // sequences are arrays of normalized CGPoints (0..1)
  static func distance(sequenceA: [CGPoint], sequenceB: [CGPoint]) -> Double {
    let n = sequenceA.count
    let m = sequenceB.count
    guard n > 0 && m > 0 else { return Double.infinity }
    // compute cost matrix with O(n*m)
    var dtw = Array(repeating: Array(repeating: Double.infinity, count: m + 1), count: n + 1)
    dtw[0][0] = 0.0
    for i in 1...n {
      for j in 1...m {
        let a = sequenceA[i - 1]
        let b = sequenceB[j - 1]
        let d = hypot(Double(a.x - b.x), Double(a.y - b.y))
        let cost = d
        let minPrev = min(dtw[i - 1][j], dtw[i][j - 1], dtw[i - 1][j - 1])
        dtw[i][j] = cost + minPrev
      }
    }
    return dtw[n][m] / Double(n + m)  // normalized by path length
  }
}

// MARK: - Scoring helpers

private struct Scoring {
  struct Weights {
    let legibility: Double = 0.30
    let shape: Double = 0.25
    let slant: Double = 0.15
    let proportion: Double = 0.10
    let connection: Double = 0.10
    let curvature: Double = 0.06
    let timing: Double = 0.04
  }

  static func slantScore(for slantDeg: Double, targetSlantDeg: Double, toleranceDeg: Double)
    -> Double
  {
    let err = abs(slantDeg - targetSlantDeg)
    if err <= toleranceDeg { return 100.0 }
    // linear falloff
    let score = max(0.0, 100.0 - (err - toleranceDeg) * 5.0)
    return score
  }

  static func proportionScore(xHeightRatio: Double, ideal: Double, tolerance: Double) -> Double {
    let err = abs(xHeightRatio - ideal)
    if err <= tolerance { return 100.0 }
    return max(0.0, 100.0 - (err - tolerance) * 100.0)
  }

  static func curvatureScore(meanCurvature: Double) -> Double {
    // smaller is smoother; choose mapping heuristically
    let score = max(0.0, 100.0 - meanCurvature * 500.0)
    return score
  }

  static func connectionScore(for seg: Segment, baselineInfo: BaselineInfo) -> Double {
    // quick heuristic: check continuity at endpoints if multiple strokes exist in segment
    let pts = seg.points
    if pts.count < 4 { return 80.0 }  // short letters, neutral
    let first = pts.first!
    let last = pts.last!
    // distance between end and start if this is a join with adjacent letter would be checked elsewhere;
    // for single-letter, penalize if start and end are far (broken)
    let dist = hypot(last.x - first.x, last.y - first.y)
    // scale relative to baseline xHeight
    let scale = baselineInfo.xHeight > 0 ? baselineInfo.xHeight : 10.0
    let norm = dist / scale
    return max(0.0, 100.0 - norm * 40.0)
  }

  static func timingScore(for seg: Segment) -> Double {
    // if stroke timestamps available we could compute speed variance; in prototype we assume neutral
    return 70.0
  }
}

// MARK: - Utility: Coordinate normalizer

private struct CoordinateNormalizer {
  /// Normalize points to 0..1 space using bounding box of points
  static func normalize(points: [CGPoint], in imageRect: CGRect) -> [CGPoint] {
    guard !points.isEmpty else { return points }
    let minX = points.map { $0.x }.min() ?? 0
    let maxX = points.map { $0.x }.max() ?? 1
    let minY = points.map { $0.y }.min() ?? 0
    let maxY = points.map { $0.y }.max() ?? 1
    let width = max(1, maxX - minX)
    let height = max(1, maxY - minY)
    return points.map { p in
      let nx = (p.x - minX) / width
      // normalize y so origin at top-> keep same orientation
      let ny = (p.y - minY) / height
      return CGPoint(x: nx, y: ny)
    }
  }
}

// MARK: - String similarity (Levenshtein)

private struct StringSimilarity {
  static func levenshteinDistance(_ a: String, _ b: String) -> Int {
    let s = Array(a)
    let t = Array(b)
    let n = s.count
    let m = t.count
    if n == 0 { return m }
    if m == 0 { return n }
    var v0 = [Int](repeating: 0, count: m + 1)
    var v1 = [Int](repeating: 0, count: m + 1)
    for j in 0...m { v0[j] = j }
    for i in 0..<n {
      v1[0] = i + 1
      for j in 0..<m {
        let cost = s[i] == t[j] ? 0 : 1
        v1[j + 1] = min(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost)
      }
      v0 = v1
    }
    return v1[m]
  }

  static func levenshteinSimilarity(a: String, b: String) -> Double {
    let d = levenshteinDistance(a, b)
    let maxLen = max(a.count, b.count)
    guard maxLen > 0 else { return 1.0 }
    return 1.0 - (Double(d) / Double(maxLen))
  }
}

// MARK: - Vision helpers (text recognition + contours fallback)

private struct VisionHelpers {
  static func recognizeTextObservations(in image: UIImage) throws -> [VNRecognizedTextObservation] {
    guard let cg = image.cgImage else { return [] }
    let req = VNRecognizeTextRequest()
    req.recognitionLanguages = ["en-US"]
    // Fast recognition provides character-range boxes; accurate mode returns word boxes.
    req.recognitionLevel = .fast
    req.usesLanguageCorrection = true
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    try handler.perform([req])
    return req.results ?? []
  }

  static func characterAnchors(from observations: [VNRecognizedTextObservation])
    -> [CharacterAnchor]
  {
    observations.flatMap { observation -> [CharacterAnchor] in
      guard let candidate = observation.topCandidates(1).first else { return [] }
      let text = candidate.string
      let indices = Array(text.indices)
      return indices.enumerated().compactMap { offset, index in
        let character = text[index]
        guard !character.isWhitespace else { return nil }
        let range = index..<text.index(after: index)
        let characterBox = try? candidate.boundingBox(for: range)
        // Vision boxes are approximate. A missing box uses an explicit equal-width heuristic.
        let word = observation.boundingBox
        let width = word.width / CGFloat(max(1, indices.count))
        let fallback = CGRect(
          x: word.minX + CGFloat(offset) * width, y: word.minY,
          width: width, height: word.height)
        return CharacterAnchor(
          character: String(character).lowercased(),
          normalizedBox: characterBox?.boundingBox ?? fallback)
      }
    }
  }

  static func extractContours(from cgImage: CGImage) throws -> [[CGPoint]] {
    // Use VNDetectContoursRequest to extract stroke-like contours if stroke sampling unavailable
    let request = VNDetectContoursRequest()
    request.contrastAdjustment = 1.0
    request.maximumImageDimension = 1024
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])
    guard let observation = request.results?.first as? VNContoursObservation else { return [] }
    var result: [[CGPoint]] = []
    for i in 0..<observation.contourCount {
      guard let contour = try? observation.contour(at: i) else { continue }
      let points = contour.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
      result.append(points)
    }
    return result
  }
}

// MARK: - Convenience: PKDrawing -> UIImage

extension PKDrawing {
  fileprivate func asImage(backgroundColor: UIColor = .white, scale: CGFloat = 1.0) -> UIImage {
    // determine bounds
    let bounds = self.bounds
    let img = self.image(from: bounds, scale: scale)

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0  // image is already scaled
    let renderer = UIGraphicsImageRenderer(size: img.size, format: format)

    return renderer.image { ctx in
      backgroundColor.setFill()
      ctx.fill(CGRect(origin: .zero, size: img.size))
      img.draw(at: .zero)
    }
  }
}

// MARK: - Small helpers

extension Array where Element == Double {
  fileprivate func mean() -> Double {
    guard !self.isEmpty else { return 0.0 }
    return self.reduce(0.0, +) / Double(self.count)
  }
}
