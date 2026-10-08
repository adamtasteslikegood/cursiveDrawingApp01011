# Prototype 1.4 — extra ink and model coverage

**Follow-up:** the [1.4-final device trial](ipad-prototype-1.4-evaluation.md) reports improved false positives and centering but overly low totals. [Version 1.5](scoring-evidence-1.5.md) removes the coverage multipliers. The formula and results below describe 1.4.

The owner selected **reduce high scores for scribbles while preserving tracing scores** after the [1.3 iPad trial](ipad-prototype-1.3-evaluation.md). That trial reported about 98% for tracing and about 75% for scribbling. This iteration addresses [CURS-20](https://tasteslikegood.atlassian.net/browse/CURS-20); physical scoring acceptance and the cause of the earlier 1.2 tracing ceiling remain open.

## Algorithm and guide identity

Bundled guides advance to revision **2** and select `geometry-v2`. Their glyph curves, strokes, joins, lessons and line ratios are unchanged. The five-letter SVG remains byte-identical. The standalone package displays **Lesson prototype 1.4 · 2026-10-07** and includes the 1.3.1 writing-area positioning fix.

1. Fit the ink with one uniform scale that minimizes the squared errors of width and height together. This avoids letting a small height variation shrink a long trace. Translation and size are still assessed separately in original drawing coordinates.
2. Compare both directions: ink near the reference, and reference covered by ink. Sample 512 positions uniformly along actual path length in each direction and query a balanced bounding-box index of the other drawing's actual polyline edges. The index prunes distant edges without discarding segments or inserting chords. Each visible path stays separate; no edge is inserted across a lift or erased gap.
3. `matchTolerance` sets a distance in writing-band heights. Support is 1 up to half that distance, decreases linearly to 0 at the full distance, and remains 0 beyond it. Bundled profiles use 0.05. These are weighted geometric support measures, not recognized-letter accuracy percentages.
4. Refine translation through at most five nearest-edge iterations. Keep a candidate only if neither support measure decreases and at least one improves. Equal-support candidates leave the existing fit unchanged. This improves alignment for wobbly traces without pulling an already complete trace away merely because extra ink was added. It never rotates, changes the uniform scale, merges strokes or edits the actual drawing.
5. Multiply the existing shape/position/height composite by both support factors. Matching the writing area's height and position therefore cannot supply 40 points independently of ink matching. The UI shows **Ink near example** and **Example covered** alongside the existing components.

`geometry-v1` remains supported for older imported guides, with its original fitting and formula. Its 36-record baseline JSON is unchanged, and the compatibility test explicitly selects v1. Unsupported algorithms are rejected. V2 requires an explicit finite matching tolerance; v1 rejects that unused parameter. Results serialize algorithm, guide revision, profile and the optional new support measures.

## Reproduction and results

```sh
python3 scripts/test-portable.py
python3 scripts/probe-ink-support.py > /tmp/cursive-ink-support.json
python3 scripts/probe-scoring.py > /tmp/cursive-current-scores.json
```

The new probe compiles the exact app sources and exports 150 records: all 12 lessons, every bundled profile, ten synthetic cases, a 700 × 320 canvas, component scores, guide/profile identity, source commit and tracked-change status. No personal handwriting is stored. The existing probe still supports `--baseline 3f04013` for the historical 1.2 implementation.

| Synthetic input | Nine word lessons, Explore | Stroke Lab, Explore | Stroke Lab, Precise |
| --- | ---: | ---: | ---: |
| Exact model | 100 | 100 | 100 |
| 2%-of-band-height point jitter | 97.42–99.37 | 99.63–99.85 | 98.89–99.50 |
| Dense crosshatch | 8.69–15.08 | 8.18–36.23 | 6.94–34.92 |
| Zigzag | 9.91–13.50 | 7.41–37.88 | 6.20–36.57 |
| Seeded random scribble | 13.67–17.14 | 9.04–39.96 | 7.88–38.53 |
| Exact trace plus crosshatch | 27.78–33.37 | 19.23–46.00 | 16.95–44.62 |
| First half of each path | 1.70–6.32 | 6.64–57.61 | 6.09–54.57 |
| Reverse direction | 100 | 100 | 100 |
| Reverse whole-stroke order | 100 | 100 | 100 |
| Trace twice | 98.99–100 | 100 | 100 |

The random case uses seed 42. Regression tests also use seeds 1 and 2026, compact/wide canvases, all profiles for faithful/jittered traces, extra ink after a complete trace, missing visible ranges, serialization and collinear resampling. The new unrelated-ink test first reproduced 30 high-score failures on the old implementation. The engineering guardrails require these unrelated cases below 50, trace-plus-crosshatch below 60, and the tested wobbly traces above 90. These thresholds are provisional regression expectations, not passing grades for students.

The spatial-index review fix preserves all 900 numeric components across the 150 probes when compared with exhaustive edge queries under the same fitting policy. A dense regression uses 5,000 horizontal edges and 100 queries: each exact result checks at most 16 edges, with separate assertions for diagonal projection, erased gaps and equal-support fitting stability. This measures query work rather than asserting a hardware-dependent latency threshold.

## Limits and next acceptance

This is geometric comparison, not spelling recognition or calibrated handwriting instruction. Reversing stroke order is a no-op for the single-path word models and meaningful for Stroke Lab; both still score highly because v2 does not grade order or direction. Retracing is not automatically an error. Partial paths can retain moderate scores, especially for small glyphs. An unrelated word with similar geometry may still match; OCR is a separate diagnostic. Point sampling approximates support and can miss very small features. Index construction grows with drawing size, and heavily overlapping edge bounds can still require more comparisons; actual iPad latency needs validation.

The guide's stroke expectations and first five letter shapes still need the planned instructional review. Nothing here establishes Zaner-Bloser alignment. The 1.3 user tracing result is not evidence for this new version; new iPad acceptance is required.

On the same iPad, pair careful traces with dense scribbles, unrelated words, partial letters and a good trace followed by extra scribbles. Repeat after Clear/lesson/profile/guide changes. Record the visible version, guide revision/profile, target, all five components and orientation. Confirm comfortable paper positioning before and after evaluation. Keep [CURS-20](https://tasteslikegood.atlassian.net/browse/CURS-20) and [CURS-21](https://tasteslikegood.atlassian.net/browse/CURS-21) open until the relevant device evidence is reviewed.
