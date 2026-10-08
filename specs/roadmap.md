# Roadmap

User-directed progression, updated 2026-10-07. Order below is proposed; timing is not settled. The user selected Zaner-Bloser as the primary instructional reference for now.

| Stage | Deliverable | Acceptance evidence |
| --- | --- | --- |
| Accepted baseline | 1.1: three word lessons, guides, ghost replay, consistent whole-word practice score | User's iPad report; advanced per-letter feedback explicitly excluded |
| Guide foundation | 1.3: versioned guide/profile data, validated session imports and independent Stroke Lab | PR #6 merged with passing Apple CI; iPad reports about 98% tracing and working Stroke Lab modes, but scribbling still scores about 75%; full checklist and scoring acceptance outstanding |
| Immediate usability patch | 1.3.1: writing area can scroll toward the viewport center without needing feedback | [CURS-24](https://tasteslikegood.atlassian.net/browse/CURS-24); repeat centering before evaluation and after Clear/lesson/guide/profile changes; device acceptance pending |
| Owner-selected analysis follow-up | 1.4: guide-controlled ink support/coverage to reduce scribble scores and preserve traces | [Synthetic evidence](../docs/scoring-evidence-1.4.md), preserved v1 compatibility, paired real iPad trials still required for CURS-20/CURS-21 |
| Primary primer | Align models and lessons with the selected Zaner-Bloser reference; review rights/provenance, full models, stroke/lift and join rules | User selection recorded; model alignment, qualified educational review, and calibration outstanding |
| Letters and combinations | Single-letter lessons and two-or-more-letter joins as sub-lessons of a containing word | Parent word linkage, primer-consistent entry/exit strokes, contextual joins and allowed pen lifts |
| Advanced analysis | More reliable segmentation, stroke order/direction, spacing, slant, and contextual connection feedback | Labeled teacher-reviewed samples, missing/extra/ambiguous cases, agreement measures and explicit uncertainty |
| Phrases | Multiple words with spacing and word boundaries | No scoring of spaces as glyphs, per-word/letter results, unchanged primer identity |
| Sentences | Capitalization, punctuation, wrapping, and multi-line baselines | Reviewed uppercase/punctuation models, line assignment and iPad layout tests |
| Interchangeable guides | Schema 1 engine and second technical guide implemented in 1.3; expand capabilities when supported by model data | Import checks and owner review remain open; unsupported shaping/contextual variants are explicitly rejected |
| Personalized models and font capture | Future learned user-style guides, adaptive teaching, and separate penmanship/font capture | Consent/provenance, reproducible model revisions, reviewable adaptation, and distinct instructional/font outputs |

The guide foundation is implemented; the owner selected scribble rejection with preserved tracing as the next priority. Version 1.4 provides an engineering candidate and paired evidence for device review. Continue first-five-letter and contextual-join review (CURS-8/CURS-9) before expanding curriculum claims. Stroke order/direction (CURS-11) needs explicit model expectations and ambiguous/missing-stroke cases, not inference from a high whole-word score.

No milestone is complete merely because it appears here. Adding words with the same five glyphs increases practice variety, not alphabet coverage or educational validation.
