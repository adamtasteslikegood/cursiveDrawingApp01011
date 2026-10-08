# Codex project guide

## Purpose and status

Cursive Prototype is an iOS-only Swift Playgrounds handwriting practice experiment using SwiftUI, PencilKit, Vision, and geometric scoring. It is a prototype toward a POC; educational scoring is not validated. The full original conversation and code are reference documents in `docs/`.

## Layout

- `CursivePrototype.swiftpm/`: active standalone app. `MyApp.swift` is the entry point, `ContentView.swift` contains the canvas and feedback UI, `LinedPaper.swift` draws guides, `CursiveAnalyzer.swift` performs analysis, `HandwritingGuide.swift` validates versioned data from `Guides/`, `PracticeLesson.swift` composes shared model paths, guide geometry, and practice scoring, and `EvaluationState.swift` handles result transitions and occurrence-based feedback rows.
- `Tests/`: analyzer regression test fragment and a standard test package manifest.
- `scripts/`: canonical lint/build/test/integrity commands.
- `docs/`: unique historical exports, provenance index, and device checklist.
- `specs/`: `plan.md`, `roadmap.md`, and `design.md` frame the user-directed progression; Zaner-Bloser is the user-selected instructional reference; model alignment and future interfaces remain open. Do not invent accepted requirements.
- `backups/legacy/`: preserved originals. Do not format, compile, or modify archived code.

## Working rules

Inspect current branch, status, PR dependencies, and source before editing. Prefer focused branches from `main`; if prototype setup is not merged, preserve and clearly state its branch dependency. Never revert unrelated edits.

Keep the app package standalone and one directory below root. The AppleProductTypes application manifest needs Xcode/Playgrounds; host `swift build` is not a valid iOS app check. Avoid dependencies or larger architecture changes during visual fixes unless requested.

The analyzer aligns recognized characters to `targetText`, measures physical features in drawing coordinates, and splits continuous paths at OCR character boundaries. Feedback identity uses row occurrences. These behaviors have regression coverage; OCR and segmentation accuracy and educational scoring remain unvalidated. The primary lesson feedback compares whole-word model geometry, vertical placement, and height; OCR character scores remain experimental diagnostics. The examples are illustrative, not validated teacher models. Timing/join/stroke-order quality is not measured by the practice score. The legacy character scorer still uses fixed timing and requires template registration. Each lesson assumes one left-to-right line. See `docs/lesson-prototype.md` and the recorded baseline iPad evaluation. See `docs/review-fixes.md` and read source and conversation before planning further changes.

## Verification

Run `python3 scripts/check_repository.py` and `./scripts/lint.sh` for repository/source changes. On macOS run `./scripts/build.sh` and `./scripts/test.sh` for app changes. Test scripts compile the exact lesson-model, analyzer, and evaluation-state sources plus test fragment in one file to access file-private helpers without modifying app visibility. Add meaningful behavioral regression tests when fixing analysis.

CI runs macOS iOS builds and simulator tests. CodeQL Swift uses manual generic-iOS compilation; do not replace it with host autobuild. Keep GitHub default CodeQL setup disabled while the custom advanced workflow is enabled. Dependabot currently covers Actions only. Review current workflow results before declaring readiness.

For UI changes use `docs/device-validation.md`; CI success does not prove iPad behavior. On Linux report unavailable Apple checks explicitly.

Use Swift's built-in formatter on the active package and tests only. Do not commit generated `.swiftpm`, `.build`, Xcode state, personal drawings, or secrets. Preserve document hashes and originals when organizing references.

Keep README, QUICKSTART, CONTRIBUTING, and this guide consistent when commands or structure change. Use the PR template and include precise validation and device limitations.

Foundation-only analyzer tests can also run on Linux with `python3 scripts/test-portable.py`. This copies the exact guide loader, lesson models/resources and math/model declarations from the active analyzer; it does not exercise Vision, PencilKit, or the iOS UI and does not replace the simulator suite.

Version 1.3 keeps nine words in three sets under `prototype-cursive` revision 1. Letter feedback uses expected model windows after whole-word fitting; it is not independent recognition. Join observations require one visible path across both sides of the model boundary and do not grade pen-lift correctness. Visible mask ranges remain separate. See `docs/letter-analysis-prototype.md` and `docs/primer-decisions.md`; the user adopted Zaner-Bloser as the primary instructional reference for now; Handwriting Without Tears is a marketplace reference only. Do not relabel the current hand-authored runtime curves as Zaner-Bloser before alignment and review. Lint runs `scripts/export-primer.py --check` to keep the five-letter visual synchronized. A guide/profile selector and session-only validated JSON import are implemented. Stroke Lab verifies a new glyph, separate paths, lifted joins and alternate line ratios; it is a technical example, not a curriculum. There are no phrase/sentence/parent-linked combination lesson types. Read `docs/guide-format.md`, `docs/model-source-assessment.md` and `docs/sprint-119.md` before extending the contract. Schema 1 rejects unsupported directions, unknown fields, contextual variants and incompatible continuous endpoints. Rendering and scoring must retain separate strokes; never flatten them into connecting ink. Results pin guide/profile identity. Update both test scripts when changing resources. AppleProductTypes app resources use `Bundle.main`; the standard SwiftPM test target defines `CURSIVE_TESTS` for `Bundle.module`. The build script verifies guide files in the produced app.

`python3 scripts/probe-scoring.py` reproduces synthetic false positives; the 36-record 1.2 fixture locks migration behavior, not desired scores. All original five curves and their generated visual are unchanged. CURS-20/CURS-21 remain unresolved; do not claim the data refactor calibrated scoring.

The 1.2 device trial (`docs/ipad-prototype-1.2-evaluation.md`) confirms animations and feedback display but reports around 70% for unrelated ink and around 85% or less for tracing. Treat scoring as unresolved; reproduce before assigning a cause. The user requires a guide-driven engine with interchangeable style, skill-level, language, and glyph data. Zaner-Bloser is the first reference, not an engine-wide assumption. Personalized learned guides and separate penmanship/font capture are future capabilities; see `specs/design.md`.

The 1.3 device trial (`docs/ipad-prototype-1.3-evaluation.md`) reports approximately 98% for tracing, approximately 75% for scribbling, and working Stroke Lab modes. Import and full checklist acceptance remain unreported. Version 1.3.1 adds viewport-relative bottom space to the outer lesson ScrollView so the paper can be centered without feedback; physical acceptance is pending. Keep this space independent of evaluation state, and keep PencilKit scrolling disabled to preserve ink/guide registration. Do not treat the UI patch as a scoring or model change.

Version 1.4 prioritizes scribble rejection while preserving traces, as selected by the user. Bundled guides are revision 2 with `geometry-v2` and required `matchTolerance`; original glyph curves and generated visual remain unchanged. V2 uses a uniform extent fit, bounded translation refinement that cannot reduce either support measure, and weighted arc-length ink/model coverage against separate visible edges. It does not grade stroke order, direction, lifts or spelling. Keep v1 compatibility and its 36 fixture records intact; the v2 behavior tests are separate. `scripts/probe-ink-support.py` exports all guide/profile probes using `Tests/InkSupportFixtures.swift`, included by both test scripts. See `docs/scoring-evidence-1.4.md` for the exact formula, synthetic outcomes and limitations. CURS-20/CURS-21 and physical positioning acceptance remain open until device evidence is reviewed.
