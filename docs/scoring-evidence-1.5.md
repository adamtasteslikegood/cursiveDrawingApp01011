# Prototype 1.5 — independent practice

The [1.4-final device evaluation](ipad-prototype-1.4-evaluation.md) reports improved false positives and centering, but totals consistently below 20% despite useful individual feedback. [CURS-25](https://tasteslikegood.atlassian.net/browse/CURS-25) addresses that mismatch; [CURS-26](https://tasteslikegood.atlassian.net/browse/CURS-26) makes Replay clear ink and previous feedback.

The old scorer did not inspect overlay visibility. Its near-exact ink support and model coverage multipliers nevertheless favored tracing heavily. Smooth synthetic variations reproduce this failure: changing loops and vertical position by up to 10% of the writing-band height produces word totals of 13.5–21.4% with v2. These are generated examples, not recordings of the owner's handwriting.

## Algorithm and identity

The package displays **Lesson prototype 1.5 · 2026-10-08** (bundle version 7). Bundled guides advance to revision **3**, selecting `geometry-v3`. No original glyph curve, line ratio, join, lesson or generated primer image changes. The existing guide/profile selector remains; the owner's preference for Stroke Lab Precise geometry is recorded without changing other profiles.

1. Fit ink with one uniform scale minimizing squared width/height extent errors, then align bounding-box centers. This retains proportions and separate visible paths. Horizontal translation is irrelevant to shape. Position and height still use original drawing coordinates. V3 does not use v2's coverage-based translation refinement.
2. Retain the existing mean-distance shape estimate. Additionally, sample 512 arc-length positions in each direction against the other path's exact edge index. Average the largest 103 distances (approximately the most different fifth); take the larger directional average and normalize by writing-band height. This detects sustained extra/missing form differences that a global average can hide. It does not count the fraction of the example traced.
3. Convert this sustained difference `d` to a form score, clamped to 0–100: `100 × (1 − max(0, d − (shapeTolerance + shapeFalloff / 4)) / shapeFalloff)`. Use the lower of this and the existing mean-distance shape score as **Shape**. Tolerances come from the selected guide/profile, not glyph names or a particular curriculum.
4. Compute `Shape × (0.60 + 0.002 × Position + 0.002 × Height)`. Good positioning alone cannot earn points for a badly mismatched form. Position/height can reduce a good shape score by up to 40%.
5. Limit unusually excessive pen travel. Let `r` be fitted visible ink length divided by model length. The ceiling is `100 / (1 + max(0, r − lengthAllowance))`. Bundled profiles allow twice the model length before this ceiling applies; this accommodates a second trace. A dense scribble can overlap much of a small model yet travel vastly farther. Apply the lower of this ceiling and the component score, and explain a materially active ceiling in feedback.

There is **no ink-support or model-coverage multiplier** in v3, nor a trace-visibility input. V3 results omit those two percentages; v2 imports still display their legacy diagnostics. Existing letter-window feedback and OCR diagnostics remain separate. Replay calls the same clear action as Clear, resetting both PencilKit ink and evaluation state, then enables the overlay and restarts the example. It remains disabled during evaluation and uses the existing Reduce Motion behavior.

## Verification and reproducible probes

```sh
python3 scripts/check_repository.py
./scripts/lint.sh
python3 scripts/test-portable.py
python3 scripts/probe-ink-support.py > /tmp/practice-v3.json
python3 scripts/probe-ink-support.py --algorithm geometry-v2 > /tmp/practice-v2.json
```

The probe exports 180 records: 12 lessons, all bundled profiles, 12 generated cases, and a 700 × 320 canvas. It records component scores, length ceiling, algorithm override, guide/profile identity, source commit and dirty state. `--algorithm geometry-v2` selects the retained 1.4 algorithm/settings on identical geometry and inputs; it does not assert that revision 3 was shipped in 1.4.

| Synthetic input | Nine words, Explore | Stroke Lab, Explore | Stroke Lab, Precise |
| --- | ---: | ---: | ---: |
| Exact model | 100 | 100 | 100 |
| Smooth 5%-of-band variation | 91.40–93.35 | 88.39–99.34 | 80.99–96.35 |
| Smooth 10%-of-band variation | 73.28–85.69 | 64.35–93.34 | 41.36–87.32 |
| 2% point jitter | 97.89–99.13 | 98.31–100 | 94.97–98.94 |
| Dense crosshatch | 0 | 0–22.68 | 0–22.68 |
| Zigzag | 0 | 0–9.90 | 0–9.90 |
| Seeded random scribble | 0–11.54 | 0–6.02 | 0–6.02 |
| Exact trace plus crosshatch | 0–6.46 | 0–18.49 | 0–18.49 |
| First half of each path | 0 | 0–53.63 | 0–32.94 |
| Reversed direction / whole-stroke order | 100 | 100 | 100 |
| Trace twice | 98.32–100 | 100 | 100 |

Regressions cover three canvas sizes for exact/jittered/smooth positives, all guides/profiles, three random seeds, missing separate strokes, extra ink, translated writing beside the model, algorithm serialization and strict parameter validation. The original 36-record v1 fixture and v2 regression bounds remain intact; legacy tests explicitly select v2 after the bundled guides advance. Both Apple and portable harnesses compile the same sources and fixtures. Linux cannot exercise PencilKit, Vision or SwiftUI; macOS CI and a new physical trial are separate evidence.

## Limits and device acceptance

This is still geometric comparison with a provisional model, not recognized letter formation or a validated educational grade. A geometrically similar wrong word can score well. Smooth warped models cover only a narrow class of freehand variation; actual student writing, uneven spacing, slant and differing legitimate letter forms need reviewed samples. The synthetic values and regression thresholds are engineering guardrails, not promised grades or curriculum standards.

The length ceiling can penalize repeated corrections or retracing beyond the selected allowance. Global bounds remain sensitive to outlying marks. Sampling can miss tiny features. Separate strokes/gaps remain separate; direction, timing, order and pen-lift correctness are not graded. Broad grading and Zaner-Bloser alignment remain open.

Use the [1.5 device checklist](device-validation.md#independent-practice-and-replay-15) to compare freehand targets with tracing, scribbles and partial attempts. Verify that visibility alone changes no score, Replay clears ink/results with either toggle state, and centering remains comfortable. Record actual guide/profile/target, all components and exceptions. The 1.4 device report does not accept 1.5 behavior.
