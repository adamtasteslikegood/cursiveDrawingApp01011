import PencilKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var canvasView = AttachedWritingCanvas()
  @State private var toolPicker = PKToolPicker()
  @State private var evaluation = EvaluationState()
  @State private var models = GuideLibrary.all
  @State private var modelID = GuideLibrary.prototype.id
  @State private var profileID = GuideLibrary.prototype.profiles[0].id
  @State private var importsGuide = false
  @State private var importError: String?
  @State private var setID = 1
  @State private var lessonID = PracticeLesson.all[0].id
  @State private var showsTrace = true
  @State private var replayID = 0
  @State private var ghostProgress: CGFloat = 1
  @State private var layoutChangedDuringAnalysis = false

  private var model: HandwritingGuide { models.first { $0.id == modelID } ?? models[0] }
  private var profile: HandwritingGuide.Profile {
    model.profiles.first { $0.id == profileID } ?? model.profiles[0]
  }
  private var lessons: [PracticeLesson] { PracticeLesson.lessons(in: model, profile: profile) }
  private var lesson: PracticeLesson { lessons.first { $0.id == lessonID } ?? lessons[0] }

  var body: some View {
    GeometryReader { geometry in
      let height = min(360, max(220, geometry.size.height * 0.45))
      let canvasSize = CGSize(width: max(1, geometry.size.width - 32), height: height)
      let guide = WritingGuide(size: canvasSize, wordWidth: lesson.width, lines: model.lines)
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Cursive practice").font(.largeTitle.bold())
          Text(PracticeLesson.revision).font(.caption).foregroundColor(.secondary)
          Text("\(lesson.primer.name) · revision \(lesson.primer.revision)")
            .font(.caption).foregroundColor(.secondary)
          guideControls
          Picker("Lesson set", selection: $setID) {
            ForEach(Array(Set(lessons.map { $0.set })).sorted(), id: \.self) { value in
              Text("Set \(value)").tag(value)
            }
          }
          .pickerStyle(.segmented)
          .disabled(evaluation.isAnalyzing)
          .onChange(of: setID) { value in
            lessonID = lessons.first { $0.set == value }?.id ?? lessons[0].id
          }
          Picker("Practice word", selection: $lessonID) {
            ForEach(lessons.filter { $0.set == setID }) { item in
              Text(item.word).tag(item.id)
            }
          }
          .pickerStyle(.segmented)
          .disabled(evaluation.isAnalyzing)
          .onChange(of: lessonID) { _ in resetLesson() }

          HStack(alignment: .center, spacing: 16) {
            LessonThumbnail(lesson: lesson)
            VStack(alignment: .leading, spacing: 6) {
              Text("Write “\(lesson.word)”").font(.title2.bold())
              Text(
                "Follow the blue example and its guide lines. Lift your pen where the example has separate strokes."
              )
              .font(.subheadline)
            }
          }
          Text("Changing the guide, profile, or lesson clears your canvas.").font(.caption)
            .foregroundColor(.secondary)
          Text(lesson.focus).font(.subheadline)
          Text(model.reviewStatus)
            .font(.caption).foregroundColor(.secondary)

          ViewThatFits(in: .horizontal) {
            HStack {
              traceToggle
              Spacer()
              replayButton
            }
            VStack(alignment: .leading, spacing: 10) {
              traceToggle
              replayButton
            }
          }

          ZStack {
            LinedPaperBackground(guide: guide, showsDescender: lesson.showsDescender)
            if showsTrace {
              ReferenceWord(
                strokes: lesson.referenceStrokes(in: guide), progress: ghostProgress,
                color: .blue.opacity(0.23), lineWidth: 5)
            }
            WritingCanvas(
              canvasView: $canvasView, toolPicker: $toolPicker,
              isAnalyzing: evaluation.isAnalyzing)
            if evaluation.isAnalyzing {
              ProgressView("Comparing your writing…")
                .padding().background(.regularMaterial).cornerRadius(10)
            }
          }
          .frame(height: height)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))
          .task(id: replayID) {
            guard replayID > 0, !reduceMotion else {
              ghostProgress = 1
              return
            }
            ghostProgress = 0
            do { try await Task.sleep(nanoseconds: 100_000_000) } catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: 6)) { ghostProgress = 1 }
          }
          .onChange(of: canvasSize) { _ in
            // Resizing moves the reference guides. Keep ink, but require a fresh evaluation.
            if evaluation.isAnalyzing {
              layoutChangedDuringAnalysis = true
            } else {
              evaluation.reset()
            }
          }

          HStack {
            Button(action: clearCanvas) { Label("Clear", systemImage: "trash") }
              .foregroundColor(.red)
            Spacer()
            Button {
              evaluateDrawing(guide: guide)
            } label: {
              Label("Evaluate", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
          }
          .disabled(evaluation.isAnalyzing)

          feedback
          Text(
            "Practice feedback is experimental. It compares shape, height, position, ink near the example, and example coverage. Writing speed and educational mastery are unmeasured. OCR may misread cursive."
          )
          .font(.caption).foregroundColor(.secondary)
        }
        .padding(16)
        // Keep room to scroll the paper to the viewport center even without feedback.
        // Padding belongs to the page; the canvas and its ink/guide coordinates stay fixed.
        .padding(.bottom, max(0, (geometry.size.height - height) / 2))
      }
    }
    .fileImporter(isPresented: $importsGuide, allowedContentTypes: [.json]) { result in
      do {
        let url = try result.get()
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        // Bound the read itself; metadata sizes on external providers are not authoritative.
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: HandwritingGuide.maximumBytes + 1) ?? Data()
        let imported = try HandwritingGuide.decode(data)
        guard !models.contains(where: { $0.id == imported.id }) else {
          throw HandwritingGuide.Invalid(
            reason:
              "A guide with this ID is already loaded. Use a distinct ID to compare a new draft.")
        }
        models.append(imported)
        modelID = imported.id
        importError = nil
      } catch { importError = error.localizedDescription }
    }
  }

  private var guideControls: some View {
    VStack(alignment: .leading, spacing: 8) {
      Picker("Handwriting guide", selection: $modelID) {
        ForEach(models) { item in Text(item.name).tag(item.id) }
      }
      .onChange(of: modelID) { _ in
        profileID = model.profiles[0].id
        setID = model.lessons[0].set
        lessonID = model.lessons[0].id
        resetLesson()
      }
      Picker("Practice profile", selection: $profileID) {
        ForEach(model.profiles) { item in Text(item.name).tag(item.id) }
      }
      .onChange(of: profileID) { _ in resetLesson() }
      Text(profile.instruction).font(.subheadline)
      Button("Import guide JSON…") { importsGuide = true }
      Text("Imported guides stay available for this session. Geometry scores remain experimental.")
        .font(.caption).foregroundColor(.secondary)
      if let importError { Text(importError).font(.caption).foregroundColor(.red) }
      DisclosureGroup("About this guide") {
        Text("\(model.style) · \(model.language) / \(model.script)")
        Text(model.provenance.source)
        Text(model.provenance.instructionalReference)
        Text(model.provenance.reviewNotes)
      }.font(.caption)
    }.disabled(evaluation.isAnalyzing)
  }

  private var traceToggle: some View {
    Toggle("Trace guide", isOn: $showsTrace).fixedSize()
      .disabled(evaluation.isAnalyzing)
  }

  private var replayButton: some View {
    Button {
      clearCanvas()
      showsTrace = true
      replayID += 1
    } label: {
      Label("Replay example", systemImage: "play.circle")
    }
    .disabled(evaluation.isAnalyzing)
  }

  @ViewBuilder private var feedback: some View {
    if let report = evaluation.analysisReport, let practice = report.practice {
      VStack(alignment: .leading, spacing: 10) {
        Text("Practice score: \(Int(practice.score.rounded()))/100")
          .font(.title2.bold())
        Text(
          "Shape \(Int(practice.shape.rounded())) · Position \(Int(practice.placement.rounded())) · Height \(Int(practice.size.rounded()))"
        )
        .font(.subheadline)
        if let near = practice.inkNearModel, let covered = practice.modelCoverage {
          Text(
            "Ink near example \(Int(near.rounded()))% · Example covered \(Int(covered.rounded()))%"
          )
          .font(.subheadline)
        }
        ForEach(Array(practice.notes.enumerated()), id: \.offset) { _, note in Text(note) }
        Text("OCR read: \(evaluation.recognizedText)").font(.subheadline)
        if let note = report.recognitionNote { Text(note).font(.caption) }
        Text("OCR is a separate check; a shape match does not prove the word is correct.")
          .font(.caption).foregroundColor(.secondary)
        DisclosureGroup("Experimental letter and join analysis") {
          Text(
            "Guided estimates use expected model regions. They do not identify letters or validate stroke order; pen lifts may be intentional."
          )
          .font(.caption).foregroundColor(.secondary)
          ForEach(practice.letters ?? []) { letter in
            letterRow(letter)
          }
        }
        DisclosureGroup("OCR character diagnostics") {
          ForEach(report.rows) { row in
            VStack(alignment: .leading, spacing: 4) {
              Text("Expected \(row.report.letter) · Read \(row.report.recognizedLetter ?? "—")")
                .font(.headline)
              Text(
                row.report.recognizedLetter == row.report.letter
                  ? "Recognition agrees with this character."
                  : "Recognition differs or is incomplete; compare your ink with the example."
              )
              .font(.caption)
            }.padding(.vertical, 4)
          }
        }
      }
      .padding().frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(.secondarySystemBackground)).cornerRadius(10)
    } else if !evaluation.feedback.isEmpty {
      Text(evaluation.feedback).foregroundColor(.red)
    }
  }

  private func letterRow(_ letter: LetterPracticeFeedback) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        LessonThumbnail(
          lesson: PracticeLesson(
            word: letter.letter, focus: "Letter model", model: model, profile: profile),
          thumbnailWidth: 100)
        VStack(alignment: .leading) {
          Text("Letter \(letter.id + 1): \(letter.letter)").font(.headline)
          Text("Expected model").font(.caption).foregroundColor(.secondary)
        }
      }
      if let shape = letter.shape {
        Text("Model shape: \(Int(shape.rounded()))/100").font(.subheadline)
      }
      Text(model.glyph(letter.letter)?.instruction ?? "").font(.caption)
      Text(letter.note).font(.caption)
      if let join = letter.incomingJoin {
        Text(
          "Join \(join.combination): \(join.continuousInk ? "continuous ink observed" : "inspect the connection")"
        )
        .font(.subheadline)
        Text(join.note).font(.caption).foregroundColor(.secondary)
      }
    }.padding(.vertical, 6)
  }

  private func clearCanvas() {
    canvasView.drawing = PKDrawing()
    evaluation.reset()
  }

  private func resetLesson() {
    clearCanvas()
    ghostProgress = 1
    replayID = 0
  }

  private func evaluateDrawing(guide: WritingGuide) {
    guard evaluation.begin(hasInk: !canvasView.drawing.strokes.isEmpty) else { return }
    layoutChangedDuringAnalysis = false
    canvasView.isUserInteractionEnabled = false
    canvasView.updatePickerPresentation()
    CursiveAnalyzer.shared.analyze(
      drawing: canvasView.drawing, targetText: lesson.word,
      lesson: lesson, guide: guide
    ) { result in
      if layoutChangedDuringAnalysis {
        evaluation.reset()
        evaluation.feedback = "The canvas size changed. Evaluate again against the current guides."
      } else {
        evaluation.finish(result)
      }
    }
  }
}

