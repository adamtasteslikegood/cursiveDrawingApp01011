# Device validation

Record package commit, iPad model, iPadOS version, Swift Playgrounds version, and input device for each run.

- Open the root-level package and launch without errors; confirm the current package revision is visible (`Lesson prototype 1.4 · 2026-10-07` for this iteration).
- Confirm lined paper and canvas remain usable in portrait and landscape, including compact iPhone landscape; scroll the full lesson to reach controls and all results.
- On first launch and after window reattachment, confirm the tool picker appears; write with touch and Apple Pencil where available and check pen and eraser.
- Evaluate a nonempty drawing; confirm drawing, erasing, and lasso edits are blocked while analyzing, then resume after completion; confirm feedback matches the frozen ink.
- Evaluate an empty canvas; confirm the prompt to write first.
- Clear the canvas; confirm drawing and old results disappear.
- Write repeated letters such as “loop”; verify all four feedback rows appear.
- Write “look”, “lop”, and “loopx”; verify substitutions, omissions, and extras receive explicit feedback.
- Write away from the canvas origin and move/resize/rotate ink; check segmentation remains aligned with visible handwriting.
- After a successful evaluation, erase all ink and evaluate again; confirm the previous score is replaced by the empty-input message.
- Check fast-mode OCR and character boundaries on real cursive writing; record recognition and segmentation limitations.
- Confirm low-quality or unrecognized input does not freeze or crash the app.

Keep findings in the PR. Scores, timing, teacher templates, and target-text alignment remain experimental; passing these checks does not validate educational accuracy.

## Guided lesson 1.1

- Try loop, pool, and hello. Confirm changing words clears ink/results and each thumbnail matches its trace guide.
- Confirm the centered band has solid top/baseline and a dashed middle line. Verify l/h rise to the top, o/e fit the lower half, and p descends below the baseline.
- Replay the example and check it draws once; with Reduce Motion enabled, verify a static example remains available.
- Trace the guide, then switch it off and write independently. Record shape, vertical position, height, and OCR read separately; do not treat a high geometry match as proof of spelling/mastery.
- Check small, shifted, incomplete, and distorted words receive relevant feedback rather than an unreachable grade.
- Try Apple Pencil and finger input; verify the surrounding lesson scrolls without moving/zooming the canvas guides relative to ink.
- Rotate during evaluation; the result should be discarded with a request to evaluate again. Confirm rotation after evaluation clears stale feedback.
- Verify tool-picker availability and resumed editing after successful and failed evaluation.

## Primer/letter iteration 1.2

- Confirm all three sets contain the expected three words; changing sets/words clears ink and feedback.
- Confirm primer name/revision are visible; word/letter examples use the same illustrative forms.
- Expand letter analysis for all nine words; repeated letters need separate occurrence rows and thumbnails.
- Distort one small letter while retaining the other letters; compare its regional feedback with intact neighbours. Try omitting a middle letter and record any misleading window assignments.
- Compare a continuous word stroke with separate letter strokes whose endpoints touch; inspect join evidence without assuming pen lifts are incorrect.
- Erase part of a stroke with the partial/bitmap eraser and reevaluate; erased gaps must not appear as continuous recorded joins. Fully erased input should prompt for measurable ink.
- Confirm the accepted replay/toggle interaction and whole-word score consistency remain intact. Record region estimates separately from OCR and educational correctness.

## Guide foundation 1.3 — partial device evidence

