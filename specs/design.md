# Design — primer-aware lessons and feedback

Status: current prototype behavior plus proposed future interfaces. User-authorized lesson families are words, single letters, linking combinations, phrases, and sentences. Only single words are implemented in 1.2.

## Current model

`PracticeLesson` supplies word, focus, set, and a provisional primer descriptor. Each occurrence has a stable index, expected letter, model-space X interval, and sampled path. Examples and feedback share these points. `WritingGuide` converts model coordinates into one fixed canvas writing band. Whole-word fitting preserves aspect ratio and produces the existing shape/position/height score.

Letter feedback clips actual fitted stroke edges into expected X windows and compares each region with its reference without independently stretching that letter. This is a guided estimate, not independent character recognition. Empty/degenerate regions receive no numerical estimate. Repeated letters retain distinct occurrence IDs. Join evidence requires a continuous recorded path on both sides of the model boundary near the current primer's baseline; touching endpoints from separate strokes do not count. This observation is not an assessment of correct joining or pen-lift technique and does not change the accepted whole-word grade.

Partial masks are sampled by visible PencilKit ranges and kept separate. OCR remains a separate diagnostic. Malformed words, large missing portions, and unusual spacing can make globally fitted windows assign the wrong ink; the UI states this limitation. The current baseline-boundary heuristic must be replaced by primer-specific anchors before supporting different joining conventions.

## Proposed future lesson structure

Use a typed lesson kind and explicit text/occurrence tokens rather than passing spaces, punctuation, or unknown letters into the current glyph builder. A combination sub-lesson references its parent word and occurrence range; its entry/exit context comes from that word. Phrase/sentence lessons need word boundaries, spaces, capitals, punctuation, and line/baseline assignment before scoring. Do not implement them by concatenating unsupported characters into the existing one-line model.

## Selected instructional reference

The user adopted Zaner-Bloser for now. Align letter shapes, line proportions, stroke instructions, contextual joins, and feedback with this reference before identifying runtime models as Zaner-Bloser. Handwriting Without Tears is only a marketplace reference. Current `prototype-cursive` revision 1 remains accurate until that implementation work is complete.

## Proposed primer record

Persist primer ID/revision and provenance with each lesson and result. An adopted record should supply guide ratios, reviewed letter variants, ordered strokes, allowed pen lifts, entry/exit anchors, contextual join rules, acceptable deviations, source/reuse status, and review/calibration metadata. A selectable primer swaps rendering, lesson construction, and scoring together. Do not expose a selector for a primer whose assets/rules are absent.

## Validation

Synthetic reference and negative tests check implementation behavior, not educational validity. Preserve original word-score regression coverage; test duplicate occurrences, local distortion, missing windows, sparse crossings, pen lifts, partial masks, serialization, and compact layout. Test the new runtime on the user's iPad. Before higher-confidence instruction, evaluate against teacher-labeled samples, report ambiguity, and avoid converting uncertain geometric/recognition observations into confident corrective advice.
