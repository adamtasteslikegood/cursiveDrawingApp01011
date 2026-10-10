# CURS-1 review continuation

Prepared 2026-10-09 for **Adam Schoen**, human owner, reviewer and escalation
contact. The owner selected restoration of the review handoff with a new PR
and fresh harness evidence. The [charter](../specs/curs-1-charter.md) retains
the original three-item scope and acceptance criteria.

[PR #10](https://github.com/adamtasteslikegood/cursiveDrawingApp01011/pull/10)
merged at 2026-10-09 15:02:44 UTC. The continuation starts from main
`a9e890e8e1bb484c2589ca99ed3d6404128ffb74`. Atlassian MCP reads on the evening
of October 9 Pacific time (October 10 UTC) show CURS-1 In Progress and
CURS-6/7/8 In Review. The three issues' comments and PR #10's conversation
contain no issue-specific acceptance decisions. These observations establish
current review work, while the merged documents establish the delivered
proposals.

## Decisions for review

| Item | Concrete proposal | Decision needed | Current acceptance |
| --- | --- | --- | --- |
| [CURS-6](reviews/CURS-6.md) | Create original instructional stroke data from reviewed formation and connection decisions; retain official references and project provenance | Approve the recommendation, request additional source research, or select an edition/source before authoring | Pending owner decision; no candidate adopted |
| [CURS-7](reviews/CURS-7.md) | Review schema 1's working guide contract, e/ee example, second guide and validation evidence | Accept the working subset with explicit scope refinement, or require contextual variants/connectors before Done | Pending schema decision and unreported device cases |
| [CURS-8](reviews/CURS-8.md) | Review the five original curves, official-reference observations and thirteen practiced pairs | Complete the per-letter/pair worksheet and decide the required contract/model changes | Pending formation and connection alignment |

Review CURS-6's direction first, then resolve CURS-7's contract decision before
authoring replacement geometry for CURS-8. A schema extension may depend on
CURS-9, which remains outside this run. These are recommendations for review;
the continuation does not approve a source, refine criteria or accept alignment.

The [device checklist](device-validation.md) retains successful/invalid/duplicate
imports, switching after ink/results and unreported layout cases. The latest
[1.5 owner evaluation](ipad-prototype-1.5-evaluation.md) records execution,
better grading and Replay clearing. It does not answer those cases or the
formation worksheet. Record observed results and missing details separately.

## Verified handoff

The current open continuation PR must contain the charter and all three updated
review packets, name them individually, and pass its own CI and CodeQL runs.
Each issue In Review must link that PR. The unchanged delivery verifier checks
fresh complete Jira/Confluence readbacks, committed documents, PR identity and
current-head workflows through the installed agent-harness controller.
The PM gate then checks named human accountability and controller evidence.

The historical closed run remains at its original commit, with its frozen
inputs and receipts preserved. This continuation uses a separate checkout and
fresh state; it does not recertify historical receipts or change a locked gate.
See [the harness guide](curs-1-harness.md) for initialization and resume commands.

The endpoint remains a verified review handoff. Done still requires attributable
issue-specific human acceptance under the existing verifier. CURS-9/22/23 stay
To Do. CURS-17 stays In Progress under CURS-4 in sprint 119. The sprint remains
future with dates, capacity and estimates unset; its closure and educational
calibration remain separate.
