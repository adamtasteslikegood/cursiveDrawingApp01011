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

## Next iteration — guide foundation and scoring evidence

The 1.2 device trial is recorded in `docs/ipad-prototype-1.2-evaluation.md`: lessons/animations and feedback display work; scoring is not accepted. The next priority is a technical style-guide model and an engine that consumes it.

1. Reproduce the reported high matches for unrelated ink and low matches for careful traces; capture component scores and reset/repeated-attempt behavior without assuming a cause.
2. Find or create a source-traceable Zaner-Bloser-aligned model; decide the first supported guide content, starting with the current five letters and representative connections.
3. Define and validate an interchangeable guide contract covering glyph inventory, language/script, style, skill level, geometry, instructions, and assessment capabilities.
4. Route lesson composition, guides, examples/replay, and assessment through the selected versioned guide. Use a second small test guide to expose embedded style assumptions.
5. Establish reviewed evaluation fixtures and preserve explicit uncertainty. A new data format alone does not fix scoring or establish educational validity.
6. Reserve extension points for personalized learning models and separate penmanship/font capture. ML, font generation, full language support, and additional lesson families remain future implementation.
