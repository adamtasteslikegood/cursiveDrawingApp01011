# Design — primer-aware lessons and feedback

Status: current prototype behavior plus proposed future interfaces. User-authorized lesson families are words, single letters, linking combinations, phrases, and sentences. Only single words are implemented in 1.2. The user's 1.2 device trial confirms lesson presentation and animations, while reporting misleading scoring; see `docs/ipad-prototype-1.2-evaluation.md`.

## Current model

`PracticeLesson` supplies word, focus, set, and a provisional primer descriptor. Each occurrence has a stable index, expected letter, model-space X interval, and sampled path. Examples and feedback share these points. `WritingGuide` converts model coordinates into one fixed canvas writing band. Whole-word fitting preserves aspect ratio and produces the existing shape/position/height score.

Letter feedback clips actual fitted stroke edges into expected X windows and compares each region with its reference without independently stretching that letter. This is a guided estimate, not independent character recognition. Empty/degenerate regions receive no numerical estimate. Repeated letters retain distinct occurrence IDs. Join evidence requires a continuous recorded path on both sides of the model boundary near the current primer's baseline; touching endpoints from separate strokes do not count. This observation is not an assessment of correct joining or pen-lift technique and does not change the accepted whole-word grade.

Partial masks are sampled by visible PencilKit ranges and kept separate. OCR remains a separate diagnostic. Malformed words, large missing portions, and unusual spacing can make globally fitted windows assign the wrong ink; the UI states this limitation. The current baseline-boundary heuristic must be replaced by primer-specific anchors before supporting different joining conventions.

## Proposed future lesson structure

Use a typed lesson kind and explicit text/occurrence tokens rather than passing spaces, punctuation, or unknown letters into the current glyph builder. A combination sub-lesson references its parent word and occurrence range; its entry/exit context comes from that word. Phrase/sentence lessons need word boundaries, spaces, capitals, punctuation, and line/baseline assignment before scoring. Do not implement them by concatenating unsupported characters into the existing one-line model.

## Selected instructional reference

The user adopted Zaner-Bloser for now. Align letter shapes, line proportions, stroke instructions, contextual joins, and feedback with this reference before identifying runtime models as Zaner-Bloser. Handwriting Without Tears is only a marketplace reference. Current `prototype-cursive` revision 1 remains accurate until that implementation work is complete.

## Required interchangeable guide architecture

User direction, 2026-10-06: the app must adapt to supplied guides. A guide is a versioned technical model plus its instructional/evaluation rules, not merely a font or UI theme. Zaner-Bloser is the first selected instructional reference; the engine must not assume its style or five-letter inventory universally.

The proposed guide contract includes:

- Stable guide ID/revision, language/script, supported glyph inventory and contextual variants, writing direction, and explicit unsupported-glyph handling.
- Coordinate conventions, guide-line ratios, letter paths, ordered strokes, allowed lifts, entry/exit anchors, and context-specific connections.
- Style and skill-level profiles, instructions, demonstration data, assessment capabilities, calibrated tolerances, and uncertainty policies. Skill levels must have documented teaching goals rather than unexplained score inflation.
- Source/reuse provenance and review/calibration status. A new guide is not accepted merely because its data parses.

Lesson composition, guide lines, thumbnails, replay, segmentation, and feedback must all consume the selected guide revision. Results retain guide/style/level identity. Supported model data should be changeable without editing an engine switch for each letter or style. Language/script handling needs explicit capabilities; changing a label cannot establish language support.

Guide loading/schema validation, model geometry, lesson composition, rendering/replay, and assessment should have separate responsibilities while the Playgrounds package stays standalone. Exact module/file structure and serialization format remain implementation decisions. The next model work starts with the five existing letters and representative joins, with at least a second small project-owned test guide to verify that the engine does not embed one style's assumptions.

## Future personalized guides and font capture

The user requests future learned guides for personalized teaching and penmanship capture for custom fonts. Preserve space for user-specific model revisions, provenance, consent, and separate capture/training/export flows; these are not implemented in 1.2. Keep the instructional reference identifiable alongside any personalized model. Record what adaptation changes and why, and freeze the assessed guide revision during each attempt so feedback is reproducible.

Proposed safeguards: personal handwriting capture/training is opt-in; model updates are reviewable/resettable; font exports retain their source/reuse provenance. A font's glyph outlines and metrics are distinct from the ordered strokes and instructional rules needed to teach handwriting. Machine learning architecture, storage, supported scripts, and font formats remain open implementation choices.

## Proposed primer record

Persist primer ID/revision and provenance with each lesson and result. An adopted record should supply guide ratios, reviewed letter variants, ordered strokes, allowed pen lifts, entry/exit anchors, contextual join rules, acceptable deviations, source/reuse status, and review/calibration metadata. A selectable primer swaps rendering, lesson construction, and scoring together. Do not expose a selector for a primer whose assets/rules are absent.

## Validation

Synthetic reference and negative tests check implementation behavior, not educational validity. Preserve original word-score regression coverage; test duplicate occurrences, local distortion, missing windows, sparse crossings, pen lifts, partial masks, serialization, and compact layout. The 1.2 iPad report confirms displayed lessons/animations and feedback rows but reports around 70% for unrelated ink and at most about 85% for tracing. Reproduce both findings with fixed input sequences; include repeated attempts and ink/result reset cases. Test exact model paths, traces, dense scribbles, unrelated words, and reviewed stylistic variants under a fixed guide revision. Do not invent a score cutoff from one report. Before higher-confidence instruction, evaluate against teacher-labeled samples, report ambiguity, and avoid converting uncertain geometric/recognition observations into confident corrective advice.
