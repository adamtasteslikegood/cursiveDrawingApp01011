# Plan — guided analysis iteration

Status: implementation plan for the user's 2026-10-06 direction; the user adopted Zaner-Bloser as the primary instructional reference for now after comparison; model alignment and validation remain open. Runtime acceptance of 1.1 is recorded in `docs/ipad-lesson-1.1-evaluation.md`.

## This iteration

1. Merge PR #4 with the user's successful device evaluation.
2. Preserve the accepted whole-word score, three initial words, replay/trace behavior, and standalone app package.
3. Identify the existing primer and render its five supported letters directly from code. Record the Zaner-Bloser selection and model-alignment work in `docs/primer-decisions.md` without importing publisher assets or claiming accreditation.
4. Add two sets of three single words using the existing glyphs: hope/help/peel and heel/hole/pole.
5. Add occurrence-based, explicitly experimental per-letter geometric estimates and observed join continuity. Use expected model windows after whole-word fitting, not OCR as a segmentation truth. Withhold estimates when usable ink is absent; do not treat pen lifts as automatically incorrect.
6. Respect visible PencilKit mask ranges so partial erasure does not create synthetic connecting ink.
7. Run integrity/lint, portable behavioral tests, macOS build/simulator tests, and CodeQL; deliver a version-labeled ZIP for a fresh device trial.

## Boundaries

This iteration does not implement phrase/sentence lessons, a complete alphabet, a selectable commercial primer, validated stroke-order instruction, or calibrated educational grades. Guided model-window assignment can be wrong for malformed/free-positioned words. Letter/join feedback remains a prototype requiring new device evidence and later educator review.
