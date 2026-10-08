# Scoring evidence — prototype 1.3 guide migration

Historical report for source `a2a46acef78c8985597f39654b3c8abb421eb98b`. Run the reproduction commands in that checkout to reproduce the migration comparison below. Current bundled guides select the newer algorithm described in [1.4 scoring evidence](scoring-evidence-1.4.md); the original v1 fixture remains a compatibility check.

The [1.2 iPad report](ipad-prototype-1.2-evaluation.md) reported unrelated ink around 70 and careful tracing at about 85 or less. This investigation uses deterministic synthetic geometry, not the user's ink. It cannot establish the cause of the reported device tracing results.

## Reproduction

```sh
python3 scripts/probe-scoring.py --baseline 3f04013 > /tmp/cursive-baseline.json
python3 scripts/probe-scoring.py > /tmp/cursive-current.json
python3 scripts/test-portable.py
```

The baseline is the merged 1.2 `PracticeLesson.swift`. The current probe compiles the exact guide loader and lesson scorer. `Tests/ScoringFixtures.swift` supplies four probes for each of nine words, at a 700 × 320 canvas. The baseline's 36 component-score records are retained in `Tests/Fixtures/geometry-v1-baseline.json`. A behavioral regression compares every current component with those records to within 0.000001. This is a migration characterization, **not** a desired educational scoring specification; change the fixture deliberately when a reviewed replacement algorithm fixes these failures.

| Input | Geometry score range across nine words |
| --- | ---: |
| Exact model | 100 |
| Model with deterministic 2%-of-band-height point jitter | 96.21–99.33 |
| Unrelated dense horizontal crosshatching inside model bounds | 73.39–79.72 |
| Unrelated zigzag inside model bounds | 75.59–80.58 |

All 36 pre/post-migration scores are identical. The five-letter visual also remains identical. The guide migration neither fixes nor conceals the known scoring weakness.

## What the evidence supports

For `loop`, crosshatching receives shape 56.40, position 100 and height 100, yielding 73.84 overall. A zigzag receives shape 59.92 and the same position/height values, yielding 75.95. These synthetic inputs show that nearest-path averaging and the 40 combined position/height points can reward unrelated ink occupying the expected area. They do not prove any particular mechanism caused the user's specific attempts.

The score does not determine the written word, grade stroke order, count correct pen lifts, or recognize educational mastery. OCR remains separate. High-score wording now asks the user to compare actual letters rather than asserting the ink follows the example.

Exact synthetic paths and mild jitter do not reproduce an 85-point tracing ceiling. Repeated engine evaluation is deterministic; existing state-transition tests cover reset/failure behavior. Neither result excludes PencilKit capture, masks, device layout, actual tracing variation or a UI lifecycle issue. Do not select one cause without a device reproduction.

## Next acceptance evidence

CURS-20 remains open for false-positive correction; CURS-21 remains open for device tracing investigation. Record visible version, guide/revision/profile, canvas orientation, target, OCR, shape/position/height, and repeated attempts for trace, freehand, unrelated word and scribble cases. Check clear, lesson/profile/guide changes, partial erasure and rotation. Obtain consent before retaining personal drawings; no personal samples are committed here. Reviewed positive/negative examples are needed before choosing replacement thresholds or confidence gates.
