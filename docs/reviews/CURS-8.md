# CURS-8 first-five formation and connection review

Prepared 2026-10-08 for **Adam Schoen**, human owner and acceptance reviewer.
Disposition: alignment-gap proposal for In Review. Zaner-Bloser alignment remains
unaccepted. The owner selected public official references for this review; no
particular complete edition or publisher asset adaptation has been approved.

Review continuation, 2026-10-09: [PR #10](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/pull/10)
delivered this worksheet to main. Fresh Atlassian MCP reads still show CURS-8
In Review, with model alignment pending. The owner selected a fresh review
handoff. The [decision register](../curs-1-review-continuation.md) preserves
each formation and contextual-pair decision below as pending. The official
reference observations retain their original 2026-10-08 attribution.

## Acceptance evidence

All five source-traceable records are in
[prototype-cursive.json](../../CursivePrototype.swiftpm/Guides/prototype-cursive.json),
model ID `prototype-cursive`, current revision `3`. Provenance identifies original
project material and the visible metadata says **Unreviewed project model**.
Assessment revisions changed the algorithm settings, not the original glyph
curves. The models are not traced publisher assets.

The [generated visual](../primer-reference.svg) is synchronized by
`python3 scripts/export-primer.py --check`, included in lint. It loads the same
guide decoder and `PracticeLesson.modelStrokes` used by the app. Thumbnail,
ghost/replay and practice comparison obtain paths from the selected lesson's
guide; evaluation results pin guide revision and profile identity. This supplies
shared-model evidence without establishing formation correctness.

The table records actual project geometry. Top is 0, midline 0.5, baseline 1 and
descender 1.35. Each glyph has one path, enters at `(0, 1)` and exits at
`(advance, 1)`. Sampled bounds include the starting point and 24 equal-parameter
intervals per cubic, as the runtime does; they are not analytic extrema or grades.

| Glyph | Advance | Cubics / sampled points | Sampled y range | Current model observation |
| --- | ---: | ---: | --- | --- |
| e | 0.65 | 3 / 73 | 0.505840–1.041250 | Small loop; baseline exit; sampled dip below baseline |
| h | 0.90 | 5 / 121 | 0.004334–1.026378 | Tall loop and midline shoulder; baseline exit |
| l | 0.65 | 3 / 73 | 0.003721–1.027141 | Tall loop; baseline exit |
| o | 0.80 | 4 / 97 | 0.500735–1.000000 | Oval with baseline entry and ending connector |
| p | 0.85 | 5 / 121 | 0.510000–1.350000 | Descender, rising return and bowl; baseline exit |

Public official material inspected on 2026-10-08:

- [Grade 3 teacher sample](https://www.zaner-bloser.com/sites/default/files/2025-03/Zaner-Bloser-Handwriting-G3-Teacher-Edition-Sample.pdf),
  physical PDF page 19 / printed page 37: lowercase e's ending upstroke reaches
  the midline.
- [Grade 4 teacher sample](https://www.zaner-bloser.com/sites/default/files/2025-03/Zaner-Bloser-Handwriting-G4-Teacher-Edition-Sample_0.pdf),
  physical PDF page 19 / printed page 19: e and l midline endings, with
  undercurve-to-undercurve, undercurve-to-downcurve and undercurve-to-overcurve
  joining examples. Physical page 9 /
  printed ix groups e/l/h/p as undercurve beginners and o as a downcurve beginner.
  Physical pages 12–13 preview the printed h lesson 22; the visible example has
  a tall loop and a finishing undercurve to the midline. Full o/p formation rules
  are not established by these partial samples.

These are reference observations, not a complete teaching alphabet. Copyright
notices in the samples reserve reproduction rights; no artwork is copied or
redistribution permission claimed. Inspection copies were kept outside the
repository. The downloaded Grade 3 PDF SHA-256 was
`9d60f12945910545d8c0889dd4abd42d11b7a0ec40345b80730fb0653d3f8cf5`;
Grade 4 was
`0951e5fcde35846bcf7272a8ab71fb20e3f5bc3659c388b81d089a335b06f3f4`.

## Findings

There is a concrete e/l endpoint mismatch between the inspected official
examples and the current project paths. The visible h preview also warrants
formation/exit review. The samples do not settle every o/p contour, retrace,
proportion, lift or contextual join. Similar-looking loops and an alphabet-family
label cannot establish a correct model. Sampled below-baseline dips are recorded
for review; they are not proven scoring causes or automatically defects.

All 25 current ordered pair rules are continuous because the fixed endpoints
coincide. Only 13 pairs occur in the nine lessons:
`ee`, `el`, `he`, `ho`, `le`, `ll`, `lo`, `lp`, `ol`, `oo`, `op`, `pe`, `po`.
The pair rule proves composability of the existing data, not educational approval
of a join. The publisher's different joining categories cannot be represented
faithfully by relabeling this universal baseline rule.

[Schema 1](../guide-format.md) has no contextual glyph variants or bridging
connector curves. Changing an e/l exit to the midline while retaining a following
baseline entry can violate continuous endpoint validation. Resolve this contract
dependency with [CURS-7](CURS-7.md) and CURS-9 before creating reviewed forms.
Rendering and scoring must retain separate strokes and visible mask ranges;
flattening separate paths would introduce ink that was never supplied.

The original [1.3 migration evidence](../scoring-evidence-1.3.md) locks 36 baseline
records, not desired scores. Current [1.5 evidence](../scoring-evidence-1.5.md)
describes geometric form/length scoring and negative regressions. Neither grades
stroke order, direction, lifts or spelling, nor validates teacher judgments. This
review changes no curve, scoring formula or expected regression score.

## Decision requested

Adam Schoen: use the following worksheet to record formation and connection
decisions, the approving reviewer and the selected source pages. Each row remains
pending; this agent packet is not a completed educational review.

| Review unit | Decision needed | Current status |
| --- | --- | --- |
| e | Choose entry/exit convention, loop proportions and permitted retracing using the Grade 3/4 examples | Pending owner/model review |
| h | Confirm complete formation, tall-loop/shoulder proportions and finishing stroke beyond the partial preview | Pending owner/model review |
| l | Review tall-loop proportions/slant and midline ending, with contextual connection behavior | Pending owner/model review |
| o | Obtain and review full formation/exit rules; distinguish initial letter-family stroke from context-dependent entry | Pending complete reference and review |
| p | Obtain and review full formation, retrace, descender, bowl, lifts and exit | Pending complete reference and review |
| 13 used pairs | Assign reviewed join categories, alternate forms/connectors and allowed lifts for every listed pair | Pending reference mapping and CURS-9 decision |
| Guide and tolerance profile | Review line ratios and acceptable smooth variations separately from exact tracing | Pending educational and device evidence |

Choose the reference scope and approve or request a proposed contract/model
extension before implementation. Any reviewed geometry needs a new immutable
revision or distinct guide identity, regenerated visual, behavioral evidence,
Apple checks and appropriate iPad observations. Preserve the original project
baseline for comparisons.

## Remaining acceptance

The original source records, generated reference and shared revision are present.
The remaining criterion is reviewed Zaner-Bloser formation and contextual
connection alignment, including the uncertainties above. Adam's decision and any
educator/model review must be attributable; field labels and green checks cannot
replace that decision.

The [1.5 owner device report](../ipad-prototype-1.5-evaluation.md) confirms app
execution, improved grading and Replay clearing. It does not complete the
formation worksheet, calibrate scores or report all guide-import cases. Keep the
[device checklist](../device-validation.md) and scoring work separately open.
The review PR will link this packet, the
[CURS-1 charter](../../specs/curs-1-charter.md) and current verification; CURS-8
can remain In Review with these explicit gates rather than claim accepted
alignment.
