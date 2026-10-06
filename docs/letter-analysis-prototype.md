# Primer-aware letter analysis prototype 1.2

Visible revision: `Lesson prototype 1.2 · 2026-10-06`; package version 1.2, bundle 3. The core 1.1 runtime was accepted in the [device evaluation](ipad-lesson-1.1-evaluation.md). This iteration requires a separate device trial.

## Lessons and primer

| Set | Words |
| --- | --- |
| 1 | loop, pool, hello |
| 2 | hope, help, peel |
| 3 | heel, hole, pole |

The three sets reuse five lowercase models, e/h/l/o/p. Both set and word changes clear the canvas/results. Trace toggling, replay automatically enabling the overlay, and the original whole-word shape/position/height score are retained.

The app and serialized feedback identify `prototype-cursive`, revision 1. This is the existing hand-authored project model, not a named educational curriculum. The [primer visual](primer-reference.svg) is exported from source; regenerate/check it with `python3 scripts/export-primer.py` / `--check`. The user has [selected Zaner-Bloser as the primary instructional reference](primer-decisions.md); alignment of the runtime curves and feedback remains future work. No publisher assets or selectable external primer are introduced.

## Experimental per-letter feedback

Each expected occurrence has its own model path, X window, index, thumbnail, and geometric estimate. The algorithm uniformly fits the whole word as before, clips each actual stroke edge into the expected model windows, and compares those regions with the corresponding reference. It does not independently stretch each letter until it matches. Sparse edges are clipped at window boundaries; separate strokes remain separate. Repeated letters get distinct rows. Empty/degenerate regions withhold a numerical estimate.

These are **guided model-region estimates**, not independently recognized letters. Missing large portions, unusual spacing, malformed words, or extra ink can shift whole-word fitting and make window assignments wrong. The UI identifies this limitation. OCR remains a separate diagnostic. Per-letter estimates do not alter the accepted whole-word score.

## Join observations and visible ink

A join observation requires one continuous recorded polyline to span both sides of an expected boundary near the current model baseline. Separate strokes that merely touch at the boundary do not satisfy it. The result describes evidence, not correct technique: a pen lift/gap can be intentional and joining rules depend on the chosen primer and letter context. No join penalty is added to the primary grade, and stroke order, speed, or educational mastery are not inferred.

Partial PencilKit masks are sampled with `maskedPathRanges` and `interpolatedPoints(in:by:)`, with the stroke transform reset on a copy for range calculation, then transformed into drawing coordinates. The iOS 18.5 simulator returned no ranges for the translated fixture despite two ranges before translation; computing ranges in path coordinates avoids that framework behavior. Each visible range remains a separate path so erased gaps cannot manufacture joins. Fully masked ink with no usable ranges produces a visible-ink error rather than falling back into synthetic contour evidence. Apple documents these APIs in [PKStroke.maskedPathRanges](https://developer.apple.com/documentation/pencilkit/pkstroke-swift.struct/maskedpathranges) and [PKStrokePath.interpolatedPoints](https://developer.apple.com/documentation/pencilkit/pkstrokepath-swift.struct/interpolatedpoints(in:by:)). Unmasked extraction is unchanged to preserve the accepted baseline's score behavior.

## Validation

Portable tests cover all nine references scoring 100, one distinct high-match letter row per occurrence, missing windows, local distortion, empty ink, sparse clipped edges, disconnected excursions, touching pen lifts, and primer/result serialization. Simulator tests also verify partial masks remain separated after transforms and fully masked ink is not treated as drawable evidence, alongside the existing full-analyzer reference test.

On the iPad, verify all three sets, set/word clearing, preserved replay/toggle behavior, expanded letter thumbnails/results, joins with and without a pen lift, local letter distortion, and partial erasure. Record whole-word and letter-region feedback separately. The 1.1 device report does not validate these new cases. Future single-letter/combination/phrase/sentence work is scoped in `specs/`, with primer review and ambiguity handling still open.
