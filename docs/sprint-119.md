# Sprint 119 — Model foundation

The current [CURS-1 charter](../specs/curs-1-charter.md) defines the owner's three-item review handoff, distinct from closing this Scrum sprint. [Cursivly Confluence](https://tasteslikegood.atlassian.net/wiki/spaces/CURS) holds the published project charter; [PM harness instructions](curs-1-harness.md) describe its reproducible verification.

Date: 2026-10-07. Jira: [Cursivly Scrum board](https://tasteslikegood.atlassian.net/jira/software/c/projects/CURS/boards/204/backlog). Owner/acceptance reviewer: Adam Schoen. The populated future sprint is **Cursivly 01 - Model foundation** (119); the earlier empty template sprint is not the delivery scope. Dates, capacity and estimates have not been invented.

## Delivery and acceptance

| Issue | Repository evidence | Remaining acceptance |
| --- | --- | --- |
| [CURS-6](https://tasteslikegood.atlassian.net/browse/CURS-6) source research | [Source assessment](model-source-assessment.md), primary URLs, format/coverage/reuse matrix and recommendation | Owner review of recommendation |
| [CURS-7](https://tasteslikegood.atlassian.net/browse/CURS-7) schema | [Contract](guide-format.md), actual JSON resources, validator, importable e/ee example, independent technical guide and tests | Owner review; iPad import/selection verification |
| [CURS-8](https://tasteslikegood.atlassian.net/browse/CURS-8) first five models | Original five glyphs migrated to source-traceable data, unchanged generated visual, common rendering/scoring revision, [alignment gaps](model-source-assessment.md) and [baseline score comparison](scoring-evidence-1.3.md) | Contextual model work and educational alignment review remain open; no claim of Zaner-Bloser completion |
| [CURS-17](https://tasteslikegood.atlassian.net/browse/CURS-17) 1.2 device evidence | [User evaluation](ipad-prototype-1.2-evaluation.md), reported acceptance and defects, explicit unknowns; PR #5 merged | Unreported checklist details remain unknown; new 1.3 device trial is separate |

The guide engine also advances CURS-16 without moving it into this sprint or silently adding estimates. Scoring reproduction informs CURS-20/CURS-21; no scoring defect is marked fixed. Personalized learning, fonts, full alphabet, language shaping and new lesson families remain future work.

PR #6 is merged. The [separate 1.3 iPad report](ipad-prototype-1.3-evaluation.md) adds high tracing scores and working Stroke Lab modes, confirms continued false positives, and identifies [CURS-24](https://tasteslikegood.atlassian.net/browse/CURS-24), a writing-area positioning regression. The immediate 1.3.1 patch reserves scroll space independent of feedback. These observations do not close import validation, model alignment or the unreported 1.2 checklist items. CURS-24 is tracked under Lessons UI without changing sprint dates or membership.

## Verification and handoff

Local agent-harness verification executes repository integrity, strict Swift lint/visual consistency and the portable regression suite as subprocesses. The PM delivery gate tracks the owner, acceptance and evidence. Its local plan/state live in ignored `.agent-harness/`; those tool records are not product artifacts. GitHub CI supplies the Apple build/simulator evidence and custom CodeQL checks on the PR head. Linux cannot perform Apple checks locally.

Use the PR's actual check results and ZIP artifact as delivery evidence; a local harness pass is not iPad acceptance or a closed Jira sprint. The [device checklist](device-validation.md) includes guide import, switching, multiple paths and scoring probes. Issues remain open where human/device or curriculum acceptance is outstanding.

## 1.5 acceptance and merge authorization — 2026-10-08

The [owner's 1.5 evaluation](ipad-prototype-1.5-evaluation.md) confirms that the app runs on the same setup, grades better than 1.4, and Replay clears the writing area. The owner requests merging PRs #7/#8. CURS-25/CURS-26 track these delivered improvements; earlier 1.4 evidence confirms comfortable centering for CURS-24. This is qualitative acceptance of the prototype changes, not completion of the model-foundation sprint, educational calibration, or every device-checklist case. Sprint membership, dates and estimates are unchanged; CURS-20/CURS-21 retain their recorded detailed scoring follow-ups.
