# Technical model source assessment — 2026-10-07

Sprint 119, CURS-6 and CURS-8. The user selected Zaner-Bloser as the instructional reference. This selection does not turn the existing project curves into publisher models. Handwriting Without Tears remains a marketplace reference only.

## Candidates

| Source | Format and coverage | Stroke/connection information | Reuse and decision |
| --- | --- | --- | --- |
| [Zaner-Bloser Grade 3 teacher sample](https://www.zaner-bloser.com/sites/default/files/2025-03/Zaner-Bloser-Handwriting-G3-Teacher-Edition-Sample.pdf), [resource directory](https://www.zaner-bloser.com/handwriting/zaner-bloser-handwriting/free-resources) | Educational PDF and printable materials; sample is not a complete machine-readable alphabet | Basic stroke families, joining categories and selected letter demonstrations | Publisher rights notices apply; no asset redistribution permission established. Use as the instructional reference; do not ship its images or trace its pages into this package |
| [TypeTogether Playwrite](https://github.com/TypeTogether/Playwrite) | Regional handwriting font sources, including US Traditional; font outlines and variable-font development sources | Useful evidence of regional/style variation; no reviewed Zaner-Bloser teaching-stroke contract established in this assessment | [SIL OFL 1.1](https://github.com/TypeTogether/Playwrite/blob/main/OFL.txt) is included. Candidate for a later font/rendering investigation; no assets adopted |
| [Apple PencilKit drawing sample](https://developer.apple.com/documentation/PencilKit/inspecting-modifying-and-constructing-pencilkit-drawings), [WWDC20 session](https://developer.apple.com/videos/play/wwdc2020/10148/) | Sample drawing/stroke data and application code; demonstration alphabet | Demonstrates assembling letters into a word and working with ordered stroke paths | Architectural reference; not evidence of curriculum alignment or permission to relabel its alphabet. No sample assets adopted |
| Existing project curves | Five lowercase glyphs: e, h, l, o, p; cubic paths; all nine lesson words | Ordered single paths and common baseline endpoints; illustrative connections | Original project material under MIT. Migrated without geometry changes into `prototype-cursive` revision 1 as the reproducible comparison model |

Recommendation: **create the instructional stroke model**, using reviewed formation/connection decisions and explicitly documented provenance. This search did not establish a ready-made, reusable Zaner-Bloser technical model. A font is not sufficient evidence of teaching stroke order or joins. The implemented guide engine accepts independent data so later research does not require rewriting per-letter code.

## First five models and alignment review

All five source records are in [prototype-cursive.json](../CursivePrototype.swiftpm/Guides/prototype-cursive.json); the [generated visual](primer-reference.svg) is checked directly against runtime samples. Each has one ordered path, enters at `(0, 1)` and exits at `(advance, 1)`.

| Glyph | Advance | Cubics | Review finding on current project model |
| --- | ---: | ---: | --- |
| e | 0.65 | 3 | Small loop; baseline exit needs review against the selected reference |
| h | 0.90 | 5 | Tall loop and small shoulder; proportions and connection variants remain unreviewed |
| l | 0.65 | 3 | Tall loop; entry, slant and exit conventions remain unreviewed |
| o | 0.80 | 4 | Oval and baseline-ending connector; contextual exit shape remains unreviewed |
| p | 0.85 | 5 | Descender to 1.35 model units; retrace, proportions and joins remain unreviewed |

The teacher sample's lowercase **e** page (printed page 37, PDF page 19) illustrates an ending upstroke reaching the midline. Our model ends on the baseline. The sample also distinguishes several join categories. This is evidence against declaring a single baseline endpoint convention aligned with the selected curriculum. The sample does not settle every first-five stroke/connection decision in a form ready for this engine. An educator/model review is still required.

The schema now makes endpoints, lifts and per-pair connections explicit, but supports only coincident continuous endpoints or a lift. Contextual connectors and glyph variants need a subsequent contract/composer extension before a fully aligned alphabet. We deliberately retain the original five shapes and their revision instead of inventing alignment or changing scores under the same model identity.

## Sprint disposition

CURS-6 has a source/reuse assessment and find-versus-create decision. CURS-7 has a working schema, examples and validation. CURS-8 has source-traceable model data, generated visual, shared runtime paths and documented review gaps; **Zaner-Bloser alignment remains open**. No publisher assets, font dependencies, accreditation claims or new validated educational grades are included.
