# CURS-1 delivery harness

This run publishes the project charter and prepares CURS-6, CURS-7 and CURS-8
for Adam Schoen's review. Its final gate accepts each item only at actual Jira
**In Review** with the current open PR, or **Done** with explicit human acceptance.
An agent-verified review packet does not establish device, model alignment or
educational acceptance. [The charter](../specs/curs-1-charter.md) defines the scope.

The installed `agent-harness` 1.0.0 controller runs five tasks serially. The
`pm-skills` 2.11.1 governance gate checks named human accountability. Tracked
templates in `specs/harness/` contain portable plugin-path placeholders; the
preparation script resolves them into fresh `.agent-harness/curs-1-*` files.
Previous harness files remain untouched. Raw snapshots and run state are local
artifacts; keep them out of the PR.

## Prepare and freeze

Review the tracked setup files and the charter before preparation. Preparation resolves
installed paths, checks the manifest inventory against the task skills, runs
the verifier's rejection tests and the PM plan gate on the resolved plan,
then freezes SHA-256 checksums for the templates, verifier, preparation and
initialization scripts,
this guide, resolved plan/manifest, canonical repository/lint/portable checks and
plugin controller/governance scripts. It **does not initialize** the controller.

The lock is a local drift detector for a reviewed setup baseline. Review its
bytes and exact plugin paths before initialization, and retain the original
commit and run artifacts for later comparison. Plugin-role checks prevent
accidental controller/governance substitutions. The baseline and verifier remain
trusted inputs; the lock does not authenticate them against a party able to
rewrite both. A second mutable local digest would not establish independent
trust. Do not update hashes to make an existing run pass.

Pass the installed skill directories explicitly. `--agent-harness-dir` contains
`SKILL.md` and `scripts/loop_controller.py`. `--pm-skills-dir` contains the
`pm-skills/`, `jira-expert/` and `confluence-expert/` directories.

```sh
python3 scripts/prepare-curs-1-harness.py \
  --agent-harness-dir /path/to/agent-harness/skills/agent-harness \
  --pm-skills-dir /path/to/pm-skills/skills
```

The JSON output gives exact resolved controller and governance paths and the
initialization/close commands. Existing CURS-1 run files cause preparation to
fail, preserving the previous run. The runtime and evidence directories must be
real directories inside this checkout; symlinked paths are rejected. Preparation
anchors exclusive writes to the validated runtime directory so a path replacement
cannot redirect generated files outside it. The frozen-input check also rejects
symlinked runtime directories and reserved files, including dangling state links.
Review the lock and resolved plan before
running the printed `init_after_setup_review` command:

```sh
python3 scripts/initialize-curs-1-harness.py
```

The initializer and failed-preparation cleanup take the same exclusive advisory
lock on the resolved plan. The initializer rechecks the frozen inputs and named
directory/file identities while holding that lock before invoking the exact
installed controller. If cleanup finishes first, initialization refuses missing
or replaced inputs. If initialization finishes first, cleanup preserves the state
and its input files. Use this wrapper for initialization; invoking the installed
controller's raw `init` directly does not participate in this coordination.
Preparation and initialization remain separate steps, with setup review between
them. Immediately check the frozen inputs and controller checks after initialization:

```sh
python3 scripts/prepare-curs-1-harness.py --check
```

After initialization, never change a frozen check, template or resolved plan to
make an acceptance condition pass. An actual setup defect requires an explicit
stop and a separately reviewed run, preserving the existing state and evidence.
Do not reset or overwrite state to evade attempt/iteration limits.

For a later verifier correction, preserve the original commit and its complete
run artifacts in a separate checkout before editing tracked inputs. The closed
2026-10-08 run belongs to commit `7463abb`; its preserved checkout is
`.agent-harness/history/curs-1-2026-10-08`. Run its `--check` from that checkout.
The corrected scripts do not revalidate or amend its historical receipts. Prepare
any later run in a fresh checkout with no CURS-1 runtime files.

## Execute, verify and resume

The 2026-10-08 controller state is already closed. A merged review PR cannot
satisfy the current In Review gate, and merging documents does not supply
issue-specific acceptance. When the owner requests a fresh review handoff,
preserve the closed run and use a new branch/worktree from current main:

```sh
git fetch origin
git worktree add -b chore/curs-1-review-continuation \
  .agent-harness/continuation-2026-10-09 origin/main
cd .agent-harness/continuation-2026-10-09
```

These are the branch and checkout for the current continuation. For a later run,
choose new names and retain this checkout. Update the charter and review packets
before preparation, open a new review PR, and refresh their Jira links through
the authenticated Atlassian MCP connector. Use the unchanged merged verifier
and the same preparation/initialization sequence above. Review the newly frozen
inputs before initialization. Do not reuse the root checkout's historical state
or copy its stale snapshots into a new run. The
[continuation decision register](curs-1-review-continuation.md) records the
current review scope and pending acceptance.

