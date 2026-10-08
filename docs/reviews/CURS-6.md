# CURS-6 source decision review

Prepared 2026-10-08 for **Adam Schoen**, human owner and acceptance reviewer.
Disposition: proposal for In Review; the source recommendation has not been
accepted. The original Jira acceptance criteria remain authoritative.

## Acceptance evidence

The [source assessment](../model-source-assessment.md) and
[primer decisions](../primer-decisions.md) establish the selected instructional
reference and distinguish it from the project's runtime curves. The owner has
authorized public official references for this review. The following inventory
was checked against publisher, repository and Apple sources on 2026-10-08;
coverage describes the inspected material, not an inferred complete dataset.

| Candidate and source | Format and alphabet coverage | Stroke and connection information | Reuse status and suitability |
| --- | --- | --- | --- |
| [Zaner-Bloser Grade 3 teacher sample](https://www.zaner-bloser.com/sites/default/files/2025-03/Zaner-Bloser-Handwriting-G3-Teacher-Edition-Sample.pdf) and [Grade 4 teacher sample](https://www.zaner-bloser.com/sites/default/files/2025-03/Zaner-Bloser-Handwriting-G4-Teacher-Edition-Sample_0.pdf) | Public teaching PDFs, 34 and 32 physical pages respectively; selected formation and joining lessons, not a complete machine-readable alphabet | e/l midline endings and several joining categories are visible; some h instruction is visible in a lesson preview. Full o/p formation decisions were not established from these samples. No ordered vector-stroke contract was found in the inspected material | Copyright notices reserve reproduction rights. No permission to redistribute or adapt publisher assets into this app has been established. Use links and review observations; no publisher artwork is adopted |
| [Zaner-Bloser free resources](https://www.zaner-bloser.com/handwriting/zaner-bloser-handwriting/free-resources) | Directory of printable activities and writing paper | Useful instructional material; the directory does not establish a reusable digital alphabet with anchors, lifts and contextual joins | Public access alone does not establish digital adaptation permission; no assets adopted |
| [TypeTogether Playwrite](https://github.com/TypeTogether/Playwrite) | Regional handwriting font development sources, Latin typefaces including US Traditional; actual selected-font inventory would require a separate audit | Font outlines, alternates and variation mechanisms offer shaping research; they do not establish a reviewed Zaner-Bloser teaching-stroke sequence or this engine's glyph/anchor contract | Repository includes [SIL OFL 1.1](https://github.com/TypeTogether/Playwrite/blob/main/OFL.txt). Any adoption must preserve applicable license conditions and audit the chosen assets. Retain as a font investigation candidate; no assets adopted |
| [Apple PencilKit drawing sample](https://developer.apple.com/documentation/PencilKit/inspecting-modifying-and-constructing-pencilkit-drawings) and [WWDC20 demonstration](https://developer.apple.com/videos/play/wwdc2020/10148/) | Drawing/stroke API and demonstration letters; no complete instructional alphabet verified | Shows ordered path manipulation and assembling letters into words | Architectural reference, without an established Zaner-Bloser curriculum or adaptation decision. No sample alphabet adopted |
| Existing [project guide](../../CursivePrototype.swiftpm/Guides/prototype-cursive.json) | Original e/h/l/o/p cubic paths, nine words, normalized coordinates; current guide revision 3 | One continuous path per glyph, explicit baseline anchors and all 25 ordered continuous pair rules; educational correctness is unreviewed | Project material under the repository MIT license. Reproducible engineering baseline; metadata remains an unreviewed project model |
| [Handwriting Without Tears](https://www.lwtears.com/solutions/writing/handwriting-without-tears) | Publisher curriculum and marketplace materials | Publisher describes vertical cursive and connection instruction; detailed digital stroke data was not established | Marketplace reference only under the owner's primer decision; not a candidate for the app's selected instructional forms |

## Findings

The inspected sources did not establish a ready-made, reusable Zaner-Bloser
technical dataset that supplies this app's full model contract. That is a bounded
research finding, not a claim that no such dataset exists. A font's display
outline cannot by itself determine teaching stroke order, lifts, entry/exit
anchors, permitted variants or accepted learner deviations.

The public samples also expose an existing alignment gap: e and l ending at the
midline cannot be represented as the current universal baseline-ending convention
without changing models and reviewing their connections. The detailed observations
and reference pages belong in the [CURS-8 packet](CURS-8.md).

The earlier source assessment describes the original revision-1 migration.
Current bundled data is revision 3 because assessment settings changed; the five
glyph curves remain unchanged. No candidate was installed as a scoring reference
by this review. The existing model remains an illustrative project baseline.

## Decision requested

Adam Schoen: review the recommendation to **create an original instructional
stroke model from reviewed formation and connection decisions**, using official
Zaner-Bloser references as the first instructional basis. Record whether to
approve this direction, request further source research, or obtain a specific
edition and adaptation permission. This packet does not record approval.

Before authoring, identify the reference edition/pages, permissible adaptation,
reviewer, five-letter formation rules, guide ratios, contextual pair behavior and
acceptable variation. Keep provenance for newly authored paths separate from
publisher artwork. Review the CURS-7 contract gaps and CURS-9 connection dependency
before committing to a model the engine cannot faithfully render.

## Remaining acceptance

CURS-6 can be accepted only after the human reviews this inventory, its explicit
missing data and the find-versus-create recommendation. A decision should identify
its source and the approved next action. A technical model is not educationally
validated merely because its provenance fields exist.

The implementing PR will contain this packet and the
[CURS-1 charter](../../specs/curs-1-charter.md), with repository integrity, lint,
portable behavioral evidence and current-head Apple CI/CodeQL linked in its
description. This change is documentation and delivery tooling; physical-device
and educational acceptance remain separate. Existing source and archived
reference documents are preserved.
