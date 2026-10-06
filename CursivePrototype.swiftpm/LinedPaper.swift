import SwiftUI

struct LinedPaperBackground: View {
  let guide: WritingGuide
  let showsDescender: Bool

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .topLeading) {
        Color.white
        Rectangle()
          .fill(Color.blue.opacity(0.07))
          .frame(height: guide.baseline - guide.middle)
          .offset(y: guide.middle)
        lines([guide.top, guide.baseline], width: geometry.size.width)
          .stroke(Color.blue.opacity(0.65), lineWidth: 1.5)
        lines([guide.middle], width: geometry.size.width)
          .stroke(Color.blue.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [7, 5]))
        if showsDescender {
          lines([guide.descender], width: geometry.size.width)
            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
        }
        label("Tall letters", y: guide.top - 17)
        label("Small letters", y: guide.middle - 17)
        label("Baseline", y: guide.baseline + 3)
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func lines(_ heights: [CGFloat], width: CGFloat) -> Path {
    Path { path in
      for y in heights {
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: width, y: y))
      }
    }
  }

  private func label(_ text: String, y: CGFloat) -> some View {
    Text(text).font(.caption2).foregroundColor(.blue)
      .padding(.horizontal, 4).background(Color.white.opacity(0.85))
      .offset(x: 6, y: y)
  }
}

struct ReferenceWord: View {
  let points: [CGPoint]
  var progress: CGFloat = 1
  var color: Color = .blue
  var lineWidth: CGFloat = 3

  var body: some View {
    Path { path in
      if let first = points.first {
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
      }
    }
    .trim(from: 0, to: progress)
    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

struct LessonThumbnail: View {
  let lesson: PracticeLesson
  var thumbnailWidth: CGFloat = 180

  var body: some View {
    GeometryReader { geometry in
      let guide = WritingGuide(size: geometry.size, wordWidth: lesson.width)
      ZStack {
        Color.white
        ReferenceWord(points: lesson.referencePoints(in: guide), lineWidth: 2)
      }
    }
    .frame(width: thumbnailWidth, height: 88)
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.3)))
    .accessibilityLabel("Illustrative cursive example: \(lesson.word)")
  }
}
