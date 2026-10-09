# CURS-1 model foundation charter

Updated: 2026-10-09. Human owner, acceptance reviewer and escalation contact: **Adam Schoen**. Agent role: contributor. Project home: [Cursivly Confluence](https://tasteslikegood.atlassian.net/wiki/spaces/CURS).

## Goal

Prepare a reviewable foundation for a versioned, interchangeable handwriting model, with Zaner-Bloser as the first instructional reference. Preserve the original five project curves until formation, connections, provenance and educational alignment have been reviewed. The engine must remain independent of a particular style, skill level, language or glyph inventory.

[CURS-1](https://tasteslikegood.atlassian.net/browse/CURS-1) is an **epic**, not a Scrum sprint. The three active children identified by the owner are CURS-6, CURS-7 and CURS-8. They belong to Scrum sprint **119, Cursivly 01 - Model foundation**, on [board 204](https://tasteslikegood.atlassian.net/jira/software/c/projects/CURS/boards/204/backlog). The empty sprint 118 is a separate template.

## Scope

| Item | Deliverable for review | Acceptance before Done |
| --- | --- | --- |
| [CURS-6](https://tasteslikegood.atlassian.net/browse/CURS-6) | Verified source inventory, format/coverage/reuse matrix, find-versus-create recommendation and missing data | Adam reviews the recommendation; candidates remain excluded from scoring until their technical suitability and provenance are established |
| [CURS-7](https://tasteslikegood.atlassian.net/browse/CURS-7) | Guide-contract audit, existing single-letter/two-letter examples, validator evidence, second-guide evidence and explicit unsupported capabilities | Adam reviews the schema; required device import/switching cases are recorded; any outstanding contract requirement is resolved or explicitly refined by the owner |
| [CURS-8](https://tasteslikegood.atlassian.net/browse/CURS-8) | Source-traceable e/h/l/o/p records, unchanged generated visual, per-letter comparison against public official references, shared-revision evidence and a formation/connection review worksheet | Reviewed formation and contextual connection decisions establish the claimed Zaner-Bloser alignment; needed contract/model changes receive behavioral and Apple verification plus appropriate device evidence |

The existing issue acceptance criteria remain authoritative. A review packet exposes unmet criteria; it does not remove or waive them. [Review packets](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/tree/chore/curs-1-charter-review/docs/reviews/) are the concrete proposals for the open PR.

CURS-9 (contextual connections), CURS-22 (personalized guides) and CURS-23 (font capture) are future children of the epic. They are outside this run's three-item scope. CURS-17 belongs to CURS-4 and is also in sprint 119; its incomplete device checklist remains separately tracked. Broader sprint closure must consider CURS-17 and cannot be inferred from this run.

## Review handoff and Done

The owner's requested loop endpoint is: **each of CURS-6, CURS-7 and CURS-8 is either Done with acceptance evidence, or In Review with a linked open PR containing its substantive proposal and remaining acceptance gates**. A single PR may contain the three review packets if its description names all three and explains their individual findings. In Review means the proposal is ready for human review; alignment and device acceptance may remain unresolved and visible.

The final verifier checks actual Jira status, issue ownership, exact sprint membership, complete and recent Jira snapshots, publication and committed review artifacts. Each item In Review must link the current open PR; the verifier also checks that PR's files, commit and completed CI/CodeQL. When all three items are Done with valid human acceptance receipts, completion does not require an open PR. An `in-review` label alone does not satisfy it. The epic stays In Progress while alignment or any child acceptance remains open.

Done requires issue-specific acceptance evidence and a named human review receipt. Green CI, a merged engineering PR, a high synthetic score, or an agent's assessment cannot substitute for the missing owner, physical-device or educational review.

## Acceptance evidence

Existing foundation: [PR #6](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/pull/6), [guide contract](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/blob/chore/curs-1-charter-review/docs/guide-format.md), [source assessment](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/blob/chore/curs-1-charter-review/docs/model-source-assessment.md), [primer visual](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/blob/chore/curs-1-charter-review/docs/primer-reference.svg), [baseline migration evidence](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/blob/chore/curs-1-charter-review/docs/scoring-evidence-1.3.md) and the [sprint record](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/blob/chore/curs-1-charter-review/docs/sprint-119.md). The current main baseline is prototype 1.5 at `8604c48ba21d21a3799ec0d9cf446bb445308984`, with successful [CI](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/actions/runs/37766478639) and [CodeQL](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/actions/runs/37766478596).

For this documentation/tooling change, run `python3 scripts/check_repository.py`, `./scripts/lint.sh`, verifier rejection checks and the PM governance gate. GitHub CI supplies the macOS iOS build and simulator results. Linux cannot perform those Apple checks locally. The latest [owner device report](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/blob/chore/curs-1-charter-review/docs/ipad-prototype-1.5-evaluation.md) accepts execution, improved grading and Replay clearing; it does not establish guide-import completion or first-five alignment.

## Decisions and sequence

1. **Sources:** the owner selected public official Zaner-Bloser references for this review. No particular full edition has been supplied. Handwriting Without Tears remains a marketplace reference only. Public access does not establish asset reuse permission.
2. **Research:** review CURS-6's create-versus-reuse recommendation first. Record any approved source/edition and missing technical information before model work.
3. **Contract:** review CURS-7's supported fields and rejected capabilities. Schema 1 rejects contextual variants and incompatible continuous endpoints; it must not silently flatten separate paths or invent a connector.
4. **Formation:** review CURS-8's five letters and the 13 ordered pairs actually used by the nine words. Resolve differing entry/exit conventions and any CURS-9 dependency before claiming alignment.
5. **Evaluation:** label teacher/model judgments and physical iPad evidence separately from geometric tests. Detailed calibration remains under CURS-20/CURS-21 and related scoring work.

## Risks and dependencies

| Risk | Evidence or response | Owner |
| --- | --- | --- |
| No reusable, licensed technical Zaner-Bloser dataset established | Use official references for assessment; retain original runtime data and review source/reuse decisions | Adam Schoen |
| Current curves differ from selected formation/connection examples | Per-letter and per-pair review; new model identity/revision if reviewed geometry changes | Adam Schoen |
| Schema 1 lacks contextual variants and connector curves | Expose the gap; review extension alongside CURS-9 before implementation | Adam Schoen |
| Import/invalid-import device cases unreported | Execute and record the existing device checklist; preserve unknown results | Adam Schoen |
| Current prototype scores are uncalibrated | Retain negative regressions and distinguish geometric measurements from educational judgments | Adam Schoen |
| Review status must be visible on the board | In Review is enabled in CURS's own simplified workflow and mapped to its board column, with return to In Progress and a path to Done; verify actual issue transitions at handoff | Adam Schoen |

## Delivery plan and budgets

The PM-domain harness runs five serial tasks: charter/project home, CURS-6 review packet, CURS-7 review packet, CURS-8 review packet, then fresh Jira/GitHub handoff. Every task names Adam as human owner and reviewer. The controller executes its verification commands and records evidence. Reading and independent review may run in parallel; writes to shared artifacts remain serialized.

Default budgets are **3 attempts per task and 12 loop operations**. Five execution/verification pairs normally consume 10 operations. A retry must change the approach. Exhausted budgets escalate to Adam with the evidence log; the agent cannot waive work, reset the state to evade limits, or alter a locked gate. [Harness instructions](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/blob/chore/curs-1-charter-review/docs/curs-1-harness.md) describe preparation, resume and verification. Templates are tracked under `specs/harness/`; generated state and raw snapshots stay in ignored `.agent-harness/`.

Sprint dates, capacity, story points and a delivery forecast remain **unset**. Sprint 119's future state is scheduling metadata, distinct from the epic's work status. Starting a timed Scrum sprint requires an agreed time box; this review run does not invent one.

## Communication and close

Publish this charter in the CURS Confluence space and link it from CURS-1 and each review packet. Link the current open PR from each scoped issue In Review, and record engineering checks and unresolved reviewer/device decisions in that PR. Preserve attributable human acceptance receipts for each Done item. Refresh Jira snapshots before verifying the terminal condition; also query GitHub when any item is In Review. Close the agent delivery loop only after its controller and PM governance gates pass; this closes the requested review handoff, not the epic or Scrum sprint.
