# Codex project guide

## Purpose and status

Cursive Prototype is an iOS-only Swift Playgrounds handwriting practice experiment using SwiftUI, PencilKit, Vision, and geometric scoring. It is a prototype toward a POC; educational scoring is not validated. The full original conversation and code are reference documents in `docs/`.

## Layout

- `CursivePrototype.swiftpm/`: active standalone app. `MyApp.swift` is the entry point, `ContentView.swift` contains the canvas and feedback UI, `LinedPaper.swift` draws guides, `CursiveAnalyzer.swift` performs analysis, and `EvaluationState.swift` handles result transitions and occurrence-based feedback rows.
- `Tests/`: analyzer regression test fragment and a standard test package manifest.
- `scripts/`: canonical lint/build/test/integrity commands.
- `docs/`: unique historical exports, provenance index, and device checklist.
- `specs/`: future `plan.md`, `roadmap.md`, and `design.md`; do not invent accepted requirements.
- `backups/legacy/`: preserved originals. Do not format, compile, or modify archived code.

## Working rules

Inspect current branch, status, PR dependencies, and source before editing. Prefer focused branches from `main`; if prototype setup is not merged, preserve and clearly state its branch dependency. Never revert unrelated edits.

Keep the app package standalone and one directory below root. The AppleProductTypes application manifest needs Xcode/Playgrounds; host `swift build` is not a valid iOS app check. Avoid dependencies or larger architecture changes during visual fixes unless requested.

The analyzer aligns recognized characters to `targetText`, measures physical features in drawing coordinates, and splits continuous paths at OCR character boundaries. Feedback identity uses row occurrences. These behaviors have regression coverage; OCR and segmentation accuracy and educational scoring remain unvalidated. Timing is fixed, teacher templates need registration, and the current lesson assumes one left-to-right line. See `docs/review-fixes.md` and read source and conversation before planning further changes.

## Verification

Run `python3 scripts/check_repository.py` and `./scripts/lint.sh` for repository/source changes. On macOS run `./scripts/build.sh` and `./scripts/test.sh` for app changes. Test scripts compile the exact analyzer and evaluation-state sources plus test fragment in one file to access file-private helpers without modifying app visibility. Add meaningful behavioral regression tests when fixing analysis.

CI runs macOS iOS builds and simulator tests. CodeQL Swift uses manual generic-iOS compilation; do not replace it with host autobuild. Keep GitHub default CodeQL setup disabled while the custom advanced workflow is enabled. Dependabot currently covers Actions only. Review current workflow results before declaring readiness.

For UI changes use `docs/device-validation.md`; CI success does not prove iPad behavior. On Linux report unavailable Apple checks explicitly.

Use Swift's built-in formatter on the active package and tests only. Do not commit generated `.swiftpm`, `.build`, Xcode state, personal drawings, or secrets. Preserve document hashes and originals when organizing references.

Keep README, QUICKSTART, CONTRIBUTING, and this guide consistent when commands or structure change. Use the PR template and include precise validation and device limitations.

Foundation-only analyzer tests can also run on Linux with `python3 scripts/test-portable.py`. This copies the exact math/model declarations from the active analyzer; it does not exercise Vision, PencilKit, or the iOS UI and does not replace the simulator suite.
