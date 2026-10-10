# CURS-7 interchangeable guide contract review

Prepared 2026-10-08 for **Adam Schoen**, human owner and acceptance reviewer.
Disposition: engineering evidence and scope decisions for In Review. Schema
acceptance and the outstanding device checklist have not been recorded.

Review continuation, 2026-10-09: [PR #10](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/pull/10)
delivered this audit to main. Fresh Atlassian MCP reads still show CURS-7
In Review. The recorded 1.3 device report covers Stroke Lab, while imports and
the full checklist remain unreported. The owner selected a fresh review
handoff. The [decision register](../curs-1-review-continuation.md) keeps schema
refinement and device acceptance as distinct pending decisions; it does not
treat the documentation merge as acceptance of missing contextual support.

## Acceptance evidence

The canonical contract is [guide-format.md](../guide-format.md), implemented by
[HandwritingGuide.swift](../../CursivePrototype.swiftpm/HandwritingGuide.swift).
The implementation first shipped in [PR #6](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/pull/6)
and remains on the current 1.5 main baseline. Later assessment revisions do not
change schema 1's geometry and shaping capabilities. The original Jira criteria,
including variants and contextual joins, are assessed individually below.

| Criterion | Implemented evidence | Acceptance qualification |
| --- | --- | --- |
| Stable IDs and revisions | Guide, profile and lesson IDs; guide content revision; results serialize model/profile/algorithm/style/language identity | Decoder cannot prove an author incremented a revision correctly or that a reviewer approved its content |
| Normalized coordinates and guide ratios | Top 0, baseline 1; bounded midline and descender; selected guide lines drive layout | Valid geometry is not a reviewed pedagogical proportion |
| Ordered strokes, lifts and anchors | Stroke arrays preserve separate paths; entry/exit equal actual first/last endpoints; continuous/lift rules are explicit per ordered pair | Replay order follows data. The practice score does not grade stroke order, direction or pen-lift correctness |
| Variants and contextual joins | Compatible coincident endpoints can compose continuously; lifted joins remain separate | Contextual glyph variants and bridging connectors are unsupported and rejected, so this part of the original modeling requirement is unresolved |
| Provenance and review status | Required author, license declaration, origin, instructional reference and review status fields | Required text does not verify rights or establish educational approval |
| Existing letter and two-letter example | [e-and-ee.example.json](../../CursivePrototype.swiftpm/Guides/e-and-ee.example.json) is a complete distinct guide using the exact original e, with e/ee lessons and one continuous ee composition | Geometry composition is demonstrated; phrase/sentence or parent-linked combination lesson types are not implemented |
| Validator | Decoder accepts bundled/examples and rejects missing/unknown fields, unsupported versions/directions, duplicates, invalid geometry/lines/parameters/endpoints and missing join coverage | UI import-state behavior needs separate device evidence |
| Interchangeable style, profile, language and inventory | [Stroke Lab](../../CursivePrototype.swiftpm/Guides/stroke-lab.json) supplies x/l, separate strokes, lifted pairs, different lines and two profiles through the same engine | A technical second guide proves data interchange, not an alternative curriculum or calibrated skill level |

The existing behavioral cases in
[AnalyzerTests.swift](../../Tests/AnalyzerTests.swift) provide concrete checks:

- `testBundledGuidesRoundTripAndNewGlyphHasSeparateStrokes` checks decoded data,
  independent Stroke Lab paths and guide geometry.
- `testGuideProfileChangesAssessmentAndRoundTripsItsIdentity` checks profile
  effects and pinned serialized identity.
- `testConnectionsUseGuideAnchorInsteadOfAssumingBaseline` and
  `testSeparateLettersThatTouchDoNotFabricateContinuousJoins` check raised anchors
  and preserve the distinction between contact and continuous paths.
- `testShortDescenderUsesNormalizedBaselineInsteadOfPrototypeThreshold` checks
  normalized line behavior.
- `testUnknownCapabilitiesGlyphsAndDuplicateIdentityAreRejected`,
  `testImportedGuidesRequireVisibleLabelsAndInstructions`, and
  `testInvalidLinesAssessmentGeometryAndJoinsAreRejected` cover rejection rules,
  including unsupported contextual variants.
- `testImportableLetterAndCombinationExampleUsesExactBaselineGlyph` checks the
  complete e/ee example, identical e geometry and composed path.
- `testNewUnicodeGlyphLoadsWithoutAnEngineBranch` checks inventory flexibility
  with a technical ñ fixture; its reused geometry does not validate Spanish
  handwriting instruction.

The harness runs `python3 scripts/test-portable.py` for this task. That script
compiles the exact guide/lesson declarations and existing Foundation tests; it
does not exercise Vision, PencilKit or SwiftUI. Current-head GitHub CI supplies
the macOS iOS build and simulator suite. The current main baseline already has
successful [CI](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/actions/runs/37766478639)
and [CodeQL](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/actions/runs/37766478596).

## Findings

The engine consumes supplied data rather than embedding a style-specific glyph
switch. Guides and profiles are held by value during evaluation, and results pin
their identities. AppleProductTypes app resources use `Bundle.main`; the standard
test target uses `Bundle.module` under `CURSIVE_TESTS`. The build script verifies
packaged guide bytes. Rendering retains separate strokes rather than connecting
them with invented ink.

Schema 1 supports one left-to-right line with bounded glyph geometry. It does not
support contextual variants, connector curves, overhang, deferred marks, shaping
in another direction or multiple lines. These are contract gaps, not missing JSON
values that should be silently ignored. In particular, a new midline-ending form
cannot always connect to the next glyph's fixed baseline entry under the existing
coincident-endpoint rule.

Language/script fields identify data; they do not configure Vision recognition.
Explore/Precise profiles express geometric tolerances, not validated instructional
skill levels. V1's 36 locked fixture records preserve migration behavior rather
than desired scores. V2/v3 compatibility and separate negative regressions remain
intact; no calibration is claimed by the data refactor.

## Decision requested

Adam Schoen: review the supported contract and decide whether to accept this
working subset while explicitly refining variants/contextual shaping into
follow-up work, or require an extension before CURS-7 can be Done. Retain the
original criteria until that decision is recorded. Coordinate any extension with
CURS-8's formation findings and CURS-9's contextual connections; define examples,
composer behavior, revision rules and behavioral tests before implementation.

## Remaining acceptance

The [device checklist](../device-validation.md) still needs reported successful,
invalid and duplicate imports; switching after ink/results; exact path/replay
behavior; and compact layouts. The 1.3 owner report confirms Stroke Lab modes,
while the 1.5 report accepts execution, improved grading and Replay clearing.
Neither records all import/switching cases. Duplicate loaded-guide rejection and
failed-import preservation involve SwiftUI flows beyond the portable decoder
tests. Preserve unknown outcomes until Adam records them.

The open review PR will link this evidence, the
[CURS-1 charter](../../specs/curs-1-charter.md) and current checks.
Engineering verification supports review readiness; Adam's schema/scope decision,
device observations and any educational model judgment remain separate acceptance
records. No active app, geometry, scoring or archived source is changed here.
