# Primary primer decision frame

Status: the user adopted **Zaner-Bloser as the primary instructional reference for now**, 2026-10-06, after reviewing both candidates. Handwriting Without Tears is retained only as a reference for the educational-material marketplace, not as a candidate instructional primer. This supersedes the earlier compare-both-first decision. Alignment of the app models and feedback with Zaner-Bloser remains implementation work.

## What the app currently uses

`PracticeLesson.swift` contains `ModelGlyph.glyph`: hand-authored cubic curves for **e, h, l, o, p**. The word builder offsets and joins those paths. The thumbnail, ghost trace/replay, and geometric comparison use the same sampled points. Thus the code is the current model source; it is neither a complete alphabet nor an accredited instructional primer.

[Supported-letter visual](primer-reference.svg) is rendered directly from the active source by `python3 scripts/export-primer.py`; `--check` verifies that the committed visual still matches. Green/gray dots indicate encoded entry/exit positions. The code determines the replay path order, but that does not establish correct pedagogical stroke order, pen-lift rules, or permissible joins.

## Evidence and candidate references

| Reference | What it supplies | Decision relevance |
| --- | --- | --- |
| [IES / What Works Clearinghouse writing practice guide](https://ies.ed.gov/ncee/wwc/practiceguide/17) | An evidence-rated recommendation for handwriting fluency within writing instruction; the full guide discusses explicit letter formation and practice | Use for instructional principles, not as a canonical alphabet, an endorsement of our scores, or proof that one commercial style is best |
| [Zaner-Bloser grade 4 teacher sample](https://www.zaner-bloser.com/sites/default/files/2025-03/Zaner-Bloser-Handwriting-G4-Teacher-Edition-Sample_0.pdf), [publisher resources](https://www.zaner-bloser.com/handwriting/zaner-bloser-handwriting/free-resources) | Visual cursive models, basic strokes, letter families, joining instruction, and teacher materials | Selected primary instructional reference; align letter entry/exit rules and guide proportions with our models |
| [Handwriting Without Tears curriculum](https://www.lwtears.com/solutions/writing/handwriting-without-tears) | Publisher describes a vertical cursive style, explicit instruction, connections, and student/teacher resources; also shows double-line teaching materials | Educational-material marketplace reference only; not selected for letter forms, lessons, or scoring |

These are primary institutional/publisher sources. This research establishes available instructional references, not accreditation or independent validation of a particular alphabet or this application's scoring. Publisher materials have not been copied into the app; asset reuse permission and digital adaptation suitability remain unconfirmed.

## First comparison

| Dimension | Zaner-Bloser sample/resources | Handwriting Without Tears publisher materials |
| --- | --- | --- |
| Visual approach | Sample uses slanted forms and baseline/midline guidance | Publisher describes vertical cursive and double-line teaching materials |
| Instruction | Basic-stroke families and explicit formation/legibility work | Teacher scripts, developmental sequence, and connection practice |
| Join policies | Sample explicitly distinguishes uppercase letters that join from those that do not, including P/B versus R | Connection teaching is explicit; detailed letter-specific exceptions need review of the instructional materials |
| Visual source | Public teacher PDF models and references to portal animations | Grade-level student/teacher previews and connecting-cursive posters linked from the official curriculum page |
| App adoption gap | Digital vector source, reuse permission, reviewer, and calibration are not established | Same gaps; line geometry and style must also remain consistent with the chosen method |

This comparison uses the linked [Zaner-Bloser sample](https://www.zaner-bloser.com/sites/default/files/2025-03/Zaner-Bloser-Handwriting-G4-Teacher-Edition-Sample_0.pdf) and [Handwriting Without Tears materials](https://www.lwtears.com/solutions/writing/handwriting-without-tears), not a head-to-head effectiveness study. Neither supplies our current numeric scoring rubric. The next model review should map the same five letters and representative joins to Zaner-Bloser, documenting entry/exit/lift rules, guide proportions, and acceptable variants. The curriculum choice is settled for now; model alignment and educational validation remain outstanding.

## Adopted direction

Use **Zaner-Bloser** to guide the next instructional models and lessons. Keep the runtime labeled **Prototype primer, revision 1** until its curves, guides, stroke instructions, and feedback have been aligned and reviewed; changing the label alone would misrepresent the implemented model. Seek an educator's review of representative letters, entry/exit strokes, joins, pen lifts, line proportions, and word samples during that alignment. Evaluate readability, usability with Pencil/finger input, permitted stylistic variation, lesson sequence, and source/reuse provenance. Do not blend conflicting shape or joining rules from different curricula into an unnamed “correct” model.

A future choice of primers is a design requirement to preserve, not a currently implemented selector. Switching a primer must switch its guide geometry, examples, stroke instructions, join policies, and scoring references together. Feedback should identify the chosen primer and revision. One learner's accepted form in one primer must not be silently judged by another primer's model.

## Data needed before stronger instruction

Each adopted primer needs stable ID/revision, named source, asset provenance and reuse status, reviewer/review date, letter-family sequence, guide ratios, ordered stroke paths and allowed lifts, entry/exit anchors, context-sensitive joins/variants, acceptable deviations, and calibration examples. Record open choices instead of labeling them accepted. The current 1.2 prototype carries only provisional primer identity and geometry evidence; it does not supply the missing educational validation.