The [owner's 1.3 report](ipad-prototype-1.3-evaluation.md) confirms high tracing scores and working Stroke Lab modes, reports continued false positives, and identifies a scroll-positioning regression. Unreported cases below remain open.

- Record exact ZIP/commit, visible version/date, device, OS, Playgrounds and input method. Preserve the original 1.2 report separately.
- Select each guide and each profile, including after writing/evaluating. Confirm ink/results clear, the selected lesson is valid, and its lines, thumbnail, replay and feedback use the same model. Check narrow portrait and wide landscape layouts.
- Stroke Lab: x has two separate strokes; xl/lx have three. Replay must move to each stroke without drawing a connecting bridge. Lifted boundaries must not report a missing continuous join as an error.
- Import `Guides/e-and-ee.example.json`. Confirm e and ee load. Attempt malformed JSON, an unsupported glyph/direction and a duplicate ID; confirm a readable error and unchanged ink/results. Imports are session-only.
- Repeat each score probe (careful trace, freehand target, unrelated word, zigzag, dense scribble) before/after Clear, lesson change, guide change, partial erasure and rotation. Record shape/position/height and OCR, not just total. Existing false positives are not fixed in this iteration.
- Test replay with trace off, reduced motion, Apple Pencil input and tool-picker behavior. Automated tests do not establish these outcomes.

## Writing-area positioning 1.3.1

- Before writing or evaluating, scroll the page until the center of the paper is near the center of the visible viewport. Confirm writing feels comfortable and Clear/Evaluate are reachable.
- Repeat after Clear, changing a word/set, changing a guide/profile, and expanding feedback then switching to the next lesson. Centering must not depend on feedback being present.
- Repeat in portrait, landscape and Split View. Confirm the outer page scrolls while ink remains registered with its guides; test Pencil writing and finger scrolling outside the paper.
- Evaluate while the paper is centered; confirm scores and all feedback remain reachable. Repeat the existing rotation-during-evaluation check.
- Recheck a careful trace and dense scribble with the same guide/profile and record components separately. This visual patch does not fix the high scribble score.

## Ink support and coverage 1.4

- Confirm bundled guide revision 2 and record guide/profile, word, orientation and Playgrounds version. Test all three word sets and both Stroke Lab profiles.
- Pair careful traces and independent target writing with dense scribbles, zigzags, unrelated words, incomplete letters and a complete trace followed by extra scribbles. Capture shape, position, height, ink near example and example covered as well as total. Synthetic expectations are recorded in [the evidence report](scoring-evidence-1.4.md); they are not device results.
- Repeat after Clear, next lesson, guide/profile changes, erasure and rotation. Trace scores should remain high and unrelated-ink scores should drop substantially compared with the 1.3 trial. Record exceptions instead of treating a single good score as calibration.
- Try retracing and separate strokes. V2 does not grade stroke direction/order or correct lifts; erased gaps must remain gaps. Inspect feedback wording and evaluation latency on both careful and dense inputs.
- Repeat the centering checks above; 1.4 includes the positioning patch. Import the e/ee example, and optionally a retained v1 guide with a distinct ID to verify compatibility; record which algorithm the file specifies when comparing results.

## Independent practice and Replay 1.5

The [1.5 owner report](ipad-prototype-1.5-evaluation.md) confirms execution, improved grading over 1.4 and Replay clearing, with approval to merge. The detailed cases below remain a checklist; unreported cases are not marked passed.

The [1.4-final report](ipad-prototype-1.4-evaluation.md) confirms comfortable centering and improved false positives in that trial; totals below 20% remain a reported defect. Validate the new version separately:

- Confirm **Lesson prototype 1.5 · 2026-10-08**, guide revision **3**, and record device/OS/Playgrounds, guide/profile, target and orientation.
- Pair a careful trace with independent writing of the same target with the trace hidden. Write slightly beside the model as well as over it. Record total, shape, position, height and any extra-ink message. Toggling the guide without changing ink must not change the result.
- Pair those attempts with scribbles, unrelated words, partial letters, a missing Stroke Lab stroke and a good attempt followed by scribbles. Preserve low false-positive behavior; report exceptions. Compare Explore and Precise geometry without assuming either is educationally calibrated.
- Draw and evaluate, hide the trace, then press Replay: ink and all prior feedback must clear, the toggle must turn on, and the animation must restart. Repeat with the trace already on, during replay, and with Reduce Motion. Replay remains unavailable during evaluation.
- Confirm that clearing/replaying/next lesson still lets the paper center comfortably. Repeat in portrait, landscape and Split View where available.
- Record evaluation latency on large drawings. Direction/order, OCR reliability and model alignment are separate unresolved capabilities.