/// Activate PencilKit only after UIKit attaches the canvas to a window.
final class AttachedWritingCanvas: PKCanvasView {
  var picker: PKToolPicker?

  override func didMoveToWindow() {
    super.didMoveToWindow()
    updatePickerPresentation()
  }

  func updatePickerPresentation() {
    guard window != nil else { return }
    if isUserInteractionEnabled {
      becomeFirstResponder()
      picker?.setVisible(true, forFirstResponder: self)
    } else {
      picker?.setVisible(false, forFirstResponder: self)
      resignFirstResponder()
    }
  }
}

struct WritingCanvas: UIViewRepresentable {
  @Binding var canvasView: AttachedWritingCanvas
  @Binding var toolPicker: PKToolPicker
  let isAnalyzing: Bool

  func makeUIView(context: Context) -> AttachedWritingCanvas {
    canvasView.drawingPolicy = .anyInput
    canvasView.isOpaque = false
    canvasView.backgroundColor = .clear
    canvasView.isScrollEnabled = false
    canvasView.contentInsetAdjustmentBehavior = .never
    canvasView.minimumZoomScale = 1
    canvasView.maximumZoomScale = 1
    canvasView.tool = PKInkingTool(.pen, color: .black, width: 4)
    canvasView.picker = toolPicker
    toolPicker.addObserver(canvasView)
    canvasView.isUserInteractionEnabled = !isAnalyzing
    return canvasView
  }

  func updateUIView(_ uiView: AttachedWritingCanvas, context: Context) {
    uiView.isUserInteractionEnabled = !isAnalyzing
    uiView.updatePickerPresentation()
  }

  static func dismantleUIView(_ uiView: AttachedWritingCanvas, coordinator: ()) {
    uiView.picker?.setVisible(false, forFirstResponder: uiView)
    uiView.picker?.removeObserver(uiView)
    uiView.picker = nil
  }
}