Read the controller path from `.agent-harness/curs-1-lock.json` into
`CURS_CONTROLLER`, or use the exact path printed by preparation. Ask `next` for
the directive, execute only that task, record execution, then let the controller
execute its checks. Substitute the directed task ID for `T1`:

```sh
python3 "$CURS_CONTROLLER" next --state .agent-harness/curs-1-state.json
python3 "$CURS_CONTROLLER" record --state .agent-harness/curs-1-state.json \
  --task T1 --phase execute --exit-code 0 --evidence 'Specific executed work and readback'
python3 "$CURS_CONTROLLER" verify --state .agent-harness/curs-1-state.json \
  --task T1 --cwd .
```

Do not record a passing verify phase yourself. The executable gate's result
becomes the controller's `verify-run` receipt. A fresh session resumes from the
locked plan and controller state; `next` selects the unfinished task.

| Task | Deliverable | Controller-run checks |
| --- | --- | --- |
| T1 | Charter, CURS Confluence space and published charter; epic In Progress | Charter/readback gate, repository integrity, lint |
| T2 | `docs/reviews/CURS-6.md` source decision packet | Substantive packet and source-reference gate |
| T3 | `docs/reviews/CURS-7.md` schema acceptance packet | Substantive packet gate and existing portable guide/model tests |
| T4 | `docs/reviews/CURS-8.md` five-letter alignment-gap packet | Substantive packet and official-reference gate |
| T5 | Fresh Jira/Confluence readbacks and acceptance or PR evidence | Complete scope, actual statuses and Done receipts; In Review also requires PR identity/files/body and live current-head CI/CodeQL |

Every task has Adam Schoen as human owner and reviewer. Budgets are **3 attempts
per task and 12 controller loop operations**. An execute record and a verify run
each consume an operation; five passing pairs consume 10. A retry must change the
approach. Exit 2 or 5 is escalation to Adam, with state/evidence preserved. Exit 4
refuses close; exit 6 reports an invalid transition. Only an explicit human
decision can waive work.

## Evidence interface

The canonical gate is:

```sh
python3 scripts/check_curs_1_delivery.py --task T1
python3 scripts/check_curs_1_delivery.py --task T5 \
  --evidence-dir .agent-harness/curs-1-evidence
```

Each API evidence file is an envelope around the **unaltered** MCP JSON result:

```json
{
  "captured_at": "2026-10-08T18:00:00Z",
  "cloud_id": "029decc8-e09a-4d55-92f8-20d9ca64ca13",
  "query": "The actual tool name and parameters or exact JQL",
  "response": {"data": {"key": "CURS-1", "fields": {}}}
}
```

Do not replace API values with intended statuses. The check rejects wrong clouds,
API errors, missing data, non-UTC capture times, evidence older than 30 minutes,
and incomplete pagination. Capture all pages before asserting completeness.

| File | Required raw `response.data` |
| --- | --- |
| `epic.json` | `getJiraIssue` CURS-1 (`31025`), Epic, actual In Progress, Adam assignee |
| `children.json` | Complete `searchJiraIssuesUsingJql`: `project = CURS AND parent = CURS-1 ORDER BY key ASC`; `isLast: true`, actual fields and sprint membership |
| `preserved-sprint-item.json` | `getJiraIssue` CURS-17 (`31041`), still In Progress, parent CURS-4 (`31028`), Adam assignee, sprint 119 on board 204 |
| `sprint.json` | Complete `listJiraBoardSprints` board 204; sprint 119 named `Cursivly 01 - Model foundation`, still future |
| `confluence-space.json` | `getConfluenceSpace` CURS on the same site, current space, numeric ID and canonical space URL |
| `confluence-charter.json` | Published current page `CURS-1 model foundation charter`, matching space ID and complete `body: {format: "markdown", value: "..."}` |
| `pr.json` | Required when any scoped item is In Review: `{ "number": 10 }` (use the actual PR number); GitHub fields are re-queried live with `gh` |

Confluence round-trip formatting may differ. The gate compares normalized words
and link targets with the canonical charter, retaining meaningful content and
identities. T2–T4 require at least 180 words, issue/reviewer identities, attributable
source references, and substantive **Acceptance evidence**, **Findings**,
**Decision requested** and **Remaining acceptance** sections. The final gate
rechecks all packets and publication; these structural checks establish a
reviewable artifact, while the human decides its conclusions.

