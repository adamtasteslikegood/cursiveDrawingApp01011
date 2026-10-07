# Device validation

Record package commit, iPad model, iPadOS version, Swift Playgrounds version, and input device for each run.

- Open the root-level package and launch without errors; confirm the current package revision is visible (`Lesson prototype 1.3 · 2026-10-07` for this iteration).
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

## Guide foundation 1.3 — new device evidence required

- Record exact ZIP/commit, visible version/date, device, OS, Playgrounds and input method. Preserve the original 1.2 report separately.
- Select each guide and each profile, including after writing/evaluating. Confirm ink/results clear, the selected lesson is valid, and its lines, thumbnail, replay and feedback use the same model. Check narrow portrait and wide landscape layouts.
- Stroke Lab: x has two separate strokes; xl/lx have three. Replay must move to each stroke without drawing a connecting bridge. Lifted boundaries must not report a missing continuous join as an error.
- Import `Guides/e-and-ee.example.json`. Confirm e and ee load. Attempt malformed JSON, an unsupported glyph/direction and a duplicate ID; confirm a readable error and unchanged ink/results. Imports are session-only.
- Repeat each score probe (careful trace, freehand target, unrelated word, zigzag, dense scribble) before/after Clear, lesson change, guide change, partial erasure and rotation. Record shape/position/height and OCR, not just total. Existing false positives are not fixed in this iteration.
- Test replay with trace off, reduced motion, Apple Pencil input and tool-picker behavior. Automated tests do not establish these outcomes.
