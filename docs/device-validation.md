# Device validation

Record package commit, iPad model, iPadOS version, Swift Playgrounds version, and input device for each run.

- Open the root-level package and launch without errors.
- Confirm lined paper and canvas remain usable in portrait and landscape.
- Write with touch and Apple Pencil where available; check picker, pen, and eraser.
- Evaluate a nonempty drawing; confirm progress finishes and feedback is readable.
- Evaluate an empty canvas; confirm the prompt to write first.
- Clear the canvas; confirm drawing and old results disappear.
- Write repeated letters such as “loop”; verify all four feedback rows appear.
- Write “look”, “lop”, and “loopx”; verify substitutions, omissions, and extras receive explicit feedback.
- Write away from the canvas origin and move/resize/rotate ink; check segmentation remains aligned with visible handwriting.
- After a successful evaluation, erase all ink and evaluate again; confirm the previous score is replaced by the empty-input message.
- Check fast-mode OCR and character boundaries on real cursive writing; record recognition and segmentation limitations.
- Confirm low-quality or unrecognized input does not freeze or crash the app.

Keep findings in the PR. Scores, timing, teacher templates, and target-text alignment remain experimental; passing these checks does not validate educational accuracy.