The charter and all three review packets must be present in `git HEAD` and match
the working copies; untracked or staged-only documents do not establish delivery.
The epic description must link the published charter's actual page ID.

For In Review, every issue in that status must link the canonical current PR
URL. The PR must be OPEN, non-draft, target `main`, match local `git HEAD`, include
all three review files and the charter, and name each issue and file in its body.
The gate queries live workflow runs and requires successful current-head CI and
CodeQL. It uses the latest pull-request run for each workflow; an independent
duplicate dispatch/push event does not replace that run or require redundant
verification. Linux checks cannot replace the Apple build/simulator workflows.

For any Done item, additionally supply `acceptance-receipts.json` with the same
envelope and `response.data.receipts`. Each issue receipt includes `issue_key`,
`human_reviewed: true`, `accepted_by: "Adam Schoen"`, `decision: "accepted"`,
UTC `accepted_at`, the actual `acceptance_text`, a nonempty list of `criteria`,
`source_kind: "github_comment"` and `source_reference`, the exact URL of an
owner-authored issue/PR conversation comment in this repository.

The gate reads that comment live through authenticated `gh api` on `github.com`.
Its ID and URL must match; its author must be `adamtasteslikegood`, a User account,
with no GitHub App attribution. Its body must be a plain JSON acceptance object
with the following shape. This is a **format example, not acceptance evidence**:

```json
{
  "schema": "curs-1/human-acceptance.v1",
  "issue_key": "CURS-6",
  "human_reviewed": true,
  "decision": "accepted",
  "acceptance_text": "I accept CURS-6 after reviewing its source and reuse recommendation.",
  "criteria": ["Source inventory and reuse recommendation reviewed."]
}
```

The issue, decision, review flag, text and criteria must exactly match the local
receipt, and `accepted_at` must equal the live comment's UTC `updated_at`.
Missing, edited, revoked, differently authored or inaccessible sources block
Done. Local `user_message`, `jira_comment` and `confluence_page` assertions are
rejected because this CLI has no authenticated reader for those source types.
Keep the actual human decision in the evidence log; an agent cannot invent it or
post acceptance on the owner's behalf without their explicit decision.

The source check verifies the authenticated record's identity and content. It
does not prove physical human presence or distinguish every use of shared account
credentials; ownership and authorization remain required. When all three items
are Done, T5 queries their receipt sources but does not require `pr.json`, an open
PR, or live GitHub workflow queries. Mixed Done/In Review completion requires both
verified receipts and the live PR checks.

CURS-9, CURS-22 and CURS-23 must remain To Do. Unexpected active epic children
block the final gate. CURS-17 belongs to another epic and remains outside this
run's deliverables. Its independent readback must preserve the recorded parent,
In Progress status, Adam assignee and sprint membership. Sprint scheduling and
broader sprint closure remain separate work.

## Close and handoff

After the controller reports all tasks verified, create a separate PM projection:

```sh
python3 scripts/check_curs_1_delivery.py \
  --governance-output .agent-harness/curs-1-governance.json
python3 "$CURS_GOVERNANCE_GATE" --plan .agent-harness/curs-1-governance.json --mode close
python3 "$CURS_CONTROLLER" close --state .agent-harness/curs-1-state.json
```

The projection output must be a fresh file directly inside this repository's
`.agent-harness/` directory. Existing paths, nested paths, traversal and symlinks
are rejected; exclusive creation preserves historical files. If a projection
already exists, retain it and choose a new filename such as
`.agent-harness/curs-1-governance-2.json`, then pass that same file to the PM gate.

`CURS_GOVERNANCE_GATE` is the exact `governance_gate` path printed at preparation.
The projection preserves the plan's ownership, acceptance and limits plus full
controller evidence. It maps controller `verified` to PM `done` only with actual
passing `verify-run` receipts; it leaves controller state and locked plan intact.
Report issue/PR/Confluence links, current verification evidence, and remaining
human/device/alignment acceptance. Harness close completes this review handoff;
it does not close the epic or the Scrum time-box.

Run the verifier suite with `python3 scripts/check_curs_1_delivery.py --self-test`
and preparation regressions with `python3 scripts/test_curs_1_preparation.py`.
CI runs both. The verifier checks stale/denied evidence, pagination, label-only
review, unexpected active children, preserved scope, committed artifacts,
acceptance receipts, invalid PR identity and missing/failing/stale workflows.
It checks plugin-role identities and rejects symlinks during lock validation.
It also checks that governance output preserves existing files and rejects
paths outside the run directory, nested paths and symlinks.
The preparation suite checks resolved-plan governance, skill inventory, retry
after failure, directory symlinks, initialization/cleanup coordination and
preservation of existing runs. Neither suite uses synthetic fixtures as live
acceptance evidence.
